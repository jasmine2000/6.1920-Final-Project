import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import MemTypes::*;
import Vector::*;
import Ehr::*;
import StoreBuffer::*;

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
  
  Vector#(4, BRAM1PortBE#(CacheIndex, CacheLine, 64) ) cache <- replicateM(mkBRAM1ServerBE(cfg));
  Vector#(4, Vector#(32, Reg#(CacheTag))) tags <- replicateM(replicateM(mkReg('hfff)));
  Vector#(4, Vector#(32, Reg#(Bit#(1)))) dirty <- replicateM(replicateM(mkReg(0)));
  
  Vector#(32, Vector#(4, Reg#(Bit#(2)))) rrpv <- replicateM(replicateM(mkReg(2'h3)));

  Ehr#(2, Maybe#(CacheReq)) currentRequest <- mkEhr(Invalid);
  Reg#(Maybe#(CacheReq)) stallRequest <- mkReg(Invalid);

  StoreBuffer store_buffer <- mkstorebuffer();

  Reg#(Mshr) state <- mkReg(Ready);

  FIFO#(Word) toProcQueue <- mkBypassFIFO;
  FIFO#(MainMemReq) toMemQueue <- mkBypassFIFO;

  Reg#(Maybe#(CacheLine)) memResp <- mkReg(Invalid);
  Reg#(Bit#(2)) currentWay <- mkReg(0);

  Reg#(Bool) debug <- mkReg(False);


  function ActionValue#(Bit#(2)) replacementPolicy(CacheIndex idx);
    
    Bit#(2) max_upper = ?;
    Bit#(2) way_upper = ?;

    Bit#(2) max_lower = ?;
    Bit#(2) way_lower = ?;

    Bit#(2) max = ?;
    Bit#(2) way = ?;

    if (rrpv[idx][0] > rrpv[idx][1]) begin
      max_lower = rrpv[idx][0];
      way_lower = 2'h0;
    end else begin
      max_lower = rrpv[idx][1];
      way_lower = 2'h1;
    end

    if (rrpv[idx][2] > rrpv[idx][3]) begin
      max_upper = rrpv[idx][2];
      way_upper = 2'h2;
    end else begin
      max_upper = rrpv[idx][3];
      way_upper = 2'h3;
    end

    if (max_lower > max_upper) begin
      max = max_lower;
      way = way_lower;
    end else begin
      max = max_upper;
      way = way_upper;
    end

  return (
    actionvalue
      // Increment all if 3 not found
      for (Integer i = 0; i < 4; i = i + 1) begin
        if (fromInteger(i)!=way) rrpv[idx][i] <= rrpv[idx][i] + (2'h3 - max);
      end
      rrpv[idx][way] <= 2'h2;
      return  way;
    endactionvalue
  );


  endfunction

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
        
        rrpv[address.index][way] <= 2'b0;

        // Read Line from BRAM
        let hitreq = BRAMRequestBE{
          writeen: '0,
          address: address.index,
          datain: ?,
          responseOnWrite: False
        };
        cache[way].portA.request.put(hitreq);
        state <= Hit;
        currentWay <= fromInteger(way);

      end else begin // load miss
        if (debug) $display("%x req load miss", req.addr);
        
        Bit#(2) newWay <- replacementPolicy(address.index);// currentWay + 1; // TODO replacement policy
        currentWay <= newWay;

        if (dirty[newWay][address.index] == 1) begin
          state <= Writeback;
          let dirtyLine = BRAMRequestBE{
            writeen: '0,
            address: address.index,
            datain: ?,
            responseOnWrite: False
          };
          cache[newWay].portA.request.put(dirtyLine);
        end else state <= SendFillReq;
      end

    end else begin // Store
      if (debug) $display("%x store", req.addr);
      store_buffer.enq(req);
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
      $display("SHOULD NOT GET HERE");
    end
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
      
      let newLine = BRAMRequestBE{
        writeen: '1,
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

      let newLine = BRAMRequestBE{
        writeen: '1,
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
    if (store_buffer.isEmpty() && isValid(stallRequest)) begin // cleared sbuff
      currentRequest[1] <= stallRequest;
      stallRequest <= tagged Invalid;
    end else currentRequest[1] <= tagged Invalid;
  endrule

  rule deqStoreBuff if (
    state == Ready && 
    isValid(currentRequest[1]) == False
    );

    let req <- store_buffer.deq();
    let address = getAddressFields(req.addr);

    if (debug) $display("%x store buff", req.addr);

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

    if (hit) begin // store hit
      rrpv[address.index][way] <= 2'b0;
      
      Bit#(64) write_en = {60'b0, req.byte_en};
      Bit#(64) long_blockOffset = zeroExtend(address.blockOffset);
      write_en = write_en << (4*long_blockOffset);

      CacheLine newCacheLine = newVector();
      newCacheLine[address.blockOffset] = req.data;

      let newLine = BRAMRequestBE{
        writeen: write_en,
        address: address.index,
        datain: newCacheLine,
        responseOnWrite: False
      };
      
      cache[way].portA.request.put(newLine);
      dirty[way][address.index] <= 1;

      if (store_buffer.cnt()==1 && isValid(stallRequest)) begin // cleared sbuff
        currentRequest[1] <= stallRequest;
        stallRequest <= tagged Invalid;
      end else currentRequest[1] <= tagged Invalid;
      state <= Ready;


    end else begin // store miss
      
      Bit#(2) newWay <- replacementPolicy(address.index);// currentWay + 1; // TODO replacement policy
      currentWay <= newWay;

      if (dirty[newWay][address.index] == 1) begin
        state <= Writeback;
        let dirtyLine = BRAMRequestBE{
          writeen: '0,
          address: address.index,
          datain: ?,
          responseOnWrite: False
        };
        cache[newWay].portA.request.put(dirtyLine);
      end else state <= SendFillReq;

      currentRequest[1] <= tagged Valid req;
    end

  endrule

  method Action putFromProc(CacheReq e) if (
    state == Ready && 
    store_buffer.isFull() == False &&
    isValid(currentRequest[0]) == False &&
    isValid(stallRequest) == False
    );

    Bool found = False;
    Word ret = ?;
    Bool partialWrite = False;

    if (e.byte_en == 4'b0) begin
      let sbufffound = store_buffer.search(e);
      if (isValid(sbufffound)) begin
        let sbufffoundreq = fromMaybe(?, sbufffound);
        if (sbufffoundreq.byte_en == 4'b1111) begin
          ret = sbufffoundreq.data;
          found = True;
        end else begin
          partialWrite = True;
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
