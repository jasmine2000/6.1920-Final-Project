import ClientServer::*;
import GetPut::*;
import Randomizable::*;
import MainMem::*;
import MemTypes::*;
import Cache::*;


module mkBeveren(Empty);
    let verbose = False;
    Randomize#(CacheReq) randomCacheReq <- mkGenericRandomizer;

    MainMem mainRef <- mkMainMemFast(); //Initialize both to 0
    MainMem mainMem <- mkMainMem(); //Initialize both to 0
    Cache cache <- mkCache;
    
    Reg#(Bit#(32)) deadlockChecker <- mkReg(0); 
    Reg#(Bit#(32)) counterIn <- mkReg(0); 
    Reg#(Bit#(32)) counterOut <- mkReg(0); 
    Reg#(Bool) doinit <- mkReg(True);

    Reg#(Bit#(32)) seqCount <- mkReg(0); 

    rule connectCacheDram;
        let lineReq <- cache.getToMem();
        mainMem.put(lineReq);
    endrule
    rule connectDramCache;
        let resp <- mainMem.get;
        cache.putFromMem(resp);
    endrule

    rule start (doinit);
        randomCacheReq.cntrl.init;
        doinit <= False;
    endrule 

    rule reqs_cacheline (counterIn <= 500);
       let newrand <- randomCacheReq.next;
       deadlockChecker <= 0;
       CacheReq newreq = newrand;
       newreq.addr = {0,newreq.addr[3:0], 2'b00};

       if ( newreq.byte_en == 4'b0) counterIn <= counterIn + 1;

        if (verbose) $display("Sent byte_en: %x, addr: %x, data %x", newreq.byte_en, newreq.addr, newreq.data);

       mainRef.putWord(newreq);
       cache.putFromProc(newreq);
    endrule

    rule reqs_cache (counterIn <= 6000 && counterIn > 500);
       let newrand <- randomCacheReq.next;
       deadlockChecker <= 0;
       CacheReq newreq = newrand;
       newreq.addr = {0,newreq.addr[7:0], 2'b00};

       if ( newreq.byte_en == 4'b0) counterIn <= counterIn + 1;

        if (verbose) $display("Sent byte_en: %x, addr: %x, data %x", newreq.byte_en, newreq.addr, newreq.data);

       mainRef.putWord(newreq);
       cache.putFromProc(newreq);
    endrule

    rule reqs_mem (counterIn <= 50000 && counterIn > 6000);
       let newrand <- randomCacheReq.next;
       deadlockChecker <= 0;
       CacheReq newreq = newrand;
       newreq.addr = {0,newreq.addr[10:0], 2'b00};

       if ( newreq.byte_en == 4'b0) counterIn <= counterIn + 1;

        if (verbose) $display("Sent byte_en: %x, addr: %x, data %x", newreq.byte_en, newreq.addr, newreq.data);

       mainRef.putWord(newreq);
       cache.putFromProc(newreq);
    endrule




    rule resps;
       counterOut <= counterOut + 1; 
       if (verbose) $display("Got response\n");
       let resp1 <- cache.getToProc() ;
       let resp2 <- mainRef.getWord();
       if (resp1 != resp2) begin
           $display("The cache answered %x instead of %x\n", resp1, resp2);
           $display("FAILED\n");
           $finish;
       end 
       if (counterOut == 49999) begin
           $display("PASSED\n");
           $finish;
       end
    endrule

    rule deadlockerC;
       deadlockChecker <= deadlockChecker + 1;
       if (deadlockChecker > 1000) begin
           $display("The cache deadlocks\n");
           $display(fshow(counterOut), fshow(counterIn));
           $finish;
       end
    endrule
endmodule
