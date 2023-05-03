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
    Vector#(4, Reg#(CacheReq)) storeBuff <- replicateM(mkReg(?));
    Reg#(Bit#(2)) sBuffEnq <- mkReg(0);
    Reg#(Bit#(2)) sBuffDeq <- mkReg(0);
    Reg#(Bit#(3)) sBuffCnt <- mkReg(0);

    method Action enq(CacheReq e) if (sBuffCnt < 4);
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
        
        for (Bit#(3) i = 0; (i)<sBuffCnt; i=i+1)
        begin
            if (req.addr == storeBuff[sBuffDeq + i[1:0]].addr)
            begin
                ret = tagged Valid storeBuff[sBuffDeq + i[1:0]];
            end
        end
        return ret;
    endmethod

    method Bool isEmpty();
        return sBuffCnt == 0;
    endmethod 

    method Bool isFull();
        return sBuffCnt == 2;
    endmethod 

endmodule



