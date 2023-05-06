import RVUtil::*;
import BRAM::*;
import pipelined::*;
import FIFO::*;

// Imports from Beveren
import ClientServer::*;
import GetPut::*;
import Randomizable::*;
import MemTypes::*;
import ICache::*;
import Cache::*;


module mktop_pipelined(Empty);
    // Instantiate Cache
    ICache cacheInstruction <- mkICache;
    Cache cacheData <- mkCache;
    
    FIFO#(Bit#(1)) memArbiterFifo <- mkFIFO;
    
    // Instantiate the dual ported memory
    BRAM_Configure cfg = defaultValue();
    cfg.loadFormat = tagged Hex "memlines.vmh";
    BRAM1Port#(LineAddr, CacheLine) bram <- mkBRAM1Server(cfg);

    

    RVIfc rv_core <- mkpipelined;
    Reg#(MainMemReq) ireq <- mkRegU;
    Reg#(MainMemReq) dreq <- mkRegU;
    FIFO#(CacheReq) mmioreq <- mkFIFO;
    let debug = False;
    Reg#(Bit#(32)) cycle_count <- mkReg(0);

    Reg#(Bit#(32)) icache_miss <- mkReg(0);
    Reg#(Bit#(32)) dcache_miss <- mkReg(0);

    rule tic;
	    cycle_count <= cycle_count + 1;
    endrule
    
    rule requestIProcToCache;
        CacheReq req <- rv_core.getIReq;
        if (debug) $display("Get IReq from Proc ", fshow(req));
        cacheInstruction.putFromProc(req);
    endrule

    
    rule requestICacheToMem;
        icache_miss <= icache_miss + 1;
        MainMemReq req <- cacheInstruction.getToMem();
        if (!req.write) memArbiterFifo.enq(1'b0);
        if (debug) $display("Get IReq from Cache ", fshow(req));
        ireq <= req;
        bram.portA.request.put(BRAMRequest{
                    write: req.write,
                    responseOnWrite: False,
                    address: req.addr,
                    datain: req.data});
    endrule

    rule responseICacheToProc;
        let req <- cacheInstruction.getToProc();
        if (debug) $display("Get IResp from Cache ", fshow(req));
        rv_core.getIResp(req);
    endrule

    rule requestDProcToCache;
        let req <- rv_core.getDReq;
        if (debug) $display("Get DReq from Proc ", fshow(req));
        cacheData.putFromProc(req);
    endrule

    
    rule requestDCacheToMem;
        dcache_miss <= dcache_miss + 1;
        let req <- cacheData.getToMem();
        if (!req.write) memArbiterFifo.enq(1'b1);
        if (debug) $display("Get DReq from Cache ", fshow(req));
        dreq <= req;
        bram.portA.request.put(BRAMRequest{
                    write: req.write,
                    responseOnWrite: False,
                    address: req.addr,
                    datain: req.data});
    endrule

    rule responseDCacheToProc;
        Word req <- cacheData.getToProc();
        if (debug) $display("Get DResp from Cache ", fshow(req));
        rv_core.getDResp(req);
    endrule

    
    rule responseMemToCache;
        Bit#(1) isDcacheResp = memArbiterFifo.first();
        memArbiterFifo.deq();
        let x <- bram.portA.response.get();
        
        if (isDcacheResp=='1)
        begin
            let req = dreq;
            if (debug) $display("Get DResp from Mem", fshow(req), fshow(x));
            req.data = x;
            cacheData.putFromMem(x);
        end else 
        begin
            let req = ireq;
            if (debug) $display("Get IResp from Mem", fshow(req), fshow(x));
            req.data = x;
            cacheInstruction.putFromMem(x);
        end
        

    endrule


    rule requestMMIO;
        CacheReq req <- rv_core.getMMIOReq;
        if (debug) $display("Get MMIOReq", fshow(req));
        if (req.byte_en == 'hf) begin
            if (req.addr == 'hf000_fff4) begin
                // Write integer to STDERR
                        $fwrite(stderr, "%0d", req.data);
                        $fflush(stderr);
            end
        end
        if (req.addr ==  'hf000_fff0) begin
                // Writing to STDERR
                $fwrite(stderr, "%c", req.data[7:0]);
                $fflush(stderr);
        end else
            if (req.addr == 'hf000_fff8) begin
            // Exiting Simulation
                $display("Icache Misses: %x", icache_miss);
                $display("Dcache Misses: %x", dcache_miss);
                if (req.data == 0) begin
                        $fdisplay(stderr, "  [0;32mPASS[0m");
                end
                else
                    begin
                        $fdisplay(stderr, "  [0;31mFAIL[0m (%0d)", req.data);
                    end
                $fflush(stderr);
                $finish;
            end

        mmioreq.enq(req);
    endrule

    rule responseMMIO;
        CacheReq req = mmioreq.first();
        mmioreq.deq();
        if (debug) $display("Put MMIOResp", fshow(req));
        rv_core.getMMIOResp(req.data);
    endrule
    
endmodule
