import BRAM::*;
import FIFOF::*;
import SpecialFIFOs::*;
import MemTypes::*;
import Vector::*;
import Ehr::*;

interface Cache;
    method Action putFromProc(MainMemReq e);
    method ActionValue#(MainMemResp) getToProc();
    method ActionValue#(MainMemReq) getToMem();
    method Action putFromMem(MainMemResp e);
endinterface



module mkCache(Cache);
  // TODO Write a Cache

  // Writeback -> only write when line is evicted and dirty

  // LineAddr = {tag (19 bits) | index (7 bits)}

  BRAM_Configure cfg = defaultValue;
  BRAM1Port#(CacheIdx, MainMemResp) cacheBram <- mkBRAM1Server(cfg);

  Vector#(128, Reg#(Tag)) tag_array <- replicateM (mkReg (0));
  Vector#(128, Reg#(Bool)) dirty_array <- replicateM (mkReg (False));
  Vector#(128, Reg#(Bool)) valid_array <- replicateM (mkReg (False));


  Vector#(8, Reg#(LineAddr)) store_buffer_addr <- replicateM (mkReg(0));
  Vector#(8, Reg#(MainMemResp)) store_buffer_val <- replicateM (mkReg(0));

  Reg#(Bit#(3)) iidx <- mkReg(0);
  Reg#(Bit#(3)) ridx <- mkReg(0);
  Reg#(Bit#(4)) cnt <- mkReg(0);

  Ehr#(2, Bool) lockL1 <- mkEhr(False);



  FIFOF#(MainMemResp) hitQ <- mkBypassFIFOF;
  Reg#(MainMemReq) missReq <- mkRegU;
  Reg#(ReqStatus) mshr <- mkReg(Ready);

  FIFOF#(MainMemReq) memReqQ <- mkFIFOF;
  FIFOF#(MainMemResp) memRespQ <- mkFIFOF;


  rule fifo_full; 
    if (!memReqQ.notFull())
    begin
      // $display("MemReqQ Full");
    end
    if (!memRespQ.notFull())
    begin
      // $display("memRespQ Full");
    end
    if (!hitQ.notFull())
    begin
      // $display("hitQ Full");
    end

  endrule

  rule clearL1Lock; 
      lockL1[1] <= False; 
  endrule

  rule process_store_buffer if (cnt > 0 && mshr == Ready && !lockL1[1]);
    // $display("process_store_buffer");
    LineAddr addr = store_buffer_addr[ridx];
    MainMemResp data = store_buffer_val[ridx];
    CacheIdx cacheidx = addr[6:0];
    Tag tag = addr[25:7];

    ridx <= ridx + 1;
    cnt <= cnt - 1;


    Bool hit = valid_array[cacheidx] && (tag_array[cacheidx] == tag);

    if (hit)
    begin
      cacheBram.portA.request.put(BRAMRequest{write: True,
                            responseOnWrite: False,
                            address: cacheidx, 
                            datain: data});
      dirty_array[cacheidx] <= True;
      valid_array[cacheidx] <= True;
    end else begin
      mshr <= StartMiss;
      missReq <= MainMemReq{write: 1, addr: addr, data: data};
    end
    

  endrule

  rule load_hit_response if (mshr == LoadHit);
    // $display("load_hit_response");
    let cache_response <- cacheBram.portA.response.get();
    hitQ.enq(cache_response);
    mshr <= Ready;
  endrule


  rule start_miss if (mshr == StartMiss); 
    // $display("StartMiss write: %x, addr: %x", missReq.write, missReq.addr);

    LineAddr addr = missReq.addr; 
    CacheIdx cacheidx = addr[6:0];

    Bool line_is_dirty = dirty_array[cacheidx] && valid_array[cacheidx];
    if (line_is_dirty)  // evict and initiate writeback
    begin
      // Get data from cache
      cacheBram.portA.request.put(BRAMRequest{write: False,
                responseOnWrite: False,
                address: cacheidx, 
                datain: ?});
      mshr <= WriteBack;
    end else begin
      mshr <= SendFillReq;
    end
  endrule

  rule writeback_evicted if (mshr == WriteBack);
    // $display("WritebackEvicted");

    LineAddr addr = missReq.addr; 
    CacheIdx cacheidx = addr[6:0];
    
    let data <- cacheBram.portA.response.get();

    Tag old_tag = tag_array[cacheidx];
    memReqQ.enq(MainMemReq{write: 1,addr: {old_tag, cacheidx}, data: data});
    mshr <= SendFillReq;
  endrule

  rule send_fill_req if (mshr == SendFillReq); 
    // $display("send_fill_req");
    if (missReq.write == 0)
    begin
      memReqQ.enq(missReq);
    end
    mshr <= WaitFillResp;
  endrule

  rule wait_fill_resp if (mshr == WaitFillResp);
    // $display("wait_fill_resp");
    LineAddr addr = missReq.addr; 
    CacheIdx cacheidx = addr[6:0];
    Tag tag = addr[25:7];
    
    if (missReq.write == 0)
    begin
      MainMemResp memResp = memRespQ.first();
      memRespQ.deq();
      hitQ.enq(memResp);

      // Update Cache

      valid_array[cacheidx] <= True;
      tag_array[cacheidx] <= tag;
      dirty_array[cacheidx] <= False;
      cacheBram.portA.request.put(BRAMRequest{write: True,
                          responseOnWrite: False,
                          address: cacheidx, 
                          datain: memResp});
    end else begin
      valid_array[cacheidx] <= True;
      tag_array[cacheidx] <= tag;
      dirty_array[cacheidx] <= True;
      cacheBram.portA.request.put(BRAMRequest{write: True,
                          responseOnWrite: False,
                          address: cacheidx, 
                          datain: missReq.data});

    end
    mshr <= Ready;
  endrule


  method Action putFromProc(MainMemReq e) if (mshr == Ready && cnt < 8);
    
    lockL1[0] <= True;

    Bit#(1) write = e.write; 
    LineAddr addr = e.addr; 
    MainMemResp data = e.data;
    CacheIdx cacheidx = addr[6:0];
    Tag tag = addr[25:7];

    // $display("putFromProc write: %x, addr: %x", write, addr);

    if (write == 0) // Load
    begin
      Bool stb_found = False;
      MainMemResp stb_data = 0;
      for (Bit#(4) i = 0; (i)<cnt; i=i+1)
      begin
          if (store_buffer_addr[ridx + i[2:0]] == addr)
          begin
            stb_data = store_buffer_val[ridx + i[2:0]];
            stb_found = True;
          end
      end
      if (stb_found) 
      begin
        // $display("stb found");
        hitQ.enq(stb_data);
      end else begin
        Bool hit = valid_array[cacheidx] && (tag_array[cacheidx] == tag);
        if (hit) 
        begin
            cacheBram.portA.request.put(BRAMRequest{write: False,
                            responseOnWrite: False,
                            address: cacheidx, 
                            datain: ?});
            mshr <= LoadHit;
        end else begin 
            missReq <= e;
            mshr <= StartMiss;
        end
      end
    end else begin // Store
      iidx <= iidx + 1;
      cnt <= cnt + 1;

      store_buffer_val[iidx] <= data;
      store_buffer_addr[iidx] <= addr;

    end

  endmethod

  method ActionValue#(MainMemResp) getToProc();
    let data = hitQ.first();
    hitQ.deq();
    return data;
  endmethod

  method ActionValue#(MainMemReq) getToMem();
    let memReq = memReqQ.first();
    memReqQ.deq();
    return memReq;
  endmethod

  method Action putFromMem(MainMemResp e);
    memRespQ.enq(e);
  endmethod

endmodule
