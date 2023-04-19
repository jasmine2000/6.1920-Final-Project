import RVUtil::*;
import BRAM::*;
import FIFO::*;
import SpecialFIFOs::*;
import DelayLine::*;
import MemTypes::*;
import Cache::*;

interface MainMem;
    method Action put(MainMemReq req);
    method ActionValue#(MainMemResp) get();
    method ActionValue#(Word) getWord();
endinterface

module mkMainMemFast(MainMem);
    BRAM_Configure cfg = defaultValue();
    BRAM1Port#(LineAddr, Bit#(512)) bram <- mkBRAM1Server(cfg);
    DelayLine#(1, MainMemResp) dl <- mkDL(); // Delay by 20 cycles
    FIFO#(Bit#(4)) offsetQueue <- mkFIFO;

    rule deq;
        let r <- bram.portA.response.get();
        dl.put(r);
    endrule    

    method Action put(MainMemReq req);
        bram.portA.request.put(BRAMRequest{
                    write: unpack(req.write),
                    responseOnWrite: False,
                    address: req.addr << 4,
                    datain: req.data});
        if (req.write == 0) offsetQueue.enq(req.addr[3:0]);
    endmethod

    method ActionValue#(MainMemResp) get();
        let r <- dl.get();
        return r;
    endmethod

    method ActionValue#(Word) getWord();
        let r <- dl.get();

        Bit#(9) offset = zeroExtend(offsetQueue.first());
        offsetQueue.deq();

        Bit#(9) start_idx = 511 - offset * 32;

        return r[start_idx:start_idx - 32];
    endmethod
endmodule

module mkMainMem(MainMem);
    BRAM_Configure cfg = defaultValue();
    BRAM1Port#(LineAddr, Bit#(512)) bram <- mkBRAM1Server(cfg);
    DelayLine#(40, MainMemResp) dl <- mkDL(); // Delay by 20 cycles
    FIFO#(Bit#(4)) offsetQueue <- mkFIFO;

    rule deq;
        let r <- bram.portA.response.get();
        dl.put(r);
    endrule    

    method Action put(MainMemReq req);
        bram.portA.request.put(BRAMRequest{
                    write: unpack(req.write),
                    responseOnWrite: False,
                    address: req.addr,
                    datain: req.data});
        if (req.write == 0) offsetQueue.enq(req.addr[3:0]);
    endmethod

    method ActionValue#(MainMemResp) get();
        let r <- dl.get();
        return r;
    endmethod

    method ActionValue#(Word) getWord();
        let r <- dl.get();

        Bit#(9) offset = zeroExtend(offsetQueue.first());
        offsetQueue.deq();

        Bit#(9) start_idx = 511 - offset * 32;

        return r[start_idx:start_idx - 32];
    endmethod
endmodule

