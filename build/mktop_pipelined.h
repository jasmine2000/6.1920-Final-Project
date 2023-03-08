/*
 * Generated by Bluespec Compiler, version 2023.01-6-g034050db (build 034050db)
 * 
 * On Wed Mar  8 08:45:58 EST 2023
 * 
 */

/* Generation options: */
#ifndef __mktop_pipelined_h__
#define __mktop_pipelined_h__

#include "bluesim_types.h"
#include "bs_module.h"
#include "bluesim_primitives.h"
#include "bs_vcd.h"
#include "mkpipelined.h"


/* Class declaration for the mktop_pipelined module */
class MOD_mktop_pipelined : public Module {
 
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
  MOD_BRAM<tUInt32,tUInt32,tUInt8> INST_bram_memory;
  MOD_Reg<tUInt8> INST_bram_serverAdapterA_cnt;
  MOD_Wire<tUInt8> INST_bram_serverAdapterA_cnt_1;
  MOD_Wire<tUInt8> INST_bram_serverAdapterA_cnt_2;
  MOD_Wire<tUInt8> INST_bram_serverAdapterA_cnt_3;
  MOD_Reg<tUInt8> INST_bram_serverAdapterA_outData_beforeDeq;
  MOD_Reg<tUInt8> INST_bram_serverAdapterA_outData_beforeEnq;
  MOD_Wire<tUInt8> INST_bram_serverAdapterA_outData_dequeueing;
  MOD_Wire<tUInt32> INST_bram_serverAdapterA_outData_enqw;
  MOD_Fifo<tUInt32> INST_bram_serverAdapterA_outData_ff;
  MOD_Reg<tUInt8> INST_bram_serverAdapterA_s1;
  MOD_Wire<tUInt8> INST_bram_serverAdapterA_s1_1;
  MOD_Wire<tUInt8> INST_bram_serverAdapterA_writeWithResp;
  MOD_Reg<tUInt8> INST_bram_serverAdapterB_cnt;
  MOD_Wire<tUInt8> INST_bram_serverAdapterB_cnt_1;
  MOD_Wire<tUInt8> INST_bram_serverAdapterB_cnt_2;
  MOD_Wire<tUInt8> INST_bram_serverAdapterB_cnt_3;
  MOD_Reg<tUInt8> INST_bram_serverAdapterB_outData_beforeDeq;
  MOD_Reg<tUInt8> INST_bram_serverAdapterB_outData_beforeEnq;
  MOD_Wire<tUInt8> INST_bram_serverAdapterB_outData_dequeueing;
  MOD_Wire<tUInt32> INST_bram_serverAdapterB_outData_enqw;
  MOD_Fifo<tUInt32> INST_bram_serverAdapterB_outData_ff;
  MOD_Reg<tUInt8> INST_bram_serverAdapterB_s1;
  MOD_Wire<tUInt8> INST_bram_serverAdapterB_s1_1;
  MOD_Wire<tUInt8> INST_bram_serverAdapterB_writeWithResp;
  MOD_Reg<tUInt32> INST_cycle_count;
  MOD_Reg<tUWide> INST_dreq;
  MOD_Reg<tUWide> INST_ireq;
  MOD_Fifo<tUWide> INST_mmioreq;
  MOD_mkpipelined INST_rv_core;
 
 /* Constructor */
 public:
  MOD_mktop_pipelined(tSimStateHdl simHdl, char const *name, Module *parent);
 
 /* Symbol init methods */
 private:
  void init_symbols_0();
 
 /* Reset signal definitions */
 private:
  tUInt8 PORT_RST_N;
 
 /* Port definitions */
 public:
 
 /* Publicly accessible definitions */
 public:
  tUInt8 DEF_b__h2255;
  tUInt8 DEF_b__h910;
  tUInt8 DEF_bram_serverAdapterB_s1___d84;
  tUInt8 DEF_bram_serverAdapterA_s1___d35;
  tUInt8 DEF_bram_serverAdapterB_cnt_3_whas____d63;
  tUInt8 DEF_bram_serverAdapterB_cnt_2_whas____d61;
  tUInt8 DEF_bram_serverAdapterB_cnt_1_whas____d60;
  tUInt8 DEF_bram_serverAdapterB_outData_ff_i_notEmpty____d54;
  tUInt8 DEF_bram_serverAdapterA_cnt_3_whas____d13;
  tUInt8 DEF_bram_serverAdapterA_cnt_2_whas____d11;
  tUInt8 DEF_bram_serverAdapterA_cnt_1_whas____d10;
  tUInt8 DEF_bram_serverAdapterA_outData_ff_i_notEmpty____d4;
  tUInt8 DEF_bram_serverAdapterB_s1_4_BIT_0___d85;
  tUInt8 DEF_bram_serverAdapterA_s1_5_BIT_0___d36;
 
 /* Local definitions */
 private:
  tUWide DEF_rv_core_getMMIOReq___d143;
  tUWide DEF_rv_core_getDReq___d124;
  tUWide DEF_rv_core_getIReq___d105;
  tUWide DEF_mmioreq_first____d160;
  tUWide DEF_dreq___d135;
  tUWide DEF_ireq___d116;
  tUInt32 DEF_x_wget__h1764;
  tUInt32 DEF_x_wget__h416;
  tUInt32 DEF_x__h514;
  tUInt32 DEF_x__h1862;
  tUInt8 DEF__0_CONCAT_DONTCARE___d26;
  tUWide DEF_ireq_16_BITS_67_TO_32_17_CONCAT_IF_bram_server_ETC___d120;
  tUWide DEF_dreq_35_BITS_67_TO_32_36_CONCAT_IF_bram_server_ETC___d139;
 
 /* Rules */
 public:
  void RL_bram_serverAdapterA_outData_enqueue();
  void RL_bram_serverAdapterA_outData_dequeue();
  void RL_bram_serverAdapterA_cnt_finalAdd();
  void RL_bram_serverAdapterA_s1__dreg_update();
  void RL_bram_serverAdapterA_stageReadResponseAlways();
  void RL_bram_serverAdapterA_moveToOutFIFO();
  void RL_bram_serverAdapterA_overRun();
  void RL_bram_serverAdapterB_outData_enqueue();
  void RL_bram_serverAdapterB_outData_dequeue();
  void RL_bram_serverAdapterB_cnt_finalAdd();
  void RL_bram_serverAdapterB_s1__dreg_update();
  void RL_bram_serverAdapterB_stageReadResponseAlways();
  void RL_bram_serverAdapterB_moveToOutFIFO();
  void RL_bram_serverAdapterB_overRun();
  void RL_tic();
  void RL_requestI();
  void RL_responseI();
  void RL_requestD();
  void RL_responseD();
  void RL_requestMMIO();
  void RL_responseMMIO();
 
 /* Methods */
 public:
 
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
  void dump_VCD(tVCDDumpType dt, unsigned int levels, MOD_mktop_pipelined &backing);
  void vcd_defs(tVCDDumpType dt, MOD_mktop_pipelined &backing);
  void vcd_prims(tVCDDumpType dt, MOD_mktop_pipelined &backing);
  void vcd_submodules(tVCDDumpType dt, unsigned int levels, MOD_mktop_pipelined &backing);
};

#endif /* ifndef __mktop_pipelined_h__ */
