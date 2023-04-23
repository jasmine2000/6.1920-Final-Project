import ClientServer::*;
import GetPut::*;
import Randomizable::*;
import MainMem::*;
import MemTypes::*;
import Cache::*;


module mkBeveren(Empty);
    let verbose = False;
    Randomize#(MainMemReq) randomMem <- mkGenericRandomizer;
    MainMem mainRef <- mkMainMemFast(); //Initialize both to 0
    MainMem mainMem <- mkMainMem(); //Initialize both to 0
    Cache cache <- mkCache;
    
    Reg#(Bit#(32)) deadlockChecker <- mkReg(0); 
    Reg#(Bit#(32)) counterIn <- mkReg(0); 
    Reg#(Bit#(32)) counterOut <- mkReg(0); 
    Reg#(Bool) doinit <- mkReg(True);

    rule connectCacheDram;
        let lineReq <- cache.getToMem();
        mainMem.put(lineReq);
    endrule
    rule connectDramCache;
        let resp <- mainMem.get;
        cache.putFromMem(resp);
    endrule

    rule start (doinit);
        randomMem.cntrl.init;
        doinit <= False;
    endrule 

    rule reqs (counterIn <= 50000);
       let newrand <- randomMem.next;
       deadlockChecker <= 0;
       MainMemReq newreq = newrand;
       newreq.addr = {0,newreq.addr[13:2],2'b0};
       
       let byte_en = 0;
       case (newreq.write) matches
        False: byte_en = 4'b0000;
        True: byte_en = 4'b1111;
       endcase

       CacheReq cachereq = CacheReq{
        byte_en: byte_en,
        addr: zeroExtend(newreq.addr),
        data: ?
       };

       if ( newreq.write == False) counterIn <= counterIn + 1;
       else begin
       CacheBlockOffset block_offset = newreq.addr[5:2];
       cachereq.data = newreq.data[block_offset];
       end

       mainRef.put(newreq);
       cache.putFromProc(cachereq);
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
           $finish;
       end
    endrule
endmodule
