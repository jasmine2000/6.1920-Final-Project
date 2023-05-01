import FIFO::*;
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
    FIFO#(CacheReq) toImem <- mkBypassFIFO;
    FIFO#(ICacheResp) fromImem <- mkBypassFIFO;
    FIFO#(CacheReq) toDmem <- mkBypassFIFO;
    FIFO#(Word) fromDmem <- mkBypassFIFO;
    FIFO#(CacheReq) toMMIO <- mkBypassFIFO;
    FIFO#(Word) fromMMIO <- mkBypassFIFO;

    Ehr#(2, Bit#(32)) pc <- mkEhr(0);
    Vector#(32, Reg#(Bit#(32))) rf <- replicateM(mkReg(0));


    SupFifo#(F2D) f2dQueue <- mkSupFifo;
    Reg#(Maybe#(Word)) next_ins <- mkReg(Invalid);

    //Vector#(2, FIFO#(F2D)) f2dQueues <- replicateM(mkFIFO);
    
    //Reg#(Bit#(1)) f2d_enq <- mkReg(0);
    //Reg#(Bit#(1)) f2d_deq <- mkReg(0);

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
        
        if(debug) $display("Fetch %x", pc_fetched);
        // You should put the pc that you fetch in pc_fetched
        // Below is the code to support Konata's visualization
		

        // TODO implement fetch
        
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
                epoch: epoch[1],
                k_id: iid2
            });
            pc[1] <= next_pc_predicted + 4;
        end 
        else 
        begin 
            iid <- fetch1Konata(lfh, fresh_id, 0);
            labelKonataLeft(lfh, iid, $format("PC %x ",pc_fetched));

            pc[1] <= next_pc_predicted;
        end

        f2dQueue.enq1(F2D { 
            pc: pc_fetched,
            ppc: next_pc_predicted,
            epoch: epoch[1],
            k_id: iid
        });

    endrule


    rule decode if (!starting);
        let resp = fromImem.first();
        Bool double_decode = isValid(resp.i2);
        let from_fetch1 = f2dQueue.first1();
        //let from_fetch2 = f2dQueue.first2();

        Word instr1 = ?;
        if (isValid(next_ins)) begin
            instr1 = fromMaybe(?, next_ins);
        end else begin
            instr1 = resp.i1;
        end
      

        //let instr1 = resp.i1;
        //let instr2 = fromMaybe(?, resp.i2);
        
        let decodedInst1 = decodeInst(instr1);
        //let decodedInst2 = decodeInst(instr2);

        decodeKonata(lfh, from_fetch1.k_id);
        labelKonataLeft(lfh,from_fetch1.k_id, $format("decoded %x ", instr1));
        

        if (debug) $display("[Decode] ", fshow(decodedInst1));

        let fields1 = getInstFields(instr1);
        let rs1_idx1 = fields1.rs1;
        let rs2_idx1 = fields1.rs2;
        let rd_idx1 = fields1.rd;

        // let fields2 = getInstFields(instr2);
        // let rs1_idx2 = fields2.rs1;
        // let rs2_idx2 = fields2.rs2;
        // let rd_idx2 = fields2.rd;

        if (scoreboard[rs1_idx1][0] == 0 && 
            scoreboard[rs2_idx1][0] == 0) begin // no data hazard
            
            f2dQueue.deq1();
            
            if (isValid(next_ins)) begin
                next_ins <= tagged Invalid;
            end else begin
                fromImem.deq();
                next_ins <= resp.i2;
            end

            

            let rs1_1 = (rs1_idx1 ==0 ? 0 : rf[rs1_idx1]);
            let rs2_1 = (rs2_idx1 == 0 ? 0 : rf[rs2_idx1]);

            d2eQueues[d2e_enq].enq(D2E {
                dinst: decodedInst1,
                pc: from_fetch1.pc,
                ppc: from_fetch1.ppc,
                epoch: from_fetch1.epoch,
                rv1: rs1_1,
                rv2: rs2_1,
                k_id: from_fetch1.k_id
            });
            d2e_enq <= d2e_enq + 1;

            if (decodedInst1.valid_rd) begin
                if (rd_idx1 != 0) begin 
                    scoreboard[rd_idx1][0] <= scoreboard[rd_idx1][0] + 1;
                    if(debug) $display("Stalling %x", rd_idx1);
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