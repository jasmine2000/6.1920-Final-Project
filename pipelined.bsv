import FIFO::*;
import SpecialFIFOs::*;
import RegFile::*;
import RVUtil::*;
import Vector::*;
import KonataHelper::*;
import Printf::*;
import Ehr::*;

import MemTypes::*;

interface RVIfc;
    method ActionValue#(CacheReq) getIReq();
    method Action getIResp(ICacheResp a);
    method ActionValue#(CacheReq) getDReq();
    method Action getDResp(Word a);
    method ActionValue#(CacheReq) getMMIOReq();
    method Action getMMIOResp(Word a);
endinterface
typedef struct { Bool isUnsigned; Bit#(2) size; Bit#(2) offset; Bool mmio; } MemBusiness deriving (Eq, FShow, Bits);

function Bool isMMIO(Bit#(32) addr);
    Bool x = case (addr) 
        32'hf000fff0: True;
        32'hf000fff4: True;
        32'hf000fff8: True;
        default: False;
    endcase;
    return x;
endfunction

typedef struct { Bit#(32) pc;
                 Bit#(32) ppc;
                 Bit#(1) epoch; 
                 KonataId k_id; // <- This is a unique identifier per instructions, for logging purposes
             } F2D deriving (Eq, FShow, Bits);

typedef struct { 
    DecodedInst dinst;
    Bit#(32) pc;
    Bit#(32) ppc;
    Bit#(1) epoch;
    Bit#(32) rv1; 
    Bit#(32) rv2; 
    KonataId k_id; // <- This is a unique identifier per instructions, for logging purposes
    } D2E deriving (Eq, FShow, Bits);

typedef struct { 
    MemBusiness mem_business;
    Bit#(32) data;
    DecodedInst dinst;
    KonataId k_id; // <- This is a unique identifier per instructions, for logging purposes
    Bool valid;
} E2W deriving (Eq, FShow, Bits);

(* synthesize *)
module mkpipelined(RVIfc);
    // Interface with memory and devices
    FIFO#(CacheReq) toImem <- mkBypassFIFO;
    FIFO#(ICacheResp) fromImem <- mkBypassFIFO;
    FIFO#(CacheReq) toDmem <- mkBypassFIFO;
    FIFO#(Word) fromDmem <- mkBypassFIFO;
    FIFO#(CacheReq) toMMIO <- mkBypassFIFO;
    FIFO#(Word) fromMMIO <- mkBypassFIFO;

    Ehr#(2, Bit#(32)) pc <- mkEhr(0);
    Vector#(32, Reg#(Bit#(32))) rf <- replicateM(mkReg(0));

    Vector#(2, FIFO#(F2D)) f2dQueues <- replicateM(mkFIFO);
    Reg#(Bit#(1)) f2d_enq <- mkReg(0);
    Reg#(Bit#(1)) f2d_deq <- mkReg(0);

    Vector#(2, FIFO#(D2E)) d2eQueues <- replicateM(mkFIFO);
    Reg#(Bit#(1)) d2e_enq <- mkReg(0);
    Reg#(Bit#(1)) d2e_deq <- mkReg(0);

    Vector#(2, FIFO#(E2W)) e2wQueues <- replicateM(mkFIFO);
    Reg#(Bit#(1)) e2w_enq <- mkReg(0);
    Reg#(Bit#(1)) e2w_deq <- mkReg(0);

    Ehr#(2, Bit#(1)) epoch <- mkEhr(1'b0);
    Vector#(32, Ehr#(2, Bit#(2))) scoreboard <- replicateM(mkEhr(0));

    Bool debug = False;

	// Code to support Konata visualization
    String dumpFile = "output.log" ;
    let lfh <- mkReg(InvalidFile);
	Reg#(KonataId) fresh_id <- mkReg(0);
	Reg#(KonataId) commit_id <- mkReg(0);

	FIFO#(KonataId) retired <- mkFIFO;
	FIFO#(KonataId) squashed <- mkFIFO;
    
    Reg#(Bool) starting <- mkReg(True);

	rule do_tic_logging;
        if (starting) begin
            let f <- $fopen(dumpFile, "w") ;
            lfh <= f;
            $fwrite(f, "Kanata\t0004\nC=\t1\n");
            starting <= False;
        end
		konataTic(lfh);
	endrule
		
    rule fetch if (!starting);
        Bit#(32) pc_fetched = pc[1];
        Bit#(32) next_pc_predicted = pc_fetched + 4;
        pc[1] <= next_pc_predicted;
        if(debug) $display("Fetch %x", pc_fetched);
        // You should put the pc that you fetch in pc_fetched
        // Below is the code to support Konata's visualization
		let iid <- fetch1Konata(lfh, fresh_id, 0);
        labelKonataLeft(lfh, iid, $format("PC %x ",pc_fetched));
        // TODO implement fetch
        
        let req = CacheReq {
            byte_en : 0,
            addr : pc_fetched,
            data : 0
        };
        toImem.enq(req);

        f2dQueues[f2d_enq].enq(F2D { 
            pc: pc_fetched,
            ppc: next_pc_predicted,
            epoch: epoch[1],
            k_id: iid
        });
        f2d_enq <= f2d_enq + 1;

    endrule

    rule decode if (!starting);
        let from_fetch = f2dQueues[f2d_deq].first();

        let resp = fromImem.first();
        let instr = resp.i1;
        let decodedInst = decodeInst(instr);

        decodeKonata(lfh, from_fetch.k_id);
        labelKonataLeft(lfh,from_fetch.k_id, $format("decoded %x ", instr));

        if (debug) $display("[Decode] ", fshow(decodedInst));

        let fields = getInstFields(instr);
        let rs1_idx = fields.rs1;
        let rs2_idx = fields.rs2;
        let rd_idx = fields.rd;

        if (scoreboard[rs1_idx][0] == 0 && 
            scoreboard[rs2_idx][0] == 0) begin // no data hazard
            
            f2dQueues[f2d_deq].deq();
            f2d_deq <= f2d_deq + 1;

            fromImem.deq();

            let rs1 = (rs1_idx ==0 ? 0 : rf[rs1_idx]);
            let rs2 = (rs2_idx == 0 ? 0 : rf[rs2_idx]);

            d2eQueues[d2e_enq].enq(D2E {
                dinst: decodedInst,
                pc: from_fetch.pc,
                ppc: from_fetch.ppc,
                epoch: from_fetch.epoch,
                rv1: rs1,
                rv2: rs2,
                k_id: from_fetch.k_id
            });
            d2e_enq <= d2e_enq + 1;

            if (decodedInst.valid_rd) begin
                if (rd_idx != 0) begin 
                    scoreboard[rd_idx][0] <= scoreboard[rd_idx][0] + 1;
                    if(debug) $display("Stalling %x", rd_idx);
                end
            end
        end
    endrule

    rule execute if (!starting);
        let from_decode = d2eQueues[d2e_deq].first();
        d2eQueues[d2e_deq].deq();
        d2e_deq <= d2e_deq + 1;
        
        let current_id = from_decode.k_id;
   	    executeKonata(lfh, current_id);
        labelKonataLeft(lfh,current_id, $format("executing "));

        let dInst = from_decode.dinst;
        if (debug) $display("[Execute] ", fshow(dInst));

        let fields = getInstFields(dInst.inst);

        if (from_decode.epoch == epoch[0]) begin
            let rv1 = from_decode.rv1;
            let rv2 = from_decode.rv2;
            let pc1 = from_decode.pc;

            let imm = getImmediate(dInst);
            Bool mmio = False;
            let data = execALU32(dInst.inst, rv1, rv2, imm, pc1);
            let isUnsigned = 0;
            let funct3 = fields.funct3;
            let size = funct3[1:0];
            let addr = rv1 + imm;
            Bit#(2) offset = addr[1:0];

            if (isMemoryInst(dInst)) begin
                // Technical details for load byte/halfword/word
                let shift_amount = {offset, 3'b0};
                let byte_en = 0;
                case (size) matches
                2'b00: byte_en = 4'b0001 << offset;
                2'b01: byte_en = 4'b0011 << offset;
                2'b10: byte_en = 4'b1111 << offset;
                endcase
                data = rv2 << shift_amount;
                addr = {addr[31:2], 2'b0};
                isUnsigned = funct3[2];
                let type_mem = (dInst.inst[5] == 1) ? byte_en : 0;
                let req = CacheReq {byte_en : type_mem,
                        addr : addr,
                        data : data};
                if (isMMIO(addr)) begin 
                    if (debug) $display("[Execute] MMIO", fshow(req));
                    toMMIO.enq(req);
                    labelKonataLeft(lfh,current_id, $format(" MMIO ", fshow(req)));
                    mmio = True;
                end else begin 
                    labelKonataLeft(lfh,current_id, $format(" MEM ", fshow(req)));
                    toDmem.enq(req);
                end
            end
            else if (isControlInst(dInst)) begin
                    labelKonataLeft(lfh,current_id, $format(" Ctrl instr "));
                    data = pc1 + 4;
            end else begin 
                labelKonataLeft(lfh,current_id, $format(" Standard instr "));
            end
            let controlResult = execControl32(dInst.inst, rv1, rv2, imm, pc1);
            let nextPc = controlResult.nextPC;
            if (nextPc != from_decode.ppc) begin
                epoch[0] <= epoch[0] + 1;
                pc[0] <= nextPc;
                labelKonataLeft(lfh,current_id, $format("new pc %x ", nextPc));
            end

            labelKonataLeft(lfh,current_id, $format("ALU output: %x " , data));

            let mem_business = MemBusiness { isUnsigned : unpack(isUnsigned), size : size, offset : offset, mmio: mmio};
            e2wQueues[e2w_enq].enq(E2W { 
                mem_business: mem_business,
                data: data,
                dinst: dInst,
                k_id: from_decode.k_id,
                valid: True
            });
            e2w_enq <= e2w_enq + 1;

        end else begin
            e2wQueues[e2w_enq].enq(E2W { 
                dinst: dInst,
                k_id: from_decode.k_id,
                valid: False,
                data: ?,
                mem_business: ?
            });
            e2w_enq <= e2w_enq + 1;
            squashed.enq(current_id);
        end

        // Similarly, to register an execute event for an instruction:
    	//	executeKonata(lfh, k_id);
    	// where k_id is the unique konata identifier that has been passed around that came from the fetch stage


    	// Execute is also the place where we advise you to kill mispredicted instructions
    	// (instead of Decode + Execute like in the class)
    	// When you kill (or squash) an instruction, you should register an event for Konata:
    	
        // squashed.enq(current_inst.k_id);

        // This will allow Konata to display those instructions in grey
    endrule

    rule writeback if (!starting);
        // TODO
        let from_execute = e2wQueues[e2w_deq].first();
        e2wQueues[e2w_deq].deq();
        e2w_deq <= e2w_deq + 1;

        let current_id = from_execute.k_id;
   	    writebackKonata(lfh, current_id);
        labelKonataLeft(lfh,current_id, $format("writeback "));

        let dInst = from_execute.dinst;
        let data = from_execute.data;
        let fields = getInstFields(dInst.inst);

        if (from_execute.valid == True) begin
            retired.enq(current_id);
            if (isMemoryInst(dInst)) begin // (* // write_val *)
                let mem_business = from_execute.mem_business;
                let resp = ?;
                if (mem_business.mmio) begin 
                    resp = fromMMIO.first();
                    fromMMIO.deq();
                end else if (dInst.inst[5] == 0) begin 
                    resp = fromDmem.first();
                    fromDmem.deq();
                end
                let mem_data = resp;
                mem_data = mem_data >> {mem_business.offset ,3'b0};
                case ({pack(mem_business.isUnsigned), mem_business.size}) matches
                3'b000 : data = signExtend(mem_data[7:0]);
                3'b001 : data = signExtend(mem_data[15:0]);
                3'b100 : data = zeroExtend(mem_data[7:0]);
                3'b101 : data = zeroExtend(mem_data[15:0]);
                3'b010 : data = mem_data;
                endcase
            end
            if(debug) $display("[Writeback]", fshow(dInst));
            if (!dInst.legal) begin
                if (debug) $display("[Writeback] Illegal Inst, Drop and fault: ", fshow(dInst));
                // pc <= 0;	// Fault
            end
        end

		if (dInst.valid_rd) begin
            let rd_idx = fields.rd;
            if (rd_idx != 0) begin 
                if (from_execute.valid == True) rf[rd_idx] <= data;
                scoreboard[rd_idx][1] <= scoreboard[rd_idx][1] - 1;
                if(debug) $display("Unstalled %x", rd_idx);
            end
		end

        // Similarly, to register an execute event for an instruction:
	   	//	writebackKonata(lfh,k_id);


	   	// In writeback is also the moment where an instruction retires (there are no more stages)
	   	// Konata requires us to register the event as well using the following: 
		// retired.enq(k_id);
	endrule
		

	// ADMINISTRATION:

    rule administrative_konata_commit;
		    retired.deq();
		    let f = retired.first();
		    commitKonata(lfh, f, commit_id);
	endrule
		
	rule administrative_konata_flush;
		    squashed.deq();
		    let f = squashed.first();
		    squashKonata(lfh, f);
	endrule
		
    method ActionValue#(CacheReq) getIReq();
		toImem.deq();
		return toImem.first();
    endmethod
    method Action getIResp(ICacheResp a);
    	fromImem.enq(a);
    endmethod
    method ActionValue#(CacheReq) getDReq();
		toDmem.deq();
		return toDmem.first();
    endmethod
    method Action getDResp(Word a);
		fromDmem.enq(a);
    endmethod
    method ActionValue#(CacheReq) getMMIOReq();
		toMMIO.deq();
		return toMMIO.first();
    endmethod
    method Action getMMIOResp(Word a);
		fromMMIO.enq(a);
    endmethod
endmodule