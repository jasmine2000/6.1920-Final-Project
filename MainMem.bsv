import RVUtil::*;
import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import DelayLine::*;
import MemTypes::*;
import Cache::*;

interface MainMem;
    method Action put(MainMemReq req);
    method Action putWord(CacheReq req);
    method ActionValue#(CacheLine) get();
    method ActionValue#(Word) getWord();
endinterface

module mkMainMemFast(MainMem);
    BRAM_Configure cfg = defaultValue();
    BRAM1PortBE#(WordAddr, Bit#(32), 4) bram <- mkBRAM1ServerBE(cfg);
    DelayLine#(1, Word) dl <- mkDL(); // Delay by 20 cycles

    rule deq;
        let r <- bram.portA.response.get();
        dl.put(r);
    endrule    

    method Action putWord(CacheReq req);
        bram.portA.request.put(BRAMRequestBE{
                    writeen: req.byte_en,
                    responseOnWrite: False,
                    address: req.addr,
                    datain: req.data});
    endmethod

    method ActionValue#(Word) getWord();
        let r <- dl.get();
        return r;
    endmethod
endmodule

module mkMainMem(MainMem);
    BRAM_Configure cfg = defaultValue();
    BRAM1Port#(LineAddr, CacheLine) bram <- mkBRAM1Server(cfg);
    DelayLine#(10, CacheLine) dl <- mkDL(); // Delay by 20 cycles

    rule deq;
        let r <- bram.portA.response.get();
        dl.put(r);
    endrule

    method Action put(MainMemReq req);
        bram.portA.request.put(BRAMRequest{
                    write: req.write,
                    responseOnWrite: False,
                    address: req.addr,
                    datain: req.data});
    endmethod

    method ActionValue#(CacheLine) get();
        let r <- dl.get();
        return r;
    endmethod
endmodule

