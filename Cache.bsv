import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import MemTypes::*;
import Vector::*;
import Ehr::*;

typedef struct {
    CacheTag tag;
    CacheIndex index;
    CacheBlockOffset blockOffset;
} Address deriving (FShow);

function Address getAddressFields(WordAddr address);
    return Address {
        tag: address[31:10],
        index: address[9:6],
        blockOffset: address[5:2]
    };
endfunction

interface Cache;
    method Action putFromProc(CacheReq e);
    method ActionValue#(Word) getToProc();
    method ActionValue#(MainMemReq) getToMem();
    method Action putFromMem(CacheLine e);
endinterface

typedef enum {
    Ready,
    Hit,
    Writeback,
    SendFillReq,
    WaitFillResp
} Mshr deriving (Bits, Eq, FShow);

module mkCache(Cache);
  BRAM_Configure cfg = defaultValue();
  
  Vector#(1, BRAM2Port#(CacheIndex, CacheLine) ) cache <- replicateM(mkBRAM2Server(cfg));
  Vector#(1, Vector#(128, Reg#(CacheTag))) tags <- replicateM(replicateM(mkReg('hfff)));
  Vector#(1, Vector#(128, Reg#(Bit#(1)))) dirty <- replicateM(replicateM(mkReg(0)));

  Ehr#(2, Maybe#(CacheReq)) currentRequest <- mkEhr(Invalid);
  Reg#(Maybe#(CacheReq)) stallRequest <- mkReg(Invalid);

  Vector#(8, Reg#(CacheReq)) storeBuff <- replicateM(mkReg(?));
  Vector#(8, Reg#(Bool)) storeBuffValid <- replicateM(mkReg(False));
  Reg#(Bit#(3)) sBuffEnq <- mkReg(0);
  Reg#(Bit#(3)) sBuffDeq <- mkReg(0);
  Reg#(Bit#(4)) sBuffCnt <- mkReg(0);

  Reg#(Mshr) state <- mkReg(Ready);

  FIFO#(Word) toProcQueue <- mkBypassFIFO;
  FIFO#(MainMemReq) toMemQueue <- mkBypassFIFO;

  Reg#(Maybe#(CacheLine)) memResp <- mkReg(Invalid);
  Reg#(Bit#(2)) currentWay <- mkReg(0);

  Reg#(Bool) debug <- mkReg(False);

  rule newReq if (
    state == Ready &&
    isValid(currentRequest[1]) == True && 
    storeBuffValid[sBuffEnq] == False
    );

    let req = fromMaybe(?, currentRequest[1]);
    let address = getAddressFields(req.addr);

    if (debug && req.byte_en == 0) $display("read %x\n", req.addr);
    if (debug && req.byte_en != 0) $display("write %x, %x\n", req.addr, req.data);

    if (req.byte_en == 0) begin // load

      // search all sets for matching tag
      Bool hit = False;
      Integer way = ?;
      
      for (Integer i = 0; i < 1; i = i+1)
      begin
        if (tags[i][address.index] == address.tag) 
        begin
          hit = True;
          way = i;
        end
      end


      
      if (hit) begin // load hit
        if (debug) $display("%x req load hit", req.addr);
        // Read Line from BRAM
        let hitreq = BRAMRequest{
          write: False,
          address: address.index,
          datain: ?,
          responseOnWrite: False
        };
        cache[way].portA.request.put(hitreq);
        state <= Hit;
        currentWay <= 0;//fromInteger(way);

      end else begin // load miss
        if (debug) $display("%x req load miss", req.addr);
        
        Bit#(2) newWay = 0; //currentWay + 1; // TODO replacement policy
        currentWay <= newWay;

        if (dirty[newWay][address.index] == 1) begin
          state <= Writeback;
          let dirtyLine = BRAMRequest{
            write: False,
            address: address.index,
            datain: ?,
            responseOnWrite: False
          };
          cache[newWay].portA.request.put(dirtyLine);
        end else state <= SendFillReq;
      end

    end else begin // Store
      if (debug) $display("%x store", req.addr);
      storeBuff[sBuffEnq] <= req;
      storeBuffValid[sBuffEnq] <= True;
      sBuffEnq <= sBuffEnq + 1;
      sBuffCnt <= sBuffCnt + 1;
      currentRequest[1] <= tagged Invalid;
    end
  endrule

  rule getHit if (state == Hit); // load/store hit
    if (debug) $display("load hit");
    CacheLine lineResp <- cache[currentWay].portA.response.get();

    let req = fromMaybe(?, currentRequest[1]);
    let address = getAddressFields(req.addr);

    if (req.byte_en == 0) begin // Load
      toProcQueue.enq(lineResp[address.blockOffset]);
      currentRequest[1] <= tagged Invalid;
    end else begin
      if (debug) $display("writing %x to %x", req.data, lineResp);

      Bit#(32) mask = ?;
      for (Integer i = 0; i < 4; i = i + 1)
      begin
        for (Integer j = 0; j < 8; j = j + 1)
        begin
          mask[8*i + j] = req.byte_en[i];
        end
      end

      lineResp[address.blockOffset] = (lineResp[address.blockOffset] & (~mask) ) | (req.data & mask);
    
      if (debug) $display("done writing %x", lineResp);

      let newLine = BRAMRequest{
        write: True,
        address: address.index,
        datain: lineResp,
        responseOnWrite: False
      };
      cache[currentWay].portA.request.put(newLine);
      dirty[currentWay][address.index] <= 1;

      // if (storeBuffValid[sBuffDeq + 1] == False && isValid(stallRequest)) begin // cleared sbuff
      //   currentRequest[1] <= stallRequest;
      //   stallRequest <= tagged Invalid;
      // end else 
      currentRequest[1] <= tagged Invalid;
    end
    // currentRequest[1] <= tagged Invalid;
    state <= Ready;
  endrule

  rule writeback if (state == Writeback);
    let req = fromMaybe(?, currentRequest[1]);
    let address = getAddressFields(req.addr);

    if (debug) $display("%x start miss", req.addr);

    LineAddr addr = {tags[currentWay][address.index], address.index};

    let lineResp <- cache[currentWay].portA.response.get();

    toMemQueue.enq(MainMemReq{
      write: True,
      addr: addr,
      data: lineResp
    });

    state <= SendFillReq;
  endrule

  rule sendingFillReq if (state == SendFillReq);
    let req = fromMaybe(?, currentRequest[1]);
    let address = getAddressFields(req.addr);
    if (debug) $display("%x send fill", req.addr);

    LineAddr addr = {address.tag, address.index};

    toMemQueue.enq(MainMemReq{
      write: False,
      addr: addr,
      data: ?
    });
    
    state <= WaitFillResp;
  endrule

  rule waitingFillResp if (state == WaitFillResp && isValid(memResp));
    let req = fromMaybe(?, currentRequest[1]);
    let address = getAddressFields(req.addr);

    if (debug) $display("%x wait fill", req.addr);

    CacheLine resp = fromMaybe(?, memResp);

    if (req.byte_en == 0) begin // Read
      toProcQueue.enq(resp[address.blockOffset]);
      
      let newLine = BRAMRequest{
        write: True,
        address: address.index,
        datain: resp,
        responseOnWrite: False
      };
      cache[currentWay].portA.request.put(newLine);
      tags[currentWay][address.index] <= address.tag;
      dirty[currentWay][address.index] <= 0;

    end else begin
      if (debug) $display("old line: %x", resp);
      
      Bit#(32) mask = ?;
      for (Integer i = 0; i < 4; i = i + 1)
      begin
        for (Integer j = 0; j < 8; j = j + 1)
        begin
          mask[8*i + j] = req.byte_en[i];
        end
      end

      resp[address.blockOffset] = (resp[address.blockOffset] & (~mask) ) | (req.data & mask);

      if (debug) $display("new line: %x", resp);

      let newLine = BRAMRequest{
        write: True,
        address: address.index,
        datain: resp,
        responseOnWrite: False
      };
      cache[currentWay].portA.request.put(newLine);
      tags[currentWay][address.index] <= address.tag;
      dirty[currentWay][address.index] <= 1;
    end

    memResp <= tagged Invalid;
    state <= Ready;
    // if (storeBuffValid[sBuffDeq + 1] == False && isValid(stallRequest)) begin // cleared sbuff
    //   currentRequest[1] <= stallRequest;
    //   stallRequest <= tagged Invalid;
    // end else 
    currentRequest[1] <= tagged Invalid;
  endrule

  rule deqStoreBuff if (
    state == Ready && 
    isValid(currentRequest[1]) == False &&
    storeBuffValid[sBuffDeq] == True
    );

    let req = storeBuff[sBuffDeq];
    let address = getAddressFields(req.addr);

    if (debug) $display("%x store buff", req.addr);

    Bool hit = False;
    Integer way = ?;
    
    for (Integer i = 0; i < 1; i = i+1)
    begin
      if (tags[i][address.index] == address.tag) 
      begin
        hit = True;
        way = i;
      end
    end

    if (hit) begin // store hit
      let hitReq = BRAMRequest{
        write: False,
        address: address.index,
        datain: ?,
        responseOnWrite: False
      };
      cache[way].portA.request.put(hitReq);
      currentRequest[1] <= tagged Valid req;
      state <= Hit;

      currentWay <= fromInteger(way);

    end else begin // store miss
      
      Bit#(2) newWay = 0;//currentWay + 1; // TODO replacement policy
      currentWay <= newWay;

      if (dirty[newWay][address.index] == 1) begin
        state <= Writeback;
        let dirtyLine = BRAMRequest{
          write: False,
          address: address.index,
          datain: ?,
          responseOnWrite: False
        };
        cache[newWay].portA.request.put(dirtyLine);
      end else state <= SendFillReq;

      currentRequest[1] <= tagged Valid req;
    end

    sBuffDeq <= sBuffDeq + 1;
    storeBuffValid[sBuffDeq] <= False;
    sBuffCnt <= sBuffCnt - 1;
  endrule

  method Action putFromProc(CacheReq e) if (
    state == Ready && 
    storeBuffValid[sBuffEnq] == False &&
    isValid(currentRequest[0]) == False
    );

    Bool found = False;
    Word ret = ?;
    Bool partialWrite = False;

    if (e.byte_en == 4'b0) begin
      for (Bit#(4) i = 0; (i)<sBuffCnt; i=i+1)
      begin
          let idx = sBuffDeq + i[2:0];
          if (storeBuffValid[idx] == True && e.addr == storeBuff[idx].addr)
          begin
            if (storeBuff[sBuffDeq + i[2:0]].byte_en == 4'b1111) begin
              ret = storeBuff[sBuffDeq + i[2:0]].data;
              found = True;
            end else partialWrite = True;
          end
      end
    end

    if (partialWrite == True) 
      stallRequest <= tagged Valid e;
    else if (found == True) 
      toProcQueue.enq(ret);
    else 
      currentRequest[0] <= tagged Valid e;
  endmethod

  method ActionValue#(Word) getToProc();
    let ret = toProcQueue.first();
    toProcQueue.deq();
    if (debug) $display("%x get to proc", ret);
    return ret;
  endmethod

  method ActionValue#(MainMemReq) getToMem();
    let req = toMemQueue.first();
    if (debug && req.write) $display("%x get to mem", req.addr, req.data);
    else if (debug) $display("%x get to mem", req.addr);
    toMemQueue.deq();
    return req;
  endmethod

  method Action putFromMem(CacheLine e) if (isValid(memResp) == False);
    memResp <= tagged Valid e;
    if (debug) $display("%x returned from mem", e);
  endmethod


endmodule
