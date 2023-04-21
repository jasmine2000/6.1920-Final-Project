import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import MemTypes::*;
import Vector::*;

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
  Vector#(128, Reg#(CacheTag)) tags <- replicateM(mkReg(19'hffff));
  Vector#(128, Reg#(Bit#(1))) dirty <- replicateM(mkReg(0));

  Reg#(Maybe#(CacheReq)) currentRequest <- mkReg(Invalid);

  Vector#(8, Reg#(CacheReq)) storeBuff <- replicateM(mkReg(?));
  Vector#(8, Reg#(Bool)) storeBuffValid <- replicateM(mkReg(False));
  Reg#(Bit#(3)) sBuffEnq <- mkReg(0);
  Reg#(Bit#(3)) sBuffDeq <- mkReg(0);

  Reg#(Mshr) state <- mkReg(Ready);

  FIFO#(Word) toProcQueue <- mkFIFO;
  FIFO#(MainMemReq) toMemQueue <- mkFIFO;

  Reg#(Maybe#(CacheLine)) memResp <- mkReg(Invalid);

  Reg#(Bool) debug <- mkReg(True);

  rule newReq if (
    state == Ready &&
    isValid(currentRequest) == True && 
    storeBuffValid[sBuffEnq] == False
    );
    let req = fromMaybe(?, currentRequest);

    CacheTag tag = req.addr[31:13];
    CacheIndex index = req.addr[12:6];
    CacheBlockOffset block_offset = req.addr[5:2];



    if (req.byte_en == 0) begin // load

      Bool found = False;
      CacheReq ret = ?;

      for (Integer i = 0; i < 8; i = i + 1) begin
        if (found == False && storeBuffValid[i] == True && req.addr == storeBuff[i].addr) begin
          // TODO if req.byte_en != 4'b1111 then don't return 
          found = True;
          ret = storeBuff[i];
        end
      end

      if (found == True) begin
        if (debug) $display("%x found in sbuff", req.addr);

        toProcQueue.enq(ret.data);

        currentRequest <= tagged Invalid;

      end else begin

        if (tags[index] == tag) begin // load hit
          if (debug) $display("%x req load hit", req.addr);
          let hit = BRAMRequest{
            write: False,
            address: index,
            datain: ?,
            responseOnWrite: False
          };
          cache.portA.request.put(hit);
          state <= Hit;

        end else begin // load miss
          if (debug) $display("%x req load miss", req.addr);
          if (dirty[index] == 1) begin
            state <= Writeback;
            let dirtyLine = BRAMRequest{
              write: False,
              address: index,
              datain: ?,
              responseOnWrite: False
            };
            cache.portA.request.put(dirtyLine);
          end else state <= SendFillReq;
        end
      end

    end else begin
      if (debug) $display("%x store", req.addr);
      storeBuff[sBuffEnq] <= req;
      storeBuffValid[sBuffEnq] <= True;
      sBuffEnq <= sBuffEnq + 1;
      currentRequest <= tagged Invalid;
    end
  endrule

  rule getHit if (state == Hit); // load/store hit
    if (debug) $display("load hit");
    CacheLine cacheLine <- cache.portA.response.get();

    let req = fromMaybe(?, currentRequest);
    CacheIndex index = req.addr[12:6];
    CacheBlockOffset offset = req.addr[5:2];

    if (req.byte_en == 0) begin // Load
      toProcQueue.enq(cacheLine[offset]);
    end else begin
      cacheLine[offset] = req.data;

      let newLine = BRAMRequest{
        write: True,
        address: index,
        datain: cacheLine,
        responseOnWrite: False
      };
      cache.portA.request.put(newLine);
      dirty[index] <= 1;
    end
    currentRequest <= tagged Invalid;
  endrule

  rule writeback if (state == Writeback);
    let req = fromMaybe(?, currentRequest);
    if (debug) $display("%x start miss", req.addr);
    CacheIndex index = req.addr[12:6];
    CacheBlockOffset offset = req.addr[5:2];

    LineAddr addr = {tags[index], index};
    
    CacheLine writeBackLine <- cache.portA.response.get();

    toMemQueue.enq(MainMemReq{
      write: True,
      addr: addr,
      data: writeBackLine
    });

    state <= SendFillReq;
  endrule

  rule sendingFillReq if (state == SendFillReq);
    let req = fromMaybe(?, currentRequest);
    if (debug) $display("%x send fill", req.addr);

    toMemQueue.enq(MainMemReq{
      write: False,
      addr: req.addr[31:6], // LineAddr
      data: ?
    });
    
    state <= WaitFillResp;
  endrule

  rule waitingFillResp if (state == WaitFillResp && isValid(memResp));
    let req = fromMaybe(?, currentRequest);
    if (debug) $display("%x wait fill", req.addr);

    CacheTag tag = req.addr[31:13];
    CacheIndex index = req.addr[12:6];
    CacheBlockOffset block_offset = req.addr[5:2];

    CacheLine resp = fromMaybe(?, memResp);

    if (req.byte_en == 0) begin // Read
      toProcQueue.enq(resp[block_offset]);
      memResp <= tagged Invalid;

      resp[index] = req.data;

      let newLine = BRAMRequest{
        write: True,
        address: index,
        datain: resp,
        responseOnWrite: False
      };
      cache.portA.request.put(newLine);
      tags[index] <= tag;

    end else begin // Write
      resp[index] = req.data;

      let newLine = BRAMRequest{
        write: True,
        address: index,
        datain: resp,
        responseOnWrite: False
      };
      cache.portA.request.put(newLine);
      tags[index] <= tag;
      dirty[index] <= 1;
    end

    state <= Ready;
    currentRequest <= tagged Invalid;
  endrule

  rule deqStoreBuff if (
    state == Ready && 
    isValid(currentRequest) == False &&
    storeBuffValid[sBuffDeq] == True
    );
    let req = storeBuff[sBuffDeq];
    if (debug) $display("%x store buff", req.addr);
    CacheTag tag = req.addr[31:13];
    CacheIndex index = req.addr[12:6];
    CacheBlockOffset offset = req.addr[5:2];

    if (tags[index] == tag) begin // store hit
      let hit = BRAMRequest{
        write: False,
        address: index,
        datain: ?,
        responseOnWrite: False
      };
      cache.portA.request.put(hit);
      state <= Hit;

    end else begin // store miss
      if (dirty[index] == 1) begin
        state <= Writeback;
        let dirtyLine = BRAMRequest{
          write: False,
          address: index,
          datain: ?,
          responseOnWrite: False
        };
        cache.portA.request.put(dirtyLine);
      end else state <= SendFillReq;

      currentRequest <= tagged Valid req;
    end

    sBuffDeq <= sBuffDeq + 1;
    storeBuffValid[sBuffDeq] <= False;
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
