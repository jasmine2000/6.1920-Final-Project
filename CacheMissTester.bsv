import ClientServer::*;
import GetPut::*;
import Randomizable::*;
import MainMem::*;
import MemTypes::*;
import Cache::*;


module mkCacheMissTester(Empty);
    let verbose = False;
    Randomize#(CacheReq) randomCacheReq <- mkGenericRandomizer;

    MainMem mainRef <- mkMainMemFast(); //Initialize both to 0
    MainMem mainMem <- mkMainMem(); //Initialize both to 0
    Cache cache <- mkCache;
    
    Reg#(Bit#(32)) deadlockChecker <- mkReg(0); 
    Reg#(Bit#(32)) counterIn <- mkReg(0); 
    Reg#(Bit#(32)) counterOut <- mkReg(0); 
    Reg#(Bool) doinit <- mkReg(True);

    Reg#(Bit#(32)) missCount <- mkReg(0); 

    rule connectCacheDram;
        let lineReq <- cache.getToMem();
        missCount <= missCount + 1;
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

    rule test_srrip (counterIn <= 10);
        CacheReq newreq = ?;
        case (counterIn) matches
            0 : newreq.addr = 32'b000_00001_0000_00;
            1 : newreq.addr = 32'b001_00001_0000_00;
            2 : newreq.addr = 32'b000_00001_0000_00;
            3 : newreq.addr = 32'b001_00001_0000_00;
            4 : newreq.addr = 32'b100_00001_0000_00;
            5 : newreq.addr = 32'b011_00001_0000_00;
            6 : newreq.addr = 32'b110_00001_0000_00;
            7 : newreq.addr = 32'b101_00001_0000_00;
            8 : newreq.addr = 32'b000_00001_0000_00;
            9 : newreq.addr = 32'b001_00001_0000_00;
        endcase
        newreq.byte_en = 4'b0;
        
        counterIn <= counterIn + 1;

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
       if (counterOut == 10) begin
           $display("PASSED\n");
           $display("Cache Misses: %x", missCount);
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