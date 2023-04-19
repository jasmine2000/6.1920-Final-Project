import FIFO::*;
import SpecialFIFOs::*;
import RegFile::*;
import RVUtil::*;
import Vector::*;
import KonataHelper::*;
import Printf::*;
import Ehr::*;

typedef struct { Bit#(4) byte_en; Bit#(32) addr; Bit#(32) data; } Mem deriving (Eq, FShow, Bits);

interface RVIfc;
    method ActionValue#(Mem) getIReq();
    method Action getIResp(Mem a);
    method ActionValue#(Mem) getDReq();
    method Action getDResp(Mem a);
    method ActionValue#(Mem) getMMIOReq();
    method Action getMMIOResp(Mem a);
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
} E2W deriving (Eq, FShow, Bits);

(* synthesize *)
module mkpipelined(RVIfc);
    // Interface with memory and devices
    FIFO#(Mem) toImem <- mkBypassFIFO;
    FIFO#(Mem) fromImem <- mkBypassFIFO;
    FIFO#(Mem) toDmem <- mkBypassFIFO;
    FIFO#(Mem) fromDmem <- mkBypassFIFO;
    FIFO#(Mem) toMMIO <- mkBypassFIFO;
    FIFO#(Mem) fromMMIO <- mkBypassFIFO;

    FIFO#(F2D) f2d <- mkFIFO;
    FIFO#(D2E) d2e <- mkFIFO;
    FIFO#(E2W) e2w <- mkFIFO;

    Ehr#(2, Bit#(32)) pc <- mkEhr(32'h00000000);
    Ehr#(2, Bit#(1)) epoch <- mkEhr(1'b0);

    // Ehr#(2, Bit#(32)) pc <- mkEhr(32'h00000000);
    // Ehr#(2, Bit#(1)) epoch <- mkEhr(1'b0);

    // TODO maybe make an ehr?
    Vector#(32, Reg#(Bit#(32))) rf <- replicateM(mkReg(0));
    Vector#(32, Reg#(Bool)) scoreboard <- replicateM(mkReg(False));
    

	// Code to support Konata visualization
    String dumpFile = "output.log" ;
    let lfh <- mkReg(InvalidFile);
	Reg#(KonataId) fresh_id <- mkReg(0);
	Reg#(KonataId) commit_id <- mkReg(0);

	FIFO#(KonataId) retired <- mkFIFO;
	FIFO#(KonataId) squashed <- mkFIFO;

    
    Reg#(Bool) starting <- mkReg(True);
    Bool debug = False;

	rule do_tic_logging;
        if (starting) begin
            let f <- $fopen(dumpFile, "w") ;
            lfh <= f;
            $fwrite(f, "Kanata\t0004\nC=\t1\n");
            starting <= False;
        end
		konataTic(lfh);
	endrule
		


    // wt pc[0] = jmp_pc
    // rd pc[0] = last_pc
    // rd pc[1] = jmp_pc if jmp else last_pc
    // wt pc[1] = next_pc
    rule fetch if (!starting);
        Bit#(32) pc_fetched = pc[1];
        Bit#(32) next_pc_predicted = pc[1] + 4;
        pc[1] <= next_pc_predicted;
        // You should put the pc that you fetch in pc_fetched
        // Below is the code to support Konata's visualization
		let iid <- fetch1Konata(lfh, fresh_id, 0);
        labelKonataLeft(lfh, iid, $format("PC %x",pc_fetched));
        // TODO implement fetch
        
        let req = Mem {byte_en : 0,
			   addr : pc_fetched,
			   data : 0};
        
        
        // TODO what are the correct ppc and pc?
        if(debug) $display("Fetch %x", pc_fetched);
        f2d.enq(F2D{pc : pc_fetched, ppc : next_pc_predicted, epoch : epoch[1], k_id : iid});
        toImem.enq(req);


    endrule

    rule decode if (!starting);
        // Get pc ppc epoch and id
        let from_fetch = f2d.first();        
        // Get instruction from fifo
        let resp = fromImem.first();
        // Decode instruction
        let instr = resp.data;
        let decodedInst = decodeInst(instr);
		
        // Unpack fields
        let rs1_idx = getInstFields(instr).rs1;
        let rs2_idx = getInstFields(instr).rs2;
        let rd_idx = getInstFields(instr).rd;
		let rs1 = (rs1_idx ==0 ? 0 : rf[rs1_idx]);
		let rs2 = (rs2_idx == 0 ? 0 : rf[rs2_idx]);
        

        if ((decodedInst.valid_rs1 && scoreboard[rs1_idx]) || (decodedInst.valid_rs2 && scoreboard[rs2_idx]) || (decodedInst.valid_rd && scoreboard[rd_idx])) begin // if sources or destinations in scoreboard
        
            // stall, so do nothing?
        end else begin
            
            // TODO these might have to be EHRs
            // scoreboard[rs1_idx] <= decodedInst.valid_rs1;
            // scoreboard[rs2_idx] <= decodedInst.valid_rs2;
            scoreboard[rd_idx] <= decodedInst.valid_rd;

            f2d.deq();
            fromImem.deq();
		    d2e.enq(D2E{dinst : decodedInst,
                        pc    : from_fetch.pc,
                        ppc   : from_fetch.ppc,
                        epoch : from_fetch.epoch,
                        rv1   : rs1,
                        rv2   : rs2,
                        k_id  : from_fetch.k_id});
        end

        // Debug and logging
        if (debug) $display("[Decode] ", fshow(decodedInst));
        decodeKonata(lfh, from_fetch.k_id);
        labelKonataLeft(lfh,from_fetch.k_id, $format("Instr bits: %x",decodedInst.inst));
        labelKonataLeft(lfh,from_fetch.k_id, $format(" Potential r1: %x, Potential r2: %x" , rs1, rs2));
    endrule

    rule execute if (!starting);
        let from_decode = d2e.first();
        d2e.deq();

        let dInst = from_decode.dinst;
        let rv1   = from_decode.rv1;
        let rv2   = from_decode.rv2;
        let inst_pc    = from_decode.pc;
        let current_id = from_decode.k_id;



		if (debug) $display("[Execute] ", fshow(dInst));
		executeKonata(lfh, current_id);

		let imm = getImmediate(dInst);
		let controlResult = execControl32(dInst.inst, rv1, rv2, imm, inst_pc);
		let nextPc = controlResult.nextPC;


		Bool mmio = False;
		let data = execALU32(dInst.inst, rv1, rv2, imm, inst_pc);
		let isUnsigned = 0;
		let funct3 = getInstFields(dInst.inst).funct3;
		let size = funct3[1:0];
		let addr = rv1 + imm;
		Bit#(2) offset = addr[1:0];


                let fields = getInstFields(dInst.inst);
        let rd_idx = fields.rd;


        if (epoch[0] != from_decode.epoch) begin // Wrong epoch, squash
            squashed.enq(current_id);
            
            // Release the scoreboard
            if (dInst.valid_rd) begin
                scoreboard[rd_idx] <= False;
            end
            
        end else begin
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
                let req = Mem {byte_en : type_mem,
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
                    data = inst_pc + 4;
            end else begin 
                labelKonataLeft(lfh,current_id, $format(" Standard instr "));
            end
            labelKonataLeft(lfh,current_id, $format(" ALU output: %x" , data));
            
            e2w.enq(E2W{
                    mem_business : MemBusiness { isUnsigned : unpack(isUnsigned), size : size, offset : offset, mmio: mmio},
                    data : data,
                    dinst : dInst,
                    k_id : current_id
                });
            
            if (nextPc != from_decode.ppc) begin // Mispredicted branch, update pc 
                epoch[0] <= epoch[0]+1;
                pc[0] <= nextPc;
            end
        end

		
    endrule

    rule writeback if (!starting);
        let from_execute = e2w.first();
        e2w.deq();

        let mem_business = from_execute.mem_business;
        let data         = from_execute.data;
        let dInst        = from_execute.dinst;
        let current_id   = from_execute.k_id;

		writebackKonata(lfh, current_id);
        retired.enq(current_id);
        let fields = getInstFields(dInst.inst);
        if (isMemoryInst(dInst)) begin // (* // write_val *)
            let resp = ?;
		    if (mem_business.mmio) begin 
                resp = fromMMIO.first();
		        fromMMIO.deq();
		    end else begin 
                resp = fromDmem.first();
		        fromDmem.deq();
		    end
            let mem_data = resp.data;
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
            $finish(1);
	    end
		if (dInst.valid_rd) begin
            // Release the scoreboard
            let rd_idx = fields.rd;
            scoreboard[rd_idx] <= False;
            if (rd_idx != 0) begin rf[rd_idx] <= data; end
		end

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
		
    method ActionValue#(Mem) getIReq();
		toImem.deq();
		return toImem.first();
    endmethod
    method Action getIResp(Mem a);
    	fromImem.enq(a);
    endmethod
    method ActionValue#(Mem) getDReq();
		toDmem.deq();
		return toDmem.first();
    endmethod
    method Action getDResp(Mem a);
		fromDmem.enq(a);
    endmethod
    method ActionValue#(Mem) getMMIOReq();
		toMMIO.deq();
		return toMMIO.first();
    endmethod
    method Action getMMIOResp(Mem a);
		fromMMIO.enq(a);
    endmethod
endmodule
