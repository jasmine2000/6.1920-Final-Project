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

module mkICache(ICache);
  BRAM_Configure cfg = defaultValue();
  
  Vector#(4, BRAM2Port#(Bit#(7), CacheLine) ) cache <- replicateM(mkBRAM2Server(cfg));
  Vector#(4, Vector#(128, Reg#(CacheTag))) tags <- replicateM(replicateM(mkReg('hfff)));
  Vector#(4, Vector#(128, Reg#(Bit#(1)))) dirty <- replicateM(replicateM(mkReg(0)));

  Ehr#(2, Maybe#(CacheReq)) currentRequest <- mkEhr(Invalid);

  Reg#(Mshr) state <- mkReg(Ready);

  FIFO#(Word) toProcQueue <- mkBypassFIFO;
  FIFO#(MainMemReq) toMemQueue <- mkBypassFIFO;

  Reg#(Maybe#(CacheLine)) memResp <- mkReg(Invalid);
  Reg#(Bit#(2)) currentWay <- mkReg(0);

  Reg#(Bool) debug <- mkReg(False);

  rule newReq if (
    state == Ready &&
    isValid(currentRequest[1]) == True
    );

    let req = fromMaybe(?, currentRequest[1]);
    let address = getAddressFields(req.addr);

    if (debug && req.byte_en == 0) $display("read %x\n", req.addr);
    if (debug && req.byte_en != 0) $display("write %x, %x\n", req.addr, req.data);

    if (req.byte_en == 0) begin // load

        // search all sets for matching tag
        Bool hit = False;
        Integer way = ?;
        
        for (Integer i = 0; i < 4; i = i+1)
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
          currentWay <= fromInteger(way);

        end else begin // load miss
          if (debug) $display("%x req load miss", req.addr);
          
          Bit#(2) newWay = currentWay + 1; // TODO replacement policy
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
        $display("illegal write");
        $finish;
    end
  endrule

  rule getHit if (state == Hit); // load/store hit
    if (debug) $display("load hit");
    CacheLine lineResp <- cache[currentWay].portA.response.get();

    let req = fromMaybe(?, currentRequest[1]);
    let address = getAddressFields(req.addr);

    if (req.byte_en == 0) begin // Load
      toProcQueue.enq(lineResp[address.blockOffset]);
    end else begin
        $display("illegal write");
        $finish;
    end
    currentRequest[1] <= tagged Invalid;
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
        $display("illegal write");
        $finish;
    end

    memResp <= tagged Invalid;
    state <= Ready;
    currentRequest[1] <= tagged Invalid;
  endrule

  method Action putFromProc(CacheReq e) if (
    state == Ready && 
    isValid(currentRequest[0]) == False
    );
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

  method Action putFromMem(CacheLine e);
    memResp <= tagged Valid e;
    if (debug) $display("%x returned from mem", e);
  endmethod


endmodule
