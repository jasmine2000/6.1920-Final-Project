import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import MemTypes::*;
import Vector::*;

typedef struct {
    Bit#(15) tag;
    Bit#(7) index;
    Bit#(4) offset;
    Bit#(9) start_idx;
    Bit#(9) end_idx;
} Address deriving (FShow);

function Address getAddressFields(Bit#(26) address);
    return Address {
        tag: address[25:11],
        index: address[10:4],
        offset: address[3:0],
        start_idx: 511 - zeroExtend(address[3:0]) * 32,
        end_idx: 480 - zeroExtend(address[3:0]) * 32
    };
endfunction

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
    let address = getAddressFields(req.addr);

    if (debug && req.write == 0) $display("read %x\n", req.addr);
    if (debug && req.write == 1) $display("write %x, %x\n", req.addr, req.data);

    if (req.write == 0) begin // load

      Bool found = False;
      Word ret = ?;

      // TODO : FIX SBUFF
      for (Integer i = 0; i < 8; i = i + 1) begin
        if (found == False && storeBuffValid[i] == True && req.addr == storeBuff[i].addr) begin
          found = True;
          ret = storeBuff[i].data;
        end
      end

      if (found == True) begin
        if (debug) $display("%x found in sbuff", req.addr);
        toProcQueue.enq(ret[address.start_idx:address.end_idx]);
        currentRequest <= tagged Invalid;

      end else begin

        if (tags[address.index] == address.tag) begin // load hit
          if (debug) $display("%x req load hit", req.addr);
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
    let address = getAddressFields(req.addr);

    if (req.write == 0) begin
      toProcQueue.enq(a[address.start_idx:address.end_idx]);
    end else begin
      if (debug) $display("writing %x to %x", req.data, a);
      for (Bit#(9) i = 0; i < 32; i = i + 1) begin
        a[address.start_idx - i] = req.data[31 - i];
      end
      if (debug) $display("done writing %x", a);

      let newLine = BRAMRequest{
        write: True,
        address: address.index,
        datain: a,
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

    LineAddr addr = {tags[address.index], address.index, address.offset};
    
    Bit#(9) start_idx = 511 - zeroExtend(address.offset) * 32;

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
    let address = getAddressFields(req.addr);

    if (debug) $display("%x wait fill", req.addr);

    MainMemResp resp = fromMaybe(?, memResp);

    if (req.write == 0) begin
      toProcQueue.enq(resp[address.start_idx:address.end_idx]);

    end else if (req.write == 1) begin
      if (debug) $display("old line: %x", resp);
      for (Bit#(9) i = 0; i < 32; i = i + 1) begin
        resp[address.start_idx - i] = req.data[31 - i];
      end
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
