import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import RegFile::*;
import RVUtil::*;
import Vector::*;
import KonataHelper::*;
import Printf::*;
import Ehr::*;
import Supfifo::*;
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
    FIFOF#(CacheReq) toImem <- mkSizedBypassFIFOF(3);
    SupFifo#(Word) fromImem <- mkBypassSupFifo;
    SupFifo#(CacheReq) toDmem <- mkBypassSupFifo;
    SupFifo#(Word) fromDmem <- mkBypassSupFifo;
    SupFifo#(CacheReq) toMMIO <- mkBypassSupFifo;
    SupFifo#(Word) fromMMIO <- mkBypassSupFifo;

    Ehr#(3, Bit#(32)) pc <- mkEhr(0);
    Vector#(32, Ehr#(3, Bit#(32))) rf <- replicateM(mkEhr(0));

    SupFifo#(F2D) f2dQueue <- mkSupFifo;
    SupFifo#(D2E) d2eQueue <- mkSupFifo;
    SupFifo#(E2W) e2wQueue <- mkSupFifo;

    Ehr#(3, Bool) allowDecode2 <- mkEhr(False);
    Ehr#(3, Bool) allowExecute2 <- mkEhr(False);
    Ehr#(3, Bool) allowWriteback2 <- mkEhr(False);

    Ehr#(3, Bit#(1)) epoch <- mkEhr(1'b0);
    Vector#(32, Ehr#(4, Bit#(5))) scoreboard <- replicateM(mkEhr(0));

    Bool debug = False;
    
	// Code to support Konata visualization
    String dumpFile = "output.log" ;
    let lfh <- mkReg(InvalidFile);
	Reg#(KonataId) fresh_id <- mkReg(0);
	Ehr#(2, KonataId) commit_id <- mkEhr(0);

	SupFifo#(KonataId) retired <- mkSupFifo;
	SupFifo#(KonataId) squashed <- mkSupFifo;
    
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

    rule resetAllow if (!starting);
        allowDecode2[0] <= False;
        allowExecute2[0] <= False;
        allowWriteback2[0] <= False;
    endrule
		
    rule fetch if (!starting);
        Bit#(32) pc_fetched = pc[2];
        Bit#(32) next_pc_predicted = pc_fetched + 4;
        
        if(debug) $display("Fetch %x", pc_fetched);
        
        let req = CacheReq {
            byte_en : 0,
            addr : pc_fetched,
            data : 0
        };
        toImem.enq(req);

        KonataId iid = ?;
        if (pc_fetched[5:2] < 15) // Not end of line
        begin
            iid <- nfetchKonata(lfh, fresh_id, 0,2);
            let iid2 = iid + 1;
            labelKonataLeft(lfh, iid, $format("PC %x ",pc_fetched));
            labelKonataLeft(lfh, iid2, $format("PC %x ",next_pc_predicted));

            f2dQueue.enq2(F2D { 
                pc: next_pc_predicted,
                ppc: next_pc_predicted + 4,
                epoch: epoch[2],
                k_id: iid2
            });
            pc[2] <= next_pc_predicted + 4;
        end 
        else 
        begin 
            iid <- fetch1Konata(lfh, fresh_id, 0);
            labelKonataLeft(lfh, iid, $format("PC %x ",pc_fetched));

            pc[2] <= next_pc_predicted;
        end

        f2dQueue.enq1(F2D { 
            pc: pc_fetched,
            ppc: next_pc_predicted,
            epoch: epoch[2],
            k_id: iid
        });

    endrule


    rule decode1 if (!starting);
        let from_fetch = f2dQueue.first1();
        let instr = fromImem.first1();
        
        let decodedInst = decodeInst(instr);

        if (debug) $display("[Decode] ", fshow(decodedInst));

        let fields = getInstFields(instr);
        let rs1_idx = fields.rs1;
        let rs2_idx = fields.rs2;
        let rd_idx = fields.rd;

        if (scoreboard[rs1_idx][2] == 0 && 
            scoreboard[rs2_idx][2] == 0
            ) begin // no data hazard

            decodeKonata(lfh, from_fetch.k_id);
            labelKonataLeft(lfh,from_fetch.k_id, $format("decoded %x ", instr));

            f2dQueue.deq1();
            fromImem.deq1();

            let rs1 = (rs1_idx == 0 ? 0 : rf[rs1_idx][2]);
            let rs2 = (rs2_idx == 0 ? 0 : rf[rs2_idx][2]);

            d2eQueue.enq1(D2E {
                dinst: decodedInst,
                pc: from_fetch.pc,
                ppc: from_fetch.ppc,
                epoch: from_fetch.epoch,
                rv1: rs1,
                rv2: rs2,
                k_id: from_fetch.k_id
            });

            if (decodedInst.valid_rd) begin
                if (rd_idx != 0) begin 
                    scoreboard[rd_idx][2] <= scoreboard[rd_idx][2] + 1;
                    if(debug) $display("Stalling %x", rd_idx);
                end
            end

            allowDecode2[1] <= True;

        end else allowDecode2[1] <= False;
    endrule

    rule decode2 if (!starting && allowDecode2[2] == True);
        let from_fetch = f2dQueue.first2();
        let instr = fromImem.first2();
        
        let decodedInst = decodeInst(instr);

        if (debug) $display("[Decode] ", fshow(decodedInst));

        let fields = getInstFields(instr);
        let rs1_idx = fields.rs1;
        let rs2_idx = fields.rs2;
        let rd_idx = fields.rd;

        if (scoreboard[rs1_idx][3] == 0 && 
            scoreboard[rs2_idx][3] == 0
            ) begin // no data hazard

            decodeKonata(lfh, from_fetch.k_id);
            labelKonataLeft(lfh,from_fetch.k_id, $format("decoded %x ", instr));
            
            f2dQueue.deq2();
            fromImem.deq2();

            let rs1 = (rs1_idx == 0 ? 0 : rf[rs1_idx][2]);
            let rs2 = (rs2_idx == 0 ? 0 : rf[rs2_idx][2]);

            d2eQueue.enq2(D2E {
                dinst: decodedInst,
                pc: from_fetch.pc,
                ppc: from_fetch.ppc,
                epoch: from_fetch.epoch,
                rv1: rs1,
                rv2: rs2,
                k_id: from_fetch.k_id
            });

            if (decodedInst.valid_rd) begin
                if (rd_idx != 0) begin 
                    scoreboard[rd_idx][3] <= scoreboard[rd_idx][3] + 1;
                    if(debug) $display("Stalling %x", rd_idx);
                end
            end
        end
    endrule

    rule execute1 if (!starting);
        let from_decode = d2eQueue.first1();
        let current_id = from_decode.k_id;

        d2eQueue.deq1();

        let dInst = from_decode.dinst;
        let fields = getInstFields(dInst.inst);

        executeKonata(lfh, current_id);
        labelKonataLeft(lfh,current_id, $format("executing "));
        if (debug) $display("[Execute] ", fshow(dInst));

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
                allowExecute2[1] <= False;
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
                let type_mem1 = (dInst.inst[5] == 1) ? byte_en : 0;
                let req = CacheReq {byte_en : type_mem1,
                        addr : addr,
                        data : data};
                if (isMMIO(addr)) begin 
                    if (debug) $display("[Execute] MMIO", fshow(req));
                    toMMIO.enq1(req);
                    labelKonataLeft(lfh,current_id, $format(" MMIO ", fshow(req)));
                    mmio = True;
                end else begin 
                    labelKonataLeft(lfh,current_id, $format(" MEM ", fshow(req)));
                    toDmem.enq1(req);
                end
            end
            else if (isControlInst(dInst)) begin
                labelKonataLeft(lfh,current_id, $format(" Ctrl instr "));
                data = pc1 + 4;
                allowExecute2[1] <= True;
            end else begin 
                labelKonataLeft(lfh,current_id, $format(" Standard instr "));
                allowExecute2[1] <= True;
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
            
            e2wQueue.enq1(E2W { 
                mem_business: mem_business,
                data: data,
                dinst: dInst,
                k_id: from_decode.k_id,
                valid: True
            });

        end else begin
            allowExecute2[1] <= True;
            e2wQueue.enq1(E2W { 
                dinst: dInst,
                k_id: from_decode.k_id,
                valid: False,
                data: ?,
                mem_business: ?
            });
            squashed.enq1(current_id);
        end
    endrule

    rule execute2 if (!starting && allowExecute2[2] == True);
        let from_decode = d2eQueue.first2();
        let current_id = from_decode.k_id;

        let dInst = from_decode.dinst;
        let fields = getInstFields(dInst.inst);

        executeKonata(lfh, current_id);
        labelKonataLeft(lfh,current_id, $format("executing "));
        if (debug) $display("[Execute] ", fshow(dInst));

        if (from_decode.epoch != epoch[1]) begin
            d2eQueue.deq2();
            e2wQueue.enq2(E2W { 
                dinst: dInst,
                k_id: from_decode.k_id,
                valid: False,
                data: ?,
                mem_business: ?
            });
            squashed.enq2(current_id);

        end else if (from_decode.epoch == epoch[1]
             && !isMemoryInst(dInst)
             ) begin
            d2eQueue.deq2();

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

            if (isControlInst(dInst)) begin
                labelKonataLeft(lfh,current_id, $format(" Ctrl instr "));
                data = pc1 + 4;
            end else begin 
                labelKonataLeft(lfh,current_id, $format(" Standard instr "));
            end

            let controlResult = execControl32(dInst.inst, rv1, rv2, imm, pc1);
            let nextPc = controlResult.nextPC;
            if (nextPc != from_decode.ppc) begin
                epoch[1] <= epoch[1] + 1;
                pc[1] <= nextPc;
                labelKonataLeft(lfh,current_id, $format("new pc %x ", nextPc));
            end

            labelKonataLeft(lfh,current_id, $format("ALU output: %x " , data));

            let mem_business = MemBusiness { isUnsigned : unpack(isUnsigned), size : size, offset : offset, mmio: mmio};
            
            e2wQueue.enq2(E2W { 
                mem_business: mem_business,
                data: data,
                dinst: dInst,
                k_id: from_decode.k_id,
                valid: True
            });
        end
    endrule

    rule writeback1 if (!starting);
        let from_execute = e2wQueue.first1();
        e2wQueue.deq1();

        let current_id = from_execute.k_id;
   	    writebackKonata(lfh, current_id);
        labelKonataLeft(lfh,current_id, $format("writeback "));

        let dInst = from_execute.dinst;
        let data = from_execute.data;
        let fields = getInstFields(dInst.inst);

        if (from_execute.valid == True) begin
            retired.enq1(current_id);
            if (isMemoryInst(dInst)) begin // (* // write_val *)
                allowWriteback2[1] <= False;
                let mem_business = from_execute.mem_business;
                let resp = ?;
                if (mem_business.mmio) begin 
                    resp = fromMMIO.first1();
                    fromMMIO.deq1();
                end else if (dInst.inst[5] == 0) begin 
                    resp = fromDmem.first1();
                    fromDmem.deq1();
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
            end else allowWriteback2[1] <= True;
            if(debug) $display("[Writeback]", fshow(dInst));
            if (!dInst.legal) begin
                if (debug) $display("[Writeback] Illegal Inst, Drop and fault: ", fshow(dInst));
                // pc <= 0;	// Fault
            end
        end else allowWriteback2[1] <= True;

		if (dInst.valid_rd) begin
            let rd_idx = fields.rd;
            if (rd_idx != 0) begin 
                if (from_execute.valid == True) rf[rd_idx][0] <= data;
                scoreboard[rd_idx][0] <= scoreboard[rd_idx][0] - 1;
                if(debug) $display("Unstalled %x", rd_idx);
            end
		end
	endrule

    rule writeback2 if (!starting && allowWriteback2[2] == True);
        let from_execute = e2wQueue.first2();
        let dInst = from_execute.dinst;

        if (!isMemoryInst(dInst) || from_execute.valid == False) begin

            e2wQueue.deq2();

            let current_id = from_execute.k_id;
            writebackKonata(lfh, current_id);
            labelKonataLeft(lfh,current_id, $format("writeback "));
            
            let data = from_execute.data;
            let fields = getInstFields(dInst.inst);

            if (from_execute.valid == True) begin
                retired.enq2(current_id);

                if(debug) $display("[Writeback]", fshow(dInst));
                if (!dInst.legal) begin
                    if (debug) $display("[Writeback] Illegal Inst, Drop and fault: ", fshow(dInst));
                    // pc <= 0;	// Fault
                end

                
            end
            if (dInst.valid_rd) begin
                let rd_idx = fields.rd;
                if (rd_idx != 0) begin 
                    if (from_execute.valid == True) rf[rd_idx][1] <= data;
                    scoreboard[rd_idx][1] <= scoreboard[rd_idx][1] - 1;
                    if(debug) $display("Unstalled %x", rd_idx);
                end
            end
        end
	endrule
		

	// ADMINISTRATION:

    rule administrative_konata_commit;
		    retired.deq1();
		    let f = retired.first1();
            $fdisplay(lfh,"R\t%d\t%d\t%d", f, commit_id[0],0);
            commit_id[0] <= commit_id[0] + 1;
            // $display(commit_id[0]);
	endrule
		
	rule administrative_konata_flush;
		    squashed.deq1();
		    let f = squashed.first1();
		    squashKonata(lfh, f);
	endrule

    rule administrative_konata_commit2;
		    retired.deq2();
		    let f = retired.first2();
            $fdisplay(lfh,"R\t%d\t%d\t%d", f, commit_id[1],0);
            commit_id[1] <= commit_id[1] + 1;
            // $display(commit_id[1]);
	endrule
		
	rule administrative_konata_flush2;
		    squashed.deq2();
		    let f = squashed.first2();
		    squashKonata(lfh, f);
	endrule
		
    method ActionValue#(CacheReq) getIReq();
		toImem.deq();
		return toImem.first();
    endmethod
    method Action getIResp(ICacheResp a);
    	fromImem.enq1(a.i1);
        if (isValid(a.i2)) fromImem.enq2(fromMaybe(?, a.i2));
    endmethod
    method ActionValue#(CacheReq) getDReq();
		toDmem.deq1();
		return toDmem.first1();
    endmethod
    method Action getDResp(Word a);
		fromDmem.enq1(a);
    endmethod
    method ActionValue#(CacheReq) getMMIOReq();
		toMMIO.deq1();
		return toMMIO.first1();
    endmethod
    method Action getMMIOResp(Word a);
		fromMMIO.enq1(a);
    endmethod
endmodule