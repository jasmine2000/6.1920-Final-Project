import RVUtil::*;
import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import DelayLine::*;
import MemTypes::*;
import Cache::*;

interface MainMem;
    method Action put(MainMemReq req);
    method ActionValue#(CacheLine) get();
    method ActionValue#(Word) getWord();
endinterface

module mkMainMemFast(MainMem);
    BRAM_Configure cfg = defaultValue();
    BRAM1Port#(LineAddr, Bit#(32)) bram <- mkBRAM1Server(cfg);
    DelayLine#(1, Word) dl <- mkDL(); // Delay by 20 cycles

    rule deq;
        let r <- bram.portA.response.get();
        dl.put(r);
    endrule    

    method Action put(MainMemReq req);
        let offset = req.addr[5:2];
        bram.portA.request.put(BRAMRequest{
                    write: req.write,
                    responseOnWrite: False,
                    address: req.addr,
                    datain: req.data[offset]});
    endmethod

    method ActionValue#(Word) getWord();
        let r <- dl.get();
        return r;
    endmethod
endmodule

module mkMainMem(MainMem);
    BRAM_Configure cfg = defaultValue();
    BRAM1Port#(LineAddr, CacheLine) bram <- mkBRAM1Server(cfg);
    DelayLine#(40, CacheLine) dl <- mkDL(); // Delay by 20 cycles

    rule deq;
        let r <- bram.portA.response.get();
        dl.put(r);
    endrule

    method Action put(MainMemReq req);
        let address = req.addr >> 4;
        bram.portA.request.put(BRAMRequest{
                    write: req.write,
                    responseOnWrite: False,
                    address: address,
                    datain: req.data});
    endmethod

    method ActionValue#(CacheLine) get();
        let r <- dl.get();
        return r;
    endmethod
endmodule

