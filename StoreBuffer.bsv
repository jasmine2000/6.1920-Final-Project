import MemTypes::*;
import Vector::*;


interface StoreBuffer;
    method Action enq(CacheReq e);
    method ActionValue#(CacheReq) deq();
    method Maybe#(CacheReq) search(CacheReq e);
    method Bool isEmpty();
    method Bool isFull();
endinterface 


module mkstorebuffer(StoreBuffer);
    Vector#(8, Reg#(CacheReq)) storeBuff <- replicateM(mkReg(?));
    Reg#(Bit#(3)) sBuffEnq <- mkReg(0);
    Reg#(Bit#(3)) sBuffDeq <- mkReg(0);
    Reg#(Bit#(4)) sBuffCnt <- mkReg(0);

    method Action enq(CacheReq e) if (sBuffCnt < 8);
        storeBuff[sBuffEnq] <= e;
        sBuffEnq <= sBuffEnq + 1;
        sBuffCnt <= sBuffCnt + 1;
    endmethod
    
    method ActionValue#(CacheReq) deq() if (sBuffCnt > 0);
        sBuffDeq <= sBuffDeq + 1;
        sBuffCnt <= sBuffCnt - 1;
        return storeBuff[sBuffDeq];
    endmethod

    method Maybe#(CacheReq) search(CacheReq req);
        Maybe#(CacheReq) ret = tagged Invalid;
        
        for (Bit#(4) i = 0; (i)<sBuffCnt; i=i+1)
        begin
            if (req.addr == storeBuff[sBuffDeq + i[2:0]].addr)
            begin
                ret = tagged Valid storeBuff[sBuffDeq + i[2:0]];
            end
        end
        return ret;
    endmethod

    method Bool isEmpty();
        return sBuffCnt == 0;
    endmethod 

    method Bool isFull();
        return sBuffCnt == 8;
    endmethod 

endmodule



