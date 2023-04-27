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
        tag: address[31:13],
        index: address[12:6],
        blockOffset: address[5:2]
    };
endfunction

interface ICache;
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

(* synthesize *)
module mkICache(ICache);
  BRAM_Configure cfg = defaultValue();
  
  BRAM2Port#(Bit#(7), CacheLine) cache <- mkBRAM2Server(cfg);
  Vector#(128, Reg#(CacheTag)) tags <- replicateM(mkReg('hfff));
  Vector#(128, Reg#(Bit#(1))) dirty <- replicateM(mkReg(0));

  Ehr#(3, Maybe#(CacheReq)) currentRequest <- mkEhr(Invalid);

  Ehr#(2, Mshr) state <- mkEhr(Ready);

  FIFO#(Word) toProcQueue <- mkBypassFIFO;
  FIFO#(MainMemReq) toMemQueue <- mkBypassFIFO;

  Reg#(Maybe#(CacheLine)) memResp <- mkReg(Invalid);

  Reg#(Bool) debug <- mkReg(False);

  rule newReq if (
    state[1] == Ready &&
    isValid(currentRequest[2]) == True
    );

    let req = fromMaybe(?, currentRequest[2]);
    let address = getAddressFields(req.addr);

    if (debug && req.byte_en == 0) $display("read %x", req.addr);
    if (debug && req.byte_en != 0) $display("write %x, %x", req.addr, req.data);

    if (req.byte_en == 0) begin // load

        if (tags[address.index] == address.tag) begin // load hit
          if (debug) $display("%x req load hit, %x", req.addr, address.blockOffset);
          // Read Line from BRAM
          let hitreq = BRAMRequest{
            write: False,
            address: address.index,
            datain: ?,
            responseOnWrite: False
          };
          cache.portA.request.put(hitreq);
          state[1] <= Hit; // old

          
        end else begin // load miss
          if (debug) $display("%x req load miss", req.addr);

          if (dirty[address.index] == 1) begin
            state[1] <= Writeback;
            let dirtyLine = BRAMRequest{
              write: False,
              address: address.index,
              datain: ?,
              responseOnWrite: False
            };
            cache.portA.request.put(dirtyLine);
          end else state[1] <= SendFillReq;
        end

    end else begin // Store
      $display("illegal write");
      $finish;
    end
  endrule

  rule getHit if (state[0] == Hit); // old
    CacheLine lineResp <- cache.portA.response.get();

    let req = fromMaybe(?, currentRequest[0]); // old
    let offset = getAddressFields(req.addr).blockOffset; // old

    if (debug) $display("load hit %x", lineResp[offset]);

    toProcQueue.enq(lineResp[offset]);

    currentRequest[0] <= tagged Invalid; // old
    state[0] <= Ready; // old
  endrule

  rule writeback if (state[0] == Writeback);
    let req = fromMaybe(?, currentRequest[0]);
    let address = getAddressFields(req.addr);

    if (debug) $display("%x start miss", req.addr);

    LineAddr addr = {tags[address.index], address.index};

    let lineResp <- cache.portA.response.get();

    toMemQueue.enq(MainMemReq{
      write: True,
      addr: addr,
      data: lineResp
    });

    state[0] <= SendFillReq;
  endrule

  rule sendingFillReq if (state[0] == SendFillReq);
    let req = fromMaybe(?, currentRequest[0]);
    let address = getAddressFields(req.addr);
    if (debug) $display("%x send fill", req.addr);

    LineAddr addr = {address.tag, address.index};

    toMemQueue.enq(MainMemReq{
      write: False,
      addr: addr,
      data: ?
    });
    
    state[0] <= WaitFillResp;
  endrule

  rule waitingFillResp if (state[0] == WaitFillResp && isValid(memResp));
    let req = fromMaybe(?, currentRequest[0]);
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
        $display("illegal write");
        $finish;
    end

    memResp <= tagged Invalid;
    state[0] <= Ready;
    currentRequest[0] <= tagged Invalid;
  endrule

  method Action putFromProc(CacheReq e) if (
    state[1] == Ready && 
    isValid(currentRequest[1]) == False
    );
    currentRequest[1] <= tagged Valid e;
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
