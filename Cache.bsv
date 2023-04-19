import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import MemTypes::*;
import Vector::*;

interface Cache;
    method Action putFromProc(CacheReq e);
    method ActionValue#(Word) getToProc();
    method ActionValue#(MainMemReq) getToMem();
    method Action putFromMem(MainMemResp e);
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
  BRAM2Port#(Bit#(7), Bit#(512)) cache <- mkBRAM2Server(cfg);
  Vector#(128, Reg#(Bit#(15))) tags <- replicateM(mkReg(0));
  Vector#(128, Reg#(Bit#(1))) dirty <- replicateM(mkReg(0));

  Reg#(Maybe#(CacheReq)) currentRequest <- mkReg(Invalid);

  Vector#(8, Reg#(CacheReq)) storeBuff <- replicateM(mkReg(?));
  Vector#(8, Reg#(Bool)) storeBuffValid <- replicateM(mkReg(False));
  Reg#(Bit#(3)) sBuffEnq <- mkReg(0);
  Reg#(Bit#(3)) sBuffDeq <- mkReg(0);

  Reg#(Mshr) state <- mkReg(Ready);

  FIFO#(Word) toProcQueue <- mkFIFO;
  FIFO#(MainMemReq) toMemQueue <- mkFIFO;

  Reg#(Maybe#(MainMemResp)) memResp <- mkReg(Invalid);

  Reg#(Bool) debug <- mkReg(False);

  rule newReq if (
    state == Ready &&
    isValid(currentRequest) == True && 
    storeBuffValid[sBuffEnq] == False
    );
    let req = fromMaybe(?, currentRequest);

    let tag = req.addr[25:11];
    let index = req.addr[10:4];
    let offset = req.addr[10:4];

    if (req.write == 0) begin // load

      Bool found = False;
      Word ret = ?;

      for (Integer i = 0; i < 8; i = i + 1) begin
        if (found == False && storeBuffValid[i] == True && req.addr == storeBuff[i].addr) begin
          found = True;
          ret = storeBuff[i].data;
        end
      end

      // Bit#(3) deq = pack(sBuffDeq);
      // Bit#(3) enq = pack(sBuffDeq);
      // for (Integer i = valueOf(sBuffDeq); i < 8; i = i + 1) begin
      //   if (found == False && storeBuffValid[i] == True && req.addr == storeBuff[i].addr) begin
      //     found = True;
      //     ret = storeBuff[i].data;
      //   end
      // end
      // for (Integer i = 0; i < valueOf(sBuffEnq); i = i + 1) begin
      //   if (found == False && storeBuffValid[i] == True && req.addr == storeBuff[i].addr) begin
      //     found = True;
      //     ret = storeBuff[i].data;
      //   end
      // end

      if (found == True) begin
        if (debug) $display("%x found in sbuff", req.addr);

        Bit#(9) start_idx = 511 - zeroExtend(offset) * 32;
        toProcQueue.enq(ret[start_idx:start_idx - 31]);

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
    Bit#(512) a <- cache.portA.response.get();

    let req = fromMaybe(?, currentRequest);
    let index = req.addr[10:4];
    let offset = req.addr[3:0];

    Bit#(9) start_idx = 511 - zeroExtend(offset) * 32;

    if (req.write == 0) begin
      toProcQueue.enq(a[start_idx:start_idx - 31]);
    end else begin
      for (Bit#(9) i = 0; i < 32; i = i + 1) begin
        a[start_idx - i] = req.data[31 - i];
      end

      let newLine = BRAMRequest{
        write: True,
        address: index,
        datain: a,
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
    let index = req.addr[10:4];
    let offset = req.addr[3:0];

    LineAddr addr = {tags[index], index, offset};
    
    Bit#(9) start_idx = 511 - zeroExtend(offset) * 32;

    let a <- cache.portA.response.get();

    toMemQueue.enq(MainMemReq{
      write: 1,
      addr: addr,
      data: a
    });

    state <= SendFillReq;
  endrule

  rule sendingFillReq if (state == SendFillReq);
    let req = fromMaybe(?, currentRequest);
    if (debug) $display("%x send fill", req.addr);

    toMemQueue.enq(MainMemReq{
      write: 0,
      addr: req.addr,
      data: ?
    });
    
    state <= WaitFillResp;
  endrule

  rule waitingFillResp if (state == WaitFillResp && isValid(memResp));
    let req = fromMaybe(?, currentRequest);
    if (debug) $display("%x wait fill", req.addr);

    let tag = req.addr[25:11];
    let index = req.addr[10:4];
    let offset = req.addr[3:0];

    Bit#(9) start_idx = 511 - zeroExtend(offset) * 32;

    MainMemResp resp = fromMaybe(?, memResp);

    if (req.write == 0) begin
      toProcQueue.enq(resp[start_idx:start_idx - 31]);
      memResp <= tagged Invalid;

    end else if (req.write == 1) begin
      for (Bit#(9) i = 0; i < 32; i = i + 1) begin
        resp[start_idx - i] = req.data[31 - i];
      end

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
    let tag = req.addr[25:11];
    let index = req.addr[10:4];
    let offset = req.addr[3:0];

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
    return ret;
  endmethod

  method ActionValue#(MainMemReq) getToMem();
    let req = toMemQueue.first();
    if (debug && req.write == 1) $display("%x get to mem", req.addr, req.data);
    else if (debug) $display("%x get to mem", req.addr);
    toMemQueue.deq();
    return req;
  endmethod

  method Action putFromMem(MainMemResp e);
    memResp <= tagged Valid e;
    if (debug) $display("%x returned from mem", e);
  endmethod


endmodule
