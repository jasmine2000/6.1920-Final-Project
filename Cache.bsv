import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import MemTypes::*;
import Vector::*;

interface Cache;
    method Action putFromProc(MainMemReq e);
    method ActionValue#(MainMemResp) getToProc();
    method ActionValue#(MainMemReq) getToMem();
    method Action putFromMem(MainMemResp e);
endinterface

interface SearchableQueue;
    method Action enq(MainMemReq value);
    method ActionValue#(MainMemReq) deq();
    method ActionValue#(Maybe#(MainMemReq)) search(LineAddr addr);
endinterface

typedef enum {
    Ready,
    StartMiss,
    SendFillReq,
    WaitFillResp
} Mshr deriving (Bits, Eq, FShow);

module mkCache(Cache);
  BRAM_Configure cfg = defaultValue();
  BRAM2Port#(Bit#(7), MainMemResp) cache <- mkBRAM2Server(cfg);
  Vector#(128, Reg#(Bit#(19))) tags <- replicateM(mkReg(0));
  Vector#(128, Reg#(Bit#(1))) dirty <- replicateM(mkReg(0));

  Reg#(Maybe#(MainMemReq)) currentRequest <- mkReg(Invalid);

  Vector#(8, Reg#(MainMemReq)) storeBuff <- replicateM(mkReg(?));
  Vector#(8, Reg#(Bool)) storeBuffValid <- replicateM(mkReg(False));
  Reg#(Bit#(3)) sBuffEnq <- mkReg(0);
  Reg#(Bit#(3)) sBuffDeq <- mkReg(0);

  Reg#(Mshr) state <- mkReg(Ready);

  FIFO#(MainMemResp) toProcQueue <- mkFIFO;
  FIFO#(MainMemReq) toMemQueue <- mkFIFO;

  Reg#(Maybe#(MainMemResp)) memResp <- mkReg(Invalid);

  Reg#(Bool) debug <- mkReg(False);

  rule newReq if (
    state == Ready &&
    isValid(currentRequest) == True && 
    storeBuffValid[sBuffEnq] == False
    );
    let req = fromMaybe(?, currentRequest);
    if (req.write == 0) begin // load

      Bool found = False;
      MainMemResp ret = ?;
      for (Integer i = 0; i < 8; i = i + 1) begin
        if (found == False && storeBuffValid[i] == True && req.addr == storeBuff[i].addr) begin
          found = True;
          ret = storeBuff[i].data;
        end
      end

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
        toProcQueue.enq(ret);
        currentRequest <= tagged Invalid;

      end else begin

        let tag = req.addr[25:7];
        let index = req.addr[6:0];

        if (tags[index] == tag) begin // load hit
          if (debug) $display("%x req load hit", req.addr);
          let hit = BRAMRequest{
            write: False,
            address: index,
            datain: ?,
            responseOnWrite: False
          };
          cache.portA.request.put(hit);
          currentRequest <= tagged Invalid;

        end else begin // load miss
          if (debug) $display("%x req load miss", req.addr);
          if (dirty[index] == 1) begin
            state <= StartMiss;
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

  rule getHit if (state == Ready); // load hit
    if (debug) $display("load hit");
    let a <- cache.portA.response.get();
    toProcQueue.enq(a);
  endrule

  rule startingMiss if (state == StartMiss);
    let req = fromMaybe(?, currentRequest);
    if (debug) $display("%x start miss", req.addr);
    let index = req.addr[6:0];
    LineAddr addr = {tags[index], index};

    let a <- cache.portA.response.get();

    toMemQueue.enq(MainMemReq{
      write: 1,
      addr: addr,
      data: a
    });

    if (req.write == 0) state <= SendFillReq;
    else state <= WaitFillResp;
  endrule

  rule sendingFillReq if (state == SendFillReq);
    let req = fromMaybe(?, currentRequest);
    if (debug) $display("%x send fill", req.addr);
    if (req.write == 0)
      toMemQueue.enq(MainMemReq{
        write: 0,
        addr: req.addr,
        data: ?
      });
    else
      toMemQueue.enq(MainMemReq{
        write: 1,
        addr: req.addr,
        data: req.data
      });
    state <= WaitFillResp;
  endrule

  rule waitingFillResp if (state == WaitFillResp);
    let req = fromMaybe(?, currentRequest);
    if (debug) $display("%x wait fill", req.addr);
    if (req.write == 0 && isValid(memResp)) begin
      toProcQueue.enq(fromMaybe(?, memResp));
      memResp <= tagged Invalid;
      currentRequest <= tagged Invalid;
      state <= Ready;
    end else if (req.write == 1) begin
      let tag = req.addr[25:7];
      let index = req.addr[6:0];
      let newLine = BRAMRequest{
        write: True,
        address: index,
        datain: req.data,
        responseOnWrite: False
      };
      cache.portA.request.put(newLine);
      tags[index] <= tag;
      dirty[index] <= 1;
      currentRequest <= tagged Invalid;
      state <= Ready;
    end
  endrule

  rule deqStoreBuff if (
    state == Ready && 
    isValid(currentRequest) == False &&
    storeBuffValid[sBuffDeq] == True
    );
    let req = storeBuff[sBuffDeq];
    if (debug) $display("%x store buff", req.addr);
    let tag = req.addr[25:7];
    let index = req.addr[6:0];

    if (tags[index] == tag) begin // store hit
      dirty[index] <= 1;
      let hit = BRAMRequest{
        write: True,
        address: index,
        datain: req.data,
        responseOnWrite: False
      };
      cache.portA.request.put(hit);

    end else begin // store miss
      if (dirty[index] == 1) begin
        state <= StartMiss;
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

  method Action putFromProc(MainMemReq e) if (
    state == Ready && 
    storeBuffValid[sBuffEnq] == False &&
    isValid(currentRequest) == False
    );
    currentRequest <= tagged Valid e;
  endmethod

  method ActionValue#(MainMemResp) getToProc();
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
