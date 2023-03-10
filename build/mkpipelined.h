/*
 * Generated by Bluespec Compiler, version 2023.01-6-g034050db (build 034050db)
 * 
 * On Fri Mar 10 17:46:40 EST 2023
 * 
 */

/* Generation options: */
#ifndef __mkpipelined_h__
#define __mkpipelined_h__

#include "bluesim_types.h"
#include "bs_module.h"
#include "bluesim_primitives.h"
#include "bs_vcd.h"


/* Class declaration for the mkpipelined module */
class MOD_mkpipelined : public Module {
 
 /* Clock handles */
 private:
  tClock __clk_handle_0;
 
 /* Clock gate handles */
 public:
  tUInt8 *clk_gate[0];
 
 /* Instantiation parameters */
 public:
 
 /* Module state */
 public:
  MOD_Reg<tUInt64> INST_commit_id;
  MOD_Fifo<tUWide> INST_d2eQueue;
  MOD_Fifo<tUWide> INST_e2wQueue;
  MOD_Reg<tUInt8> INST_epoch;
  MOD_Fifo<tUWide> INST_f2dQueue;
  MOD_Reg<tUInt64> INST_fresh_id;
  MOD_CReg<tUWide> INST_fromDmem_rv;
  MOD_CReg<tUWide> INST_fromImem_rv;
  MOD_CReg<tUWide> INST_fromMMIO_rv;
  MOD_Reg<tUInt32> INST_lfh;
  MOD_Wire<tUInt32> INST_pc_port_0;
  MOD_Wire<tUInt32> INST_pc_port_1;
  MOD_Reg<tUInt8> INST_pc_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_pc_readBeforeLaterWrites_1;
  MOD_Reg<tUInt32> INST_pc_register;
  MOD_Fifo<tUInt64> INST_retired;
  MOD_Reg<tUInt32> INST_rf_0;
  MOD_Reg<tUInt32> INST_rf_1;
  MOD_Reg<tUInt32> INST_rf_10;
  MOD_Reg<tUInt32> INST_rf_11;
  MOD_Reg<tUInt32> INST_rf_12;
  MOD_Reg<tUInt32> INST_rf_13;
  MOD_Reg<tUInt32> INST_rf_14;
  MOD_Reg<tUInt32> INST_rf_15;
  MOD_Reg<tUInt32> INST_rf_16;
  MOD_Reg<tUInt32> INST_rf_17;
  MOD_Reg<tUInt32> INST_rf_18;
  MOD_Reg<tUInt32> INST_rf_19;
  MOD_Reg<tUInt32> INST_rf_2;
  MOD_Reg<tUInt32> INST_rf_20;
  MOD_Reg<tUInt32> INST_rf_21;
  MOD_Reg<tUInt32> INST_rf_22;
  MOD_Reg<tUInt32> INST_rf_23;
  MOD_Reg<tUInt32> INST_rf_24;
  MOD_Reg<tUInt32> INST_rf_25;
  MOD_Reg<tUInt32> INST_rf_26;
  MOD_Reg<tUInt32> INST_rf_27;
  MOD_Reg<tUInt32> INST_rf_28;
  MOD_Reg<tUInt32> INST_rf_29;
  MOD_Reg<tUInt32> INST_rf_3;
  MOD_Reg<tUInt32> INST_rf_30;
  MOD_Reg<tUInt32> INST_rf_31;
  MOD_Reg<tUInt32> INST_rf_4;
  MOD_Reg<tUInt32> INST_rf_5;
  MOD_Reg<tUInt32> INST_rf_6;
  MOD_Reg<tUInt32> INST_rf_7;
  MOD_Reg<tUInt32> INST_rf_8;
  MOD_Reg<tUInt32> INST_rf_9;
  MOD_Wire<tUInt8> INST_scoreboard_0_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_0_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_0_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_0_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_0_register;
  MOD_Wire<tUInt8> INST_scoreboard_10_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_10_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_10_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_10_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_10_register;
  MOD_Wire<tUInt8> INST_scoreboard_11_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_11_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_11_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_11_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_11_register;
  MOD_Wire<tUInt8> INST_scoreboard_12_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_12_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_12_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_12_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_12_register;
  MOD_Wire<tUInt8> INST_scoreboard_13_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_13_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_13_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_13_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_13_register;
  MOD_Wire<tUInt8> INST_scoreboard_14_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_14_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_14_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_14_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_14_register;
  MOD_Wire<tUInt8> INST_scoreboard_15_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_15_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_15_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_15_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_15_register;
  MOD_Wire<tUInt8> INST_scoreboard_16_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_16_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_16_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_16_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_16_register;
  MOD_Wire<tUInt8> INST_scoreboard_17_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_17_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_17_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_17_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_17_register;
  MOD_Wire<tUInt8> INST_scoreboard_18_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_18_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_18_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_18_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_18_register;
  MOD_Wire<tUInt8> INST_scoreboard_19_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_19_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_19_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_19_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_19_register;
  MOD_Wire<tUInt8> INST_scoreboard_1_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_1_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_1_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_1_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_1_register;
  MOD_Wire<tUInt8> INST_scoreboard_20_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_20_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_20_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_20_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_20_register;
  MOD_Wire<tUInt8> INST_scoreboard_21_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_21_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_21_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_21_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_21_register;
  MOD_Wire<tUInt8> INST_scoreboard_22_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_22_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_22_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_22_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_22_register;
  MOD_Wire<tUInt8> INST_scoreboard_23_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_23_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_23_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_23_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_23_register;
  MOD_Wire<tUInt8> INST_scoreboard_24_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_24_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_24_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_24_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_24_register;
  MOD_Wire<tUInt8> INST_scoreboard_25_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_25_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_25_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_25_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_25_register;
  MOD_Wire<tUInt8> INST_scoreboard_26_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_26_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_26_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_26_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_26_register;
  MOD_Wire<tUInt8> INST_scoreboard_27_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_27_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_27_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_27_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_27_register;
  MOD_Wire<tUInt8> INST_scoreboard_28_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_28_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_28_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_28_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_28_register;
  MOD_Wire<tUInt8> INST_scoreboard_29_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_29_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_29_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_29_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_29_register;
  MOD_Wire<tUInt8> INST_scoreboard_2_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_2_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_2_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_2_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_2_register;
  MOD_Wire<tUInt8> INST_scoreboard_30_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_30_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_30_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_30_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_30_register;
  MOD_Wire<tUInt8> INST_scoreboard_31_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_31_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_31_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_31_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_31_register;
  MOD_Wire<tUInt8> INST_scoreboard_3_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_3_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_3_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_3_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_3_register;
  MOD_Wire<tUInt8> INST_scoreboard_4_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_4_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_4_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_4_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_4_register;
  MOD_Wire<tUInt8> INST_scoreboard_5_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_5_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_5_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_5_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_5_register;
  MOD_Wire<tUInt8> INST_scoreboard_6_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_6_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_6_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_6_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_6_register;
  MOD_Wire<tUInt8> INST_scoreboard_7_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_7_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_7_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_7_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_7_register;
  MOD_Wire<tUInt8> INST_scoreboard_8_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_8_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_8_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_8_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_8_register;
  MOD_Wire<tUInt8> INST_scoreboard_9_port_0;
  MOD_Wire<tUInt8> INST_scoreboard_9_port_1;
  MOD_Reg<tUInt8> INST_scoreboard_9_readBeforeLaterWrites_0;
  MOD_Reg<tUInt8> INST_scoreboard_9_readBeforeLaterWrites_1;
  MOD_Reg<tUInt8> INST_scoreboard_9_register;
  MOD_Fifo<tUInt64> INST_squashed;
  MOD_Reg<tUInt8> INST_starting;
  MOD_CReg<tUWide> INST_toDmem_rv;
  MOD_CReg<tUWide> INST_toImem_rv;
  MOD_CReg<tUWide> INST_toMMIO_rv;
 
 /* Constructor */
 public:
  MOD_mkpipelined(tSimStateHdl simHdl, char const *name, Module *parent);
 
 /* Symbol init methods */
 private:
  void init_symbols_0();
 
 /* Reset signal definitions */
 private:
  tUInt8 PORT_RST_N;
 
 /* Port definitions */
 public:
  tUWide PORT_getIResp_a;
  tUWide PORT_getDResp_a;
  tUWide PORT_getMMIOResp_a;
  tUWide PORT_getIReq;
  tUWide PORT_getDReq;
  tUWide PORT_getMMIOReq;
 
 /* Publicly accessible definitions */
 public:
  tUWide DEF_toMMIO_rv_port1__read____d1113;
  tUWide DEF_toDmem_rv_port1__read____d1109;
  tUWide DEF_toImem_rv_port1__read____d1105;
  tUInt8 DEF_x__h29545;
  tUInt8 DEF_x__h23011;
  tUInt8 DEF_rs1_idx__h23006;
  tUInt8 DEF_rs2_idx__h23007;
  tUWide DEF_d2eQueue_first____d674;
  tUWide DEF_e2wQueue_first____d861;
  tUWide DEF_fromMMIO_rv_port1__read____d872;
  tUWide DEF_fromMMIO_rv_port0__read____d1115;
  tUWide DEF_toMMIO_rv_port0__read____d729;
  tUWide DEF_fromDmem_rv_port1__read____d874;
  tUWide DEF_fromDmem_rv_port0__read____d1111;
  tUWide DEF_toDmem_rv_port0__read____d732;
  tUWide DEF_fromImem_rv_port1__read____d255;
  tUWide DEF_fromImem_rv_port0__read____d1107;
  tUWide DEF_toImem_rv_port0__read____d235;
  tUInt8 DEF_def__h50017;
  tUInt8 DEF_def__h49895;
  tUInt8 DEF_def__h49773;
  tUInt8 DEF_def__h49651;
  tUInt8 DEF_def__h49529;
  tUInt8 DEF_def__h49407;
  tUInt8 DEF_def__h49285;
  tUInt8 DEF_def__h49163;
  tUInt8 DEF_def__h49041;
  tUInt8 DEF_def__h48919;
  tUInt8 DEF_def__h48797;
  tUInt8 DEF_def__h48675;
  tUInt8 DEF_def__h48553;
  tUInt8 DEF_def__h48431;
  tUInt8 DEF_def__h48309;
  tUInt8 DEF_def__h48187;
  tUInt8 DEF_def__h48065;
  tUInt8 DEF_def__h47943;
  tUInt8 DEF_def__h47821;
  tUInt8 DEF_def__h47699;
  tUInt8 DEF_def__h47577;
  tUInt8 DEF_def__h47455;
  tUInt8 DEF_def__h47333;
  tUInt8 DEF_def__h47211;
  tUInt8 DEF_def__h47089;
  tUInt8 DEF_def__h46967;
  tUInt8 DEF_def__h46845;
  tUInt8 DEF_def__h46723;
  tUInt8 DEF_def__h46601;
  tUInt8 DEF_def__h46479;
  tUInt8 DEF_def__h46357;
  tUInt8 DEF_def__h46235;
  tUInt8 DEF_starting__h21531;
  tUInt8 DEF_x_epoch__h22662;
  tUInt32 DEF_rv1__h37543;
  tUInt32 DEF_d2eQueue_first__74_BITS_111_TO_80_82_PLUS_IF_d_ETC___d722;
  tUInt32 DEF_d2eQueue_first__74_BITS_111_TO_80_82_PLUS_IF_d_ETC___d723;
  tUInt32 DEF_x__h37751;
  tUInt8 DEF_rd_idx__h41281;
  tUInt8 DEF_e2wQueue_first__61_BITS_126_TO_124___d884;
  tUInt8 DEF_d2eQueue_first__74_BIT_212___d683;
  tUInt8 DEF_d2eQueue_first__74_BIT_208___d698;
  tUInt8 DEF_d2eQueue_first__74_BIT_183___d677;
  tUInt8 DEF_e2wQueue_first__61_BIT_121___d870;
  tUInt8 DEF_e2wQueue_first__61_BIT_85___d880;
  tUInt8 DEF_e2wQueue_first__61_BIT_55___d865;
  tUInt8 DEF_e2wQueue_first__61_BIT_0___d862;
  tUInt8 DEF_n__read__h25094;
  tUInt8 DEF_n__read__h25096;
  tUInt8 DEF_n__read__h25098;
  tUInt8 DEF_n__read__h25100;
  tUInt8 DEF_n__read__h25102;
  tUInt8 DEF_n__read__h25104;
  tUInt8 DEF_n__read__h25106;
  tUInt8 DEF_n__read__h25108;
  tUInt8 DEF_n__read__h25110;
  tUInt8 DEF_n__read__h25112;
  tUInt8 DEF_n__read__h25114;
  tUInt8 DEF_n__read__h25116;
  tUInt8 DEF_n__read__h25118;
  tUInt8 DEF_n__read__h25120;
  tUInt8 DEF_n__read__h25122;
  tUInt8 DEF_n__read__h25124;
  tUInt8 DEF_n__read__h25126;
  tUInt8 DEF_n__read__h25128;
  tUInt8 DEF_n__read__h25130;
  tUInt8 DEF_n__read__h25132;
  tUInt8 DEF_n__read__h25134;
  tUInt8 DEF_n__read__h25136;
  tUInt8 DEF_n__read__h25138;
  tUInt8 DEF_n__read__h25140;
  tUInt8 DEF_n__read__h25142;
  tUInt8 DEF_n__read__h25144;
  tUInt8 DEF_n__read__h25146;
  tUInt8 DEF_n__read__h25148;
  tUInt8 DEF_n__read__h25150;
  tUInt8 DEF_n__read__h25152;
  tUInt8 DEF_n__read__h25154;
  tUInt8 DEF_n__read__h25156;
  tUInt32 DEF_imm__h37546;
  tUInt8 DEF_IF_d2eQueue_first__74_BIT_212_83_THEN_d2eQueue_ETC___d685;
  tUInt8 DEF_d2eQueue_first__74_BIT_112_75_EQ_epoch_51___d676;
  tUInt8 DEF_e2wQueue_first__61_BITS_60_TO_56_82_EQ_0___d883;
  tUInt8 DEF_e2wQueue_first__61_BITS_53_TO_52_66_EQ_0b0___d867;
  tUInt8 DEF_d2eQueue_first__74_BITS_181_TO_180_78_EQ_0b0___d679;
  tUInt8 DEF_SEL_ARR_IF_scoreboard_0_readBeforeLaterWrites__ETC___d393;
  tUInt8 DEF_SEL_ARR_IF_scoreboard_0_readBeforeLaterWrites__ETC___d389;
  tUInt8 DEF_d2eQueue_first__74_BIT_183_77_OR_NOT_d2eQueue__ETC___d681;
  tUInt32 DEF_x__h38032;
  tUInt32 DEF_x__h37869;
  tUInt32 DEF_x__h37799;
 
 /* Local definitions */
 private:
  tUInt32 DEF_TASK_fopen___d233;
  tUInt32 DEF_signed_0___d244;
  tUWide DEF_f2dQueue_first____d401;
  tUInt32 DEF_def__h40069;
  tUInt32 DEF_x_wget__h1441;
  tUInt32 DEF_lfh___d234;
  tUInt8 DEF_x_wget__h20620;
  tUInt8 DEF_x_wget__h20123;
  tUInt8 DEF_x_wget__h19626;
  tUInt8 DEF_x_wget__h19129;
  tUInt8 DEF_x_wget__h18632;
  tUInt8 DEF_x_wget__h18135;
  tUInt8 DEF_x_wget__h17638;
  tUInt8 DEF_x_wget__h17141;
  tUInt8 DEF_x_wget__h16644;
  tUInt8 DEF_x_wget__h16147;
  tUInt8 DEF_x_wget__h15650;
  tUInt8 DEF_x_wget__h15153;
  tUInt8 DEF_x_wget__h14656;
  tUInt8 DEF_x_wget__h14159;
  tUInt8 DEF_x_wget__h13662;
  tUInt8 DEF_x_wget__h13165;
  tUInt8 DEF_x_wget__h12668;
  tUInt8 DEF_x_wget__h12171;
  tUInt8 DEF_x_wget__h11674;
  tUInt8 DEF_x_wget__h11177;
  tUInt8 DEF_x_wget__h10680;
  tUInt8 DEF_x_wget__h10183;
  tUInt8 DEF_x_wget__h9686;
  tUInt8 DEF_x_wget__h9189;
  tUInt8 DEF_x_wget__h8692;
  tUInt8 DEF_x_wget__h8195;
  tUInt8 DEF_x_wget__h7698;
  tUInt8 DEF_x_wget__h7201;
  tUInt8 DEF_x_wget__h6704;
  tUInt8 DEF_x_wget__h6207;
  tUInt8 DEF_x_wget__h5710;
  tUInt8 DEF_x_wget__h5206;
  tUWide DEF_f2dQueue_first__01_BITS_112_TO_48___d530;
  tUInt32 DEF_def__h1756;
  tUInt8 DEF_def__h20925;
  tUInt8 DEF_def__h20428;
  tUInt8 DEF_def__h19931;
  tUInt8 DEF_def__h19434;
  tUInt8 DEF_def__h18937;
  tUInt8 DEF_def__h18440;
  tUInt8 DEF_def__h17943;
  tUInt8 DEF_def__h17446;
  tUInt8 DEF_def__h16949;
  tUInt8 DEF_def__h16452;
  tUInt8 DEF_def__h15955;
  tUInt8 DEF_def__h15458;
  tUInt8 DEF_def__h14961;
  tUInt8 DEF_def__h14464;
  tUInt8 DEF_def__h13967;
  tUInt8 DEF_def__h13470;
  tUInt8 DEF_def__h12973;
  tUInt8 DEF_def__h12476;
  tUInt8 DEF_def__h11979;
  tUInt8 DEF_def__h11482;
  tUInt8 DEF_def__h10985;
  tUInt8 DEF_def__h10488;
  tUInt8 DEF_def__h9991;
  tUInt8 DEF_def__h9494;
  tUInt8 DEF_def__h8997;
  tUInt8 DEF_def__h8500;
  tUInt8 DEF_def__h8003;
  tUInt8 DEF_def__h7506;
  tUInt8 DEF_def__h7009;
  tUInt8 DEF_def__h6512;
  tUInt8 DEF_def__h6015;
  tUInt8 DEF_def__h5518;
  tUWide DEF_IF_fromImem_rv_port1__read__55_BITS_6_TO_0_05__ETC___d570;
  tUWide DEF_IF_fromImem_rv_port1__read__55_BITS_19_TO_15_8_ETC___d569;
  tUWide DEF_NOT_d2eQueue_first__74_BIT_183_77_43_AND_d2eQu_ETC___d805;
  tUWide DEF_d2eQueue_first__74_BITS_216_TO_177_03_CONCAT_d_ETC___d804;
  tUWide DEF_pc_register_CONCAT_IF_pc_readBeforeLaterWrites_ETC___d253;
  tUWide DEF__16_CONCAT_pc_register_CONCAT_0___d249;
  tUWide DEF__1_CONCAT_IF_d2eQueue_first__74_BIT_182_59_THEN_ETC___d819;
  tUWide DEF__1_CONCAT_getMMIOResp_a___d1114;
  tUWide DEF__1_CONCAT_getDResp_a___d1110;
  tUWide DEF__1_CONCAT_getIResp_a___d1106;
  tUWide DEF__0_CONCAT_DONTCARE___d404;
 
 /* Rules */
 public:
  void RL_pc_canonicalize();
  void RL_scoreboard_0_canonicalize();
  void RL_scoreboard_1_canonicalize();
  void RL_scoreboard_2_canonicalize();
  void RL_scoreboard_3_canonicalize();
  void RL_scoreboard_4_canonicalize();
  void RL_scoreboard_5_canonicalize();
  void RL_scoreboard_6_canonicalize();
  void RL_scoreboard_7_canonicalize();
  void RL_scoreboard_8_canonicalize();
  void RL_scoreboard_9_canonicalize();
  void RL_scoreboard_10_canonicalize();
  void RL_scoreboard_11_canonicalize();
  void RL_scoreboard_12_canonicalize();
  void RL_scoreboard_13_canonicalize();
  void RL_scoreboard_14_canonicalize();
  void RL_scoreboard_15_canonicalize();
  void RL_scoreboard_16_canonicalize();
  void RL_scoreboard_17_canonicalize();
  void RL_scoreboard_18_canonicalize();
  void RL_scoreboard_19_canonicalize();
  void RL_scoreboard_20_canonicalize();
  void RL_scoreboard_21_canonicalize();
  void RL_scoreboard_22_canonicalize();
  void RL_scoreboard_23_canonicalize();
  void RL_scoreboard_24_canonicalize();
  void RL_scoreboard_25_canonicalize();
  void RL_scoreboard_26_canonicalize();
  void RL_scoreboard_27_canonicalize();
  void RL_scoreboard_28_canonicalize();
  void RL_scoreboard_29_canonicalize();
  void RL_scoreboard_30_canonicalize();
  void RL_scoreboard_31_canonicalize();
  void RL_do_tic_logging();
  void RL_fetch();
  void RL_decode();
  void RL_execute();
  void RL_writeback();
  void RL_administrative_konata_commit();
  void RL_administrative_konata_flush();
 
 /* Methods */
 public:
  tUWide METH_getIReq();
  tUInt8 METH_RDY_getIReq();
  void METH_getIResp(tUWide ARG_getIResp_a);
  tUInt8 METH_RDY_getIResp();
  tUWide METH_getDReq();
  tUInt8 METH_RDY_getDReq();
  void METH_getDResp(tUWide ARG_getDResp_a);
  tUInt8 METH_RDY_getDResp();
  tUWide METH_getMMIOReq();
  tUInt8 METH_RDY_getMMIOReq();
  void METH_getMMIOResp(tUWide ARG_getMMIOResp_a);
  tUInt8 METH_RDY_getMMIOResp();
 
 /* Reset routines */
 public:
  void reset_RST_N(tUInt8 ARG_rst_in);
 
 /* Static handles to reset routines */
 public:
 
 /* Pointers to reset fns in parent module for asserting output resets */
 private:
 
 /* Functions for the parent module to register its reset fns */
 public:
 
 /* Functions to set the elaborated clock id */
 public:
  void set_clk_0(char const *s);
 
 /* State dumping routine */
 public:
  void dump_state(unsigned int indent);
 
 /* VCD dumping routines */
 public:
  unsigned int dump_VCD_defs(unsigned int levels);
  void dump_VCD(tVCDDumpType dt, unsigned int levels, MOD_mkpipelined &backing);
  void vcd_defs(tVCDDumpType dt, MOD_mkpipelined &backing);
  void vcd_prims(tVCDDumpType dt, MOD_mkpipelined &backing);
};

#endif /* ifndef __mkpipelined_h__ */
