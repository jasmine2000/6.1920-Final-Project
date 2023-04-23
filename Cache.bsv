import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import MemTypes::*;
import Vector::*;

typedef struct {
    CacheTag tag;
    CacheIndex index;
    CacheBlockOffset blockOffset;
} Address deriving (FShow);

function Address getAddressFields(WordAddr address);
    return Address {
        tag: address[31:13],
        index: address[12:6],
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
  BRAM2Port#(Bit#(7), CacheLine) cache <- mkBRAM2Server(cfg);
  Vector#(128, Reg#(CacheTag)) tags <- replicateM(mkReg('hfff));
  Vector#(128, Reg#(Bit#(1))) dirty <- replicateM(mkReg(0));

  Reg#(Maybe#(CacheReq)) currentRequest <- mkReg(Invalid);

  Vector#(8, Reg#(CacheReq)) storeBuff <- replicateM(mkReg(?));
  Vector#(8, Reg#(Bool)) storeBuffValid <- replicateM(mkReg(False));
  Reg#(Bit#(3)) sBuffEnq <- mkReg(0);
  Reg#(Bit#(3)) sBuffDeq <- mkReg(0);
  Reg#(Bit#(4)) sBuffCnt <- mkReg(0);

  Reg#(Mshr) state <- mkReg(Ready);

  FIFO#(Word) toProcQueue <- mkFIFO;
  FIFO#(MainMemReq) toMemQueue <- mkFIFO;

  Reg#(Maybe#(CacheLine)) memResp <- mkReg(Invalid);

  Reg#(Bool) debug <- mkReg(False);

  rule newReq if (
    state == Ready &&
    isValid(currentRequest) == True && 
    storeBuffValid[sBuffEnq] == False
    );

    let req = fromMaybe(?, currentRequest);
    let address = getAddressFields(req.addr);

    if (debug && req.byte_en == 0) $display("read %x\n", req.addr);
    if (debug && req.byte_en != 0) $display("write %x, %x\n", req.addr, req.data);

    if (req.byte_en == 0) begin // load

      Bool found = False;
      Word ret = ?;

      // TODO : FIX SBUFF
      for (Bit#(4) i = 0; (i)<sBuffCnt; i=i+1)
      begin
          if (req.addr == storeBuff[sBuffDeq + i[2:0]].addr)
          begin
            ret = storeBuff[sBuffDeq + i[2:0]].data;
            found = True;
          end
      end


      if (found == True) begin
        if (debug) $display("%x found in sbuff", req.addr);
        toProcQueue.enq(ret);
        currentRequest <= tagged Invalid;

      end else begin // Not found in SBuffer

        if (tags[address.index] == address.tag) begin // load hit
          if (debug) $display("%x req load hit", req.addr);
          // Read Line from BRAM
          let hit = BRAMRequest{
            write: False,
            address: address.index,
            datain: ?,
            responseOnWrite: False
          };
          cache.portA.request.put(hit);
          state <= Hit;

        end else begin // load miss
          if (debug) $display("%x req load miss", req.addr);
          if (dirty[address.index] == 1) begin
            state <= Writeback;
            let dirtyLine = BRAMRequest{
              write: False,
              address: address.index,
              datain: ?,
              responseOnWrite: False
            };
            cache.portA.request.put(dirtyLine);
          end else state <= SendFillReq;
        end
      end

    end else begin // Store
      if (debug) $display("%x store", req.addr);
      storeBuff[sBuffEnq] <= req;
      storeBuffValid[sBuffEnq] <= True;
      sBuffEnq <= sBuffEnq + 1;
      sBuffCnt <= sBuffCnt + 1;
      currentRequest <= tagged Invalid;
    end
  endrule

  rule getHit if (state == Hit); // load/store hit
    if (debug) $display("load hit");
    CacheLine lineResp <- cache.portA.response.get();

    let req = fromMaybe(?, currentRequest);
    let address = getAddressFields(req.addr);

    if (req.byte_en == 0) begin // Load
      toProcQueue.enq(lineResp[address.blockOffset]);
    end else begin
      if (debug) $display("writing %x to %x", req.data, lineResp);
      
      // TODO, byte enable in this line
      lineResp[address.blockOffset] = req.data;
    
      if (debug) $display("done writing %x", lineResp);

      let newLine = BRAMRequest{
        write: True,
        address: address.index,
        datain: lineResp,
        responseOnWrite: False
      };
      cache.portA.request.put(newLine);
      dirty[address.index] <= 1;
    end
    currentRequest <= tagged Invalid;
    state <= Ready;
  endrule

  rule writeback if (state == Writeback);
    let req = fromMaybe(?, currentRequest);
    let address = getAddressFields(req.addr);

    if (debug) $display("%x start miss", req.addr);

    LineAddr addr = {tags[address.index], address.index};

    let lineResp <- cache.portA.response.get();

    toMemQueue.enq(MainMemReq{
      write: True,
      addr: addr,
      data: lineResp
    });

    state <= SendFillReq;
  endrule

  rule sendingFillReq if (state == SendFillReq);
    let req = fromMaybe(?, currentRequest);
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
    let req = fromMaybe(?, currentRequest);
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
      cache.portA.request.put(newLine);
      tags[address.index] <= address.tag;
      dirty[address.index] <= 0;

    end else begin
      if (debug) $display("old line: %x", resp);
      
      resp[address.blockOffset] = req.data;
      if (debug) $display("new line: %x", resp);

      let newLine = BRAMRequest{
        write: True,
        address: address.index,
        datain: resp,
        responseOnWrite: False
      };
      cache.portA.request.put(newLine);
      tags[address.index] <= address.tag;
      dirty[address.index] <= 1;
    end

    memResp <= tagged Invalid;
    state <= Ready;
    currentRequest <= tagged Invalid;
  endrule

  rule deqStoreBuff if (
    state == Ready && 
    isValid(currentRequest) == False &&
    storeBuffValid[sBuffDeq] == True
    );

    let req = storeBuff[sBuffDeq];
    let address = getAddressFields(req.addr);

    if (debug) $display("%x store buff", req.addr);

    if (tags[address.index] == address.tag) begin // store hit
      let hit = BRAMRequest{
        write: False,
        address: address.index,
        datain: ?,
        responseOnWrite: False
      };
      cache.portA.request.put(hit);
      currentRequest <= tagged Valid req;
      state <= Hit;

    end else begin // store miss
      if (dirty[address.index] == 1) begin
        state <= Writeback;
        let dirtyLine = BRAMRequest{
          write: False,
          address: address.index,
          datain: ?,
          responseOnWrite: False
        };
        cache.portA.request.put(dirtyLine);
      end else state <= SendFillReq;

      currentRequest <= tagged Valid req;
    end

    sBuffDeq <= sBuffDeq + 1;
    storeBuffValid[sBuffDeq] <= False;
    sBuffCnt <= sBuffCnt - 1;
  endrule

  method Action putFromProc(CacheReq e) if (
    state == Ready && 
    storeBuffValid[sBuffEnq] == False &&
    isValid(currentRequest) == False
    );
    currentRequest <= tagged Valid e;
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

  method Action putFromMem(CacheLine e);
    memResp <= tagged Valid e;
    if (debug) $display("%x returned from mem", e);
  endmethod


endmodule
