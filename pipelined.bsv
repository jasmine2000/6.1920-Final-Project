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
    SupFifo#(Word) fromImem <- mkBypassSupFifo;
    FIFO#(CacheReq) toDmem <- mkBypassFIFO;
    FIFO#(Word) fromDmem <- mkBypassFIFO;
    FIFO#(CacheReq) toMMIO <- mkBypassFIFO;
    FIFO#(Word) fromMMIO <- mkBypassFIFO;

    Ehr#(2, Bit#(32)) pc <- mkEhr(0);
    Vector#(32, Reg#(Bit#(32))) rf <- replicateM(mkReg(0));

    SupFifo#(F2D) f2dQueue <- mkSupFifo;
    SupFifo#(D2E) d2eQueue <- mkSupFifo;
    SupFifo#(E2W) e2wQueue <- mkSupFifo;

    Ehr#(2, Bit#(1)) epoch <- mkEhr(1'b0);
    Vector#(32, Ehr#(2, Bit#(2))) scoreboard <- replicateM(mkEhr(0));

    Bool debug = False;

	// Code to support Konata visualization
    String dumpFile = "output.log" ;
    let lfh <- mkReg(InvalidFile);
	Reg#(KonataId) fresh_id <- mkReg(0);
	Reg#(KonataId) commit_id <- mkReg(0);

	FIFO#(KonataId) retired <- mkFIFO;
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
        let from_fetch1 = f2dQueue.first1();
        let instr1 = fromImem.first1();
        
        let decodedInst1 = decodeInst(instr1);

        decodeKonata(lfh, from_fetch1.k_id);
        labelKonataLeft(lfh,from_fetch1.k_id, $format("decoded %x ", instr1));
        

        if (debug) $display("[Decode] ", fshow(decodedInst1));

        let fields1 = getInstFields(instr1);
        let rs1_idx1 = fields1.rs1;
        let rs2_idx1 = fields1.rs2;
        let rd_idx1 = fields1.rd;

        if (scoreboard[rs1_idx1][0] == 0 && 
            scoreboard[rs2_idx1][0] == 0) begin // no data hazard
            
            f2dQueue.deq1();
            fromImem.deq1();

            let rs1_1 = (rs1_idx1 ==0 ? 0 : rf[rs1_idx1]);
            let rs2_1 = (rs2_idx1 == 0 ? 0 : rf[rs2_idx1]);

            d2eQueue.enq1(D2E {
                dinst: decodedInst1,
                pc: from_fetch1.pc,
                ppc: from_fetch1.ppc,
                epoch: from_fetch1.epoch,
                rv1: rs1_1,
                rv2: rs2_1,
                k_id: from_fetch1.k_id
            });

            if (decodedInst1.valid_rd) begin
                if (rd_idx1 != 0) begin 
                    scoreboard[rd_idx1][0] <= scoreboard[rd_idx1][0] + 1;
                    if(debug) $display("Stalling %x", rd_idx1);
                end
            end

            // let from_fetch2 = f2dQueue.first2();
            // let instr2 = fromImem.first2();
            // let decodedInst2 = decodeInst(instr2);

            // decodeKonata(lfh, from_fetch2.k_id);
            // labelKonataLeft(lfh,from_fetch2.k_id, $format("decoded %x ", instr2));

            // if (debug) $display("[Decode] ", fshow(decodedInst2));

            // let fields2 = getInstFields(instr2);
            // let rs1_idx2 = fields2.rs1;
            // let rs2_idx2 = fields2.rs2;
            // let rd_idx2 = fields2.rd;

            // if (rs1_idx2 != rd_idx1 && // RAW HAZARD
            //     rs2_idx2 != rd_idx1 && // RAW HAZARD
            //     rd_idx2 != rd_idx1 && // WAW HAZARD
            //     scoreboard[rs1_idx2][0] == 0 && 
            //     scoreboard[rs2_idx2][0] == 0) begin // no data hazard
                
            //     f2dQueue.deq2();
            //     fromImem.deq2();

            //     let rs1_2 = (rs1_idx2 ==0 ? 0 : rf[rs1_idx2]);
            //     let rs2_2 = (rs2_idx2 == 0 ? 0 : rf[rs2_idx2]);

            //     d2eQueue.enq2(D2E {
            //         dinst: decodedInst2,
            //         pc: from_fetch2.pc,
            //         ppc: from_fetch2.ppc,
            //         epoch: from_fetch2.epoch,
            //         rv1: rs1_2,
            //         rv2: rs2_2,
            //         k_id: from_fetch2.k_id
            //     });

            //     if (decodedInst2.valid_rd) begin
            //         if (rd_idx2 != 0) begin 
            //             scoreboard[rd_idx2][0] <= scoreboard[rd_idx2][0] + 1;
            //             if(debug) $display("Stalling %x", rd_idx2);
            //         end
            //     end
            // end
        end
    endrule

    rule execute if (!starting);
        let from_decode = d2eQueue.first1();
        let current_id = from_decode.k_id;

        d2eQueue.deq1();

        let dInst = from_decode.dinst;
        let fields = getInstFields(dInst.inst);

        let temp_epoch = epoch[0];

        executeKonata(lfh, current_id);
        labelKonataLeft(lfh,current_id, $format("executing "));
        if (debug) $display("[Execute] ", fshow(dInst));


        // let from_decode2 = d2eQueue.first2();
        // let current_id2 = from_decode2.k_id;
        // let dInst2 = from_decode.dinst;

        // executeKonata(lfh, current_id2);
        // labelKonataLeft(lfh,current_id2, $format("executing "));
        // if (debug) $display("[Execute] ", fshow(dInst2));

        if (from_decode.epoch == temp_epoch) begin
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
                temp_epoch = temp_epoch + 1;
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

            // // try execute second instruction if epoch hasn't changed
            // if (epoch[0] == temp_epoch) begin 
            //     if (!isMemoryInst(dInst2) && !isControlInst(dInst2)) begin
            //         d2eQueue.deq2();

            //         let fields2 = getInstFields(dInst2.inst);

            //         let rv1_2 = from_decode2.rv1;
            //         let rv2_2 = from_decode2.rv2;
            //         let pc1_2 = from_decode2.pc;

            //         let imm2 = getImmediate(dInst2);
            //         Bool mmio2 = False;
            //         let data2 = execALU32(dInst2.inst, rv1_2, rv2_2, imm2, pc1_2);
            //         let isUnsigned2 = 0;
            //         let funct32 = fields.funct3;
            //         let size2 = funct32[1:0];
            //         let addr2 = rv1_2 + imm2;
            //         Bit#(2) offset2 = addr2[1:0];

            //         labelKonataLeft(lfh,current_id2, $format(" Standard instr "));
            //         let controlResult2 = execControl32(dInst2.inst, rv1_2, rv2_2, imm2, pc1_2);
            //         let nextPc2 = controlResult2.nextPC;
            //         if (nextPc2 != from_decode2.ppc) begin
            //             temp_epoch = temp_epoch + 1;
            //             pc[0] <= nextPc;
            //             labelKonataLeft(lfh,current_id2, $format("new pc %x ", nextPc2));
            //         end

            //         labelKonataLeft(lfh,current_id2, $format("ALU output: %x " , data2));

            //         let mem_business2 = MemBusiness { isUnsigned : unpack(isUnsigned2), size : size2, offset : offset2, mmio: mmio2};
            //         e2wQueue.enq2(E2W { 
            //             mem_business: mem_business2,
            //             data: data2,
            //             dinst: dInst2,
            //             k_id: from_decode2.k_id,
            //             valid: True
            //         });
            //     end
            // end else begin
            //     e2wQueue.enq2(E2W { 
            //         dinst: dInst2,
            //         k_id: from_decode2.k_id,
            //         valid: False,
            //         data: ?,
            //         mem_business: ?
            //     });
            //     squashed.enq1(current_id2);
            // end

            epoch[0] <= temp_epoch;

        end else begin
            e2wQueue.enq1(E2W { 
                dinst: dInst,
                k_id: from_decode.k_id,
                valid: False,
                data: ?,
                mem_business: ?
            });
            squashed.enq1(current_id);

            // if (from_decode2.epoch != temp_epoch) begin
            //     e2wQueue.enq2(E2W { 
            //         dinst: dInst2,
            //         k_id: from_decode2.k_id,
            //         valid: False,
            //         data: ?,
            //         mem_business: ?
            //     });
            //     squashed.enq2(current_id2);
            // end
        end
    endrule

    rule writeback if (!starting);
        // TODO
        let from_execute = e2wQueue.first1();
        e2wQueue.deq1();

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

        // let from_execute2 = e2wQueue.first2();

        // let current_id2 = from_execute2.k_id;
   	    // writebackKonata(lfh, current_id2);
        // labelKonataLeft(lfh,current_id2, $format("writeback "));

        // let dInst2 = from_execute2.dinst;
        // let data2 = from_execute2.data;
        // let fields2 = getInstFields(dInst2.inst);
        // let mem_business2 = from_execute2.mem_business;

        // if (!isMemoryInst(dInst1) || 
        //     !isMemoryInst(dInst2) || 
        //     mem_business2.mmio != mem_business2.mmio ||
        //     dInst2.inst[5] != dInst2.inst[5])
        // begin
        //     queue_incr = queue_incr + 1;
        //     e2wQueue.deq2();

        //     if (from_execute2.valid == True) begin
        //         retired.enq(current_id2);
        //         if (isMemoryInst(dInst2)) begin // (* // write_val *)
        //             let resp = ?;
        //             if (mem_business2.mmio) begin 
        //                 resp = fromMMIO.first();
        //                 fromMMIO.deq();
        //             end else if (dInst2.inst[5] == 0) begin 
        //                 resp = fromDmem.first();
        //                 fromDmem.deq();
        //             end
        //             let mem_data = resp;
        //             mem_data = mem_data >> {mem_business2.offset ,3'b0};
        //             case ({pack(mem_business2.isUnsigned), mem_business2.size}) matches
        //             3'b000 : data2 = signExtend(mem_data[7:0]);
        //             3'b001 : data2 = signExtend(mem_data[15:0]);
        //             3'b100 : data2 = zeroExtend(mem_data[7:0]);
        //             3'b101 : data2 = zeroExtend(mem_data[15:0]);
        //             3'b010 : data2 = mem_data;
        //             endcase
        //         end
        //         if(debug) $display("[Writeback]", fshow(dInst2));
        //         if (!dInst2.legal) begin
        //             if (debug) $display("[Writeback] Illegal Inst, Drop and fault: ", fshow(dInst2));
        //             // pc <= 0;	// Fault
        //         end
        //     end

        //     if (dInst2.valid_rd) begin
        //         let rd_idx2 = fields2.rd;
        //         if (rd_idx2 != 0) begin 
        //             if (from_execute2.valid == True) rf[rd_idx2][1] <= data2;
        //             scoreboard[rd_idx2][1] <= scoreboard[rd_idx2][1] - 1;
        //             if(debug) $display("Unstalled %x", rd_idx2);
        //         end
        //     end
        // end
	endrule
		

	// ADMINISTRATION:

    rule administrative_konata_commit;
		    retired.deq();
		    let f = retired.first();
		    commitKonata(lfh, f, commit_id);
	endrule
		
	rule administrative_konata_flush;
		    squashed.deq1();
		    let f = squashed.first1();
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