/*
 * Generated by Bluespec Compiler, version 2023.01-6-g034050db (build 034050db)
 * 
 * On Wed Mar  8 08:45:53 EST 2023
 * 
 */
#include "bluesim_primitives.h"
#include "model_mkmulticycle.h"

#include <cstdlib>
#include <time.h>
#include "bluesim_kernel_api.h"
#include "bs_vcd.h"
#include "bs_reset.h"


/* Constructor */
MODEL_mkmulticycle::MODEL_mkmulticycle()
{
  mkmulticycle_instance = NULL;
}

/* Function for creating a new model */
void * new_MODEL_mkmulticycle()
{
  MODEL_mkmulticycle *model = new MODEL_mkmulticycle();
  return (void *)(model);
}

/* Schedule functions */

static void schedule_posedge_CLK(tSimStateHdl simHdl, void *instance_ptr)
       {
	 MOD_mkmulticycle &INST_top = *((MOD_mkmulticycle *)(instance_ptr));
	 tUInt8 DEF_INST_top_DEF_NOT_starting___d9;
	 tUInt8 DEF_INST_top_DEF_NOT_toMMIO_rv_port0__read__42_BIT_68_43___d244;
	 tUInt8 DEF_INST_top_DEF_IF_rv1_95_PLUS_IF_dInst_89_BIT_35_96_AND_IF_dI_ETC___d248;
	 tUInt8 DEF_INST_top_DEF_IF_mem_business_57_BIT_0_58_THEN_fromMMIO_rv_p_ETC___d363;
	 tUInt8 DEF_INST_top_DEF_IF_mem_business_57_BITS_5_TO_3_68_EQ_0b0_69_OR_ETC___d379;
	 tUInt8 DEF_INST_top_DEF_state__h4470;
	 tUInt8 DEF_INST_top_DEF_CAN_FIRE_RL_do_tic_logging;
	 tUInt8 DEF_INST_top_DEF_WILL_FIRE_RL_do_tic_logging;
	 tUInt8 DEF_INST_top_DEF_CAN_FIRE_RL_fetch;
	 tUInt8 DEF_INST_top_DEF_WILL_FIRE_RL_fetch;
	 tUInt8 DEF_INST_top_DEF_CAN_FIRE_RL_decode;
	 tUInt8 DEF_INST_top_DEF_WILL_FIRE_RL_decode;
	 tUInt8 DEF_INST_top_DEF_CAN_FIRE_RL_execute;
	 tUInt8 DEF_INST_top_DEF_WILL_FIRE_RL_execute;
	 tUInt8 DEF_INST_top_DEF_CAN_FIRE_RL_writeback;
	 tUInt8 DEF_INST_top_DEF_WILL_FIRE_RL_writeback;
	 tUInt8 DEF_INST_top_DEF_CAN_FIRE_RL_administrative_konata_commit;
	 tUInt8 DEF_INST_top_DEF_WILL_FIRE_RL_administrative_konata_commit;
	 tUInt8 DEF_INST_top_DEF_CAN_FIRE_RL_administrative_konata_flush;
	 tUInt8 DEF_INST_top_DEF_WILL_FIRE_RL_administrative_konata_flush;
	 DEF_INST_top_DEF_CAN_FIRE_RL_administrative_konata_commit = INST_top.INST_retired.METH_i_notEmpty();
	 DEF_INST_top_DEF_WILL_FIRE_RL_administrative_konata_commit = DEF_INST_top_DEF_CAN_FIRE_RL_administrative_konata_commit;
	 DEF_INST_top_DEF_CAN_FIRE_RL_administrative_konata_flush = INST_top.INST_squashed.METH_i_notEmpty();
	 DEF_INST_top_DEF_WILL_FIRE_RL_administrative_konata_flush = DEF_INST_top_DEF_CAN_FIRE_RL_administrative_konata_flush;
	 DEF_INST_top_DEF_CAN_FIRE_RL_do_tic_logging = (tUInt8)1u;
	 DEF_INST_top_DEF_WILL_FIRE_RL_do_tic_logging = DEF_INST_top_DEF_CAN_FIRE_RL_do_tic_logging;
	 INST_top.DEF_toMMIO_rv_port0__read____d242 = INST_top.INST_toMMIO_rv.METH_port0__read();
	 INST_top.DEF_toDmem_rv_port0__read____d245 = INST_top.INST_toDmem_rv.METH_port0__read();
	 INST_top.DEF_dInst___d189 = INST_top.INST_dInst.METH_read();
	 INST_top.DEF_dInst_89_BITS_11_TO_7___d206 = (tUInt8)((tUInt8)31u & ((INST_top.DEF_dInst___d189) >> 7u));
	 INST_top.DEF_dInst_89_BIT_6___d190 = (tUInt8)((tUInt8)1u & ((INST_top.DEF_dInst___d189) >> 6u));
	 INST_top.DEF_rs1_val__h10070 = INST_top.INST_rv1.METH_read();
	 DEF_INST_top_DEF_state__h4470 = INST_top.INST_state.METH_read();
	 INST_top.DEF_starting__h4013 = INST_top.INST_starting.METH_read();
	 INST_top.DEF_dInst_89_BIT_35___d196 = (tUInt8)((tUInt8)1u & ((INST_top.DEF_dInst___d189) >> 35u));
	 INST_top.DEF_x__h8347 = (tUInt32)(4095u & ((INST_top.DEF_dInst___d189) >> 20u));
	 INST_top.DEF_dInst_89_BIT_31___d211 = (tUInt8)((tUInt8)1u & ((INST_top.DEF_dInst___d189) >> 31u));
	 INST_top.DEF_IF_dInst_89_BIT_35_96_THEN_dInst_89_BITS_34_TO_ETC___d198 = (tUInt8)((tUInt8)7u & ((INST_top.DEF_dInst___d189) >> 32u));
	 DEF_INST_top_DEF_NOT_toMMIO_rv_port0__read__42_BIT_68_43___d244 = !INST_top.DEF_toMMIO_rv_port0__read____d242.get_bits_in_word8(2u,
																	 4u,
																	 1u);
	 INST_top.DEF_dInst_89_BITS_4_TO_3_91_EQ_0b0___d192 = ((tUInt8)((tUInt8)3u & ((INST_top.DEF_dInst___d189) >> 3u))) == (tUInt8)0u;
	 INST_top.DEF_dInst_89_BIT_6_90_OR_NOT_dInst_89_BITS_4_TO_3__ETC___d194 = INST_top.DEF_dInst_89_BIT_6___d190 || !(INST_top.DEF_dInst_89_BITS_4_TO_3_91_EQ_0b0___d192);
	 DEF_INST_top_DEF_NOT_starting___d9 = !(INST_top.DEF_starting__h4013);
	 INST_top.DEF_x__h8463 = 8191u & (((((((tUInt32)(INST_top.DEF_dInst_89_BIT_31___d211)) << 12u) | (((tUInt32)((tUInt8)((tUInt8)1u & ((INST_top.DEF_dInst___d189) >> 7u)))) << 11u)) | (((tUInt32)((tUInt8)((tUInt8)63u & ((INST_top.DEF_dInst___d189) >> 25u)))) << 5u)) | (((tUInt32)((tUInt8)((tUInt8)15u & ((INST_top.DEF_dInst___d189) >> 8u)))) << 1u)) | (tUInt32)((tUInt8)0u));
	 INST_top.DEF_x__h8624 = 2097151u & (((((((tUInt32)(INST_top.DEF_dInst_89_BIT_31___d211)) << 20u) | (((tUInt32)((tUInt8)((tUInt8)255u & ((INST_top.DEF_dInst___d189) >> 12u)))) << 12u)) | (((tUInt32)((tUInt8)((tUInt8)1u & ((INST_top.DEF_dInst___d189) >> 20u)))) << 11u)) | (((tUInt32)(1023u & ((INST_top.DEF_dInst___d189) >> 21u))) << 1u)) | (tUInt32)((tUInt8)0u));
	 INST_top.DEF_x__h8394 = 4095u & ((((tUInt32)((tUInt8)((tUInt8)127u & ((INST_top.DEF_dInst___d189) >> 25u)))) << 5u) | (tUInt32)(INST_top.DEF_dInst_89_BITS_11_TO_7___d206));
	 INST_top.DEF_imm__h8147 = INST_top.DEF_dInst_89_BIT_35___d196 && (INST_top.DEF_IF_dInst_89_BIT_35_96_THEN_dInst_89_BITS_34_TO_ETC___d198) == (tUInt8)0u ? primSignExt32(32u,
																						 12u,
																						 (tUInt32)(INST_top.DEF_x__h8347)) : (INST_top.DEF_dInst_89_BIT_35___d196 && (INST_top.DEF_IF_dInst_89_BIT_35_96_THEN_dInst_89_BITS_34_TO_ETC___d198) == (tUInt8)1u ? primSignExt32(32u,
																																												    12u,
																																												    (tUInt32)(INST_top.DEF_x__h8394)) : (INST_top.DEF_dInst_89_BIT_35___d196 && (INST_top.DEF_IF_dInst_89_BIT_35_96_THEN_dInst_89_BITS_34_TO_ETC___d198) == (tUInt8)2u ? primSignExt32(32u,
																																																																		       13u,
																																																																		       (tUInt32)(INST_top.DEF_x__h8463)) : (INST_top.DEF_dInst_89_BIT_35___d196 && (INST_top.DEF_IF_dInst_89_BIT_35_96_THEN_dInst_89_BITS_34_TO_ETC___d198) == (tUInt8)3u ? ((tUInt32)(1048575u & ((INST_top.DEF_dInst___d189) >> 12u))) << 12u : (INST_top.DEF_dInst_89_BIT_35___d196 && (INST_top.DEF_IF_dInst_89_BIT_35_96_THEN_dInst_89_BITS_34_TO_ETC___d198) == (tUInt8)4u ? primSignExt32(32u,
																																																																																																																		 21u,
																																																																																																																		 (tUInt32)(INST_top.DEF_x__h8624)) : 0u))));
	 INST_top.DEF_rv1_95_PLUS_IF_dInst_89_BIT_35_96_AND_IF_dInst_ETC___d235 = (INST_top.DEF_rs1_val__h10070) + (INST_top.DEF_imm__h8147);
	 INST_top.DEF_rv1_95_PLUS_IF_dInst_89_BIT_35_96_AND_IF_dInst_ETC___d236 = (tUInt32)((INST_top.DEF_rv1_95_PLUS_IF_dInst_89_BIT_35_96_AND_IF_dInst_ETC___d235) >> 2u);
	 switch (INST_top.DEF_rv1_95_PLUS_IF_dInst_89_BIT_35_96_AND_IF_dInst_ETC___d236) {
	 case 1006649340u:
	 case 1006649341u:
	 case 1006649342u:
	   DEF_INST_top_DEF_IF_rv1_95_PLUS_IF_dInst_89_BIT_35_96_AND_IF_dI_ETC___d248 = DEF_INST_top_DEF_NOT_toMMIO_rv_port0__read__42_BIT_68_43___d244;
	   break;
	 default:
	   DEF_INST_top_DEF_IF_rv1_95_PLUS_IF_dInst_89_BIT_35_96_AND_IF_dI_ETC___d248 = !INST_top.DEF_toDmem_rv_port0__read____d245.get_bits_in_word8(2u,
																		      4u,
																		      1u);
	 }
	 DEF_INST_top_DEF_CAN_FIRE_RL_execute = (INST_top.DEF_dInst_89_BIT_6_90_OR_NOT_dInst_89_BITS_4_TO_3__ETC___d194 || DEF_INST_top_DEF_IF_rv1_95_PLUS_IF_dInst_89_BIT_35_96_AND_IF_dI_ETC___d248) && (DEF_INST_top_DEF_state__h4470 == (tUInt8)2u && DEF_INST_top_DEF_NOT_starting___d9);
	 DEF_INST_top_DEF_WILL_FIRE_RL_execute = DEF_INST_top_DEF_CAN_FIRE_RL_execute;
	 INST_top.DEF_toImem_rv_port0__read____d4 = INST_top.INST_toImem_rv.METH_port0__read();
	 DEF_INST_top_DEF_CAN_FIRE_RL_fetch = !INST_top.DEF_toImem_rv_port0__read____d4.get_bits_in_word8(2u,
													  4u,
													  1u) && (DEF_INST_top_DEF_state__h4470 == (tUInt8)0u && DEF_INST_top_DEF_NOT_starting___d9);
	 DEF_INST_top_DEF_WILL_FIRE_RL_fetch = DEF_INST_top_DEF_CAN_FIRE_RL_fetch;
	 INST_top.DEF_WILL_FIRE_getDResp = INST_top.PORT_EN_getDResp;
	 INST_top.METH_RDY_getDResp();
	 INST_top.DEF_WILL_FIRE_getIResp = INST_top.PORT_EN_getIResp;
	 INST_top.METH_RDY_getIResp();
	 INST_top.DEF_WILL_FIRE_getMMIOResp = INST_top.PORT_EN_getMMIOResp;
	 INST_top.METH_RDY_getMMIOResp();
	 if (DEF_INST_top_DEF_WILL_FIRE_RL_execute)
	   INST_top.RL_execute();
	 INST_top.DEF_WILL_FIRE_getDReq = INST_top.PORT_EN_getDReq;
	 INST_top.METH_RDY_getDReq();
	 INST_top.DEF_WILL_FIRE_getMMIOReq = INST_top.PORT_EN_getMMIOReq;
	 INST_top.METH_RDY_getMMIOReq();
	 if (DEF_INST_top_DEF_WILL_FIRE_RL_fetch)
	   INST_top.RL_fetch();
	 INST_top.DEF_WILL_FIRE_getIReq = INST_top.PORT_EN_getIReq;
	 INST_top.METH_RDY_getIReq();
	 if (INST_top.DEF_WILL_FIRE_getDReq)
	   INST_top.METH_getDReq();
	 if (INST_top.DEF_WILL_FIRE_getDResp)
	   INST_top.METH_getDResp(INST_top.PORT_getDResp_a);
	 if (INST_top.DEF_WILL_FIRE_getIReq)
	   INST_top.METH_getIReq();
	 if (INST_top.DEF_WILL_FIRE_getMMIOReq)
	   INST_top.METH_getMMIOReq();
	 if (INST_top.DEF_WILL_FIRE_getIResp)
	   INST_top.METH_getIResp(INST_top.PORT_getIResp_a);
	 INST_top.DEF_fromImem_rv_port1__read____d17 = INST_top.INST_fromImem_rv.METH_port1__read();
	 DEF_INST_top_DEF_CAN_FIRE_RL_decode = (INST_top.DEF_fromImem_rv_port1__read____d17.get_bits_in_word8(2u,
													      4u,
													      1u) && (DEF_INST_top_DEF_state__h4470 == (tUInt8)1u && DEF_INST_top_DEF_NOT_starting___d9)) && !(DEF_INST_top_DEF_CAN_FIRE_RL_execute || DEF_INST_top_DEF_CAN_FIRE_RL_fetch);
	 DEF_INST_top_DEF_WILL_FIRE_RL_decode = DEF_INST_top_DEF_CAN_FIRE_RL_decode;
	 if (DEF_INST_top_DEF_WILL_FIRE_RL_decode)
	   INST_top.RL_decode();
	 if (INST_top.DEF_WILL_FIRE_getMMIOResp)
	   INST_top.METH_getMMIOResp(INST_top.PORT_getMMIOResp_a);
	 INST_top.DEF_fromMMIO_rv_port1__read____d359 = INST_top.INST_fromMMIO_rv.METH_port1__read();
	 INST_top.DEF_fromDmem_rv_port1__read____d361 = INST_top.INST_fromDmem_rv.METH_port1__read();
	 INST_top.DEF_mem_business___d357 = INST_top.INST_mem_business.METH_read();
	 INST_top.DEF_mem_business_57_BIT_0___d358 = (tUInt8)((tUInt8)1u & (INST_top.DEF_mem_business___d357));
	 INST_top.DEF_mem_business_57_BITS_5_TO_3___d368 = (tUInt8)((INST_top.DEF_mem_business___d357) >> 3u);
	 INST_top.DEF_dInst_89_BIT_36___d365 = (tUInt8)((tUInt8)1u & ((INST_top.DEF_dInst___d189) >> 36u));
	 DEF_INST_top_DEF_IF_mem_business_57_BIT_0_58_THEN_fromMMIO_rv_p_ETC___d363 = INST_top.DEF_mem_business_57_BIT_0___d358 ? INST_top.DEF_fromMMIO_rv_port1__read____d359.get_bits_in_word8(2u,
																								 4u,
																								 1u) : INST_top.DEF_fromDmem_rv_port1__read____d361.get_bits_in_word8(2u,
																																      4u,
																																      1u);
	 switch (INST_top.DEF_mem_business_57_BITS_5_TO_3___d368) {
	 case (tUInt8)0u:
	 case (tUInt8)1u:
	 case (tUInt8)4u:
	 case (tUInt8)5u:
	   DEF_INST_top_DEF_IF_mem_business_57_BITS_5_TO_3_68_EQ_0b0_69_OR_ETC___d379 = DEF_INST_top_DEF_IF_mem_business_57_BIT_0_58_THEN_fromMMIO_rv_p_ETC___d363;
	   break;
	 default:
	   DEF_INST_top_DEF_IF_mem_business_57_BITS_5_TO_3_68_EQ_0b0_69_OR_ETC___d379 = !((INST_top.DEF_mem_business_57_BITS_5_TO_3___d368) == (tUInt8)2u) || DEF_INST_top_DEF_IF_mem_business_57_BIT_0_58_THEN_fromMMIO_rv_p_ETC___d363;
	 }
	 INST_top.DEF_dInst_89_BITS_11_TO_7_06_EQ_0___d367 = (INST_top.DEF_dInst_89_BITS_11_TO_7___d206) == (tUInt8)0u;
	 DEF_INST_top_DEF_CAN_FIRE_RL_writeback = ((INST_top.INST_retired.METH_i_notFull() && ((INST_top.DEF_dInst_89_BIT_6_90_OR_NOT_dInst_89_BITS_4_TO_3__ETC___d194 || DEF_INST_top_DEF_IF_mem_business_57_BIT_0_58_THEN_fromMMIO_rv_p_ETC___d363) && (!(INST_top.DEF_dInst_89_BIT_36___d365) || (INST_top.DEF_dInst_89_BITS_11_TO_7_06_EQ_0___d367 || (INST_top.DEF_dInst_89_BIT_6_90_OR_NOT_dInst_89_BITS_4_TO_3__ETC___d194 || DEF_INST_top_DEF_IF_mem_business_57_BITS_5_TO_3_68_EQ_0b0_69_OR_ETC___d379))))) && (DEF_INST_top_DEF_state__h4470 == (tUInt8)3u && DEF_INST_top_DEF_NOT_starting___d9)) && !((DEF_INST_top_DEF_CAN_FIRE_RL_execute || DEF_INST_top_DEF_CAN_FIRE_RL_decode) || DEF_INST_top_DEF_CAN_FIRE_RL_fetch);
	 DEF_INST_top_DEF_WILL_FIRE_RL_writeback = DEF_INST_top_DEF_CAN_FIRE_RL_writeback;
	 if (DEF_INST_top_DEF_WILL_FIRE_RL_writeback)
	   INST_top.RL_writeback();
	 if (DEF_INST_top_DEF_WILL_FIRE_RL_administrative_konata_commit)
	   INST_top.RL_administrative_konata_commit();
	 if (DEF_INST_top_DEF_WILL_FIRE_RL_administrative_konata_flush)
	   INST_top.RL_administrative_konata_flush();
	 if (DEF_INST_top_DEF_WILL_FIRE_RL_do_tic_logging)
	   INST_top.RL_do_tic_logging();
	 INST_top.INST_fromMMIO_rv.clk((tUInt8)1u, (tUInt8)1u);
	 INST_top.INST_toMMIO_rv.clk((tUInt8)1u, (tUInt8)1u);
	 INST_top.INST_fromDmem_rv.clk((tUInt8)1u, (tUInt8)1u);
	 INST_top.INST_toDmem_rv.clk((tUInt8)1u, (tUInt8)1u);
	 INST_top.INST_fromImem_rv.clk((tUInt8)1u, (tUInt8)1u);
	 INST_top.INST_toImem_rv.clk((tUInt8)1u, (tUInt8)1u);
	 if (do_reset_ticks(simHdl))
	 {
	   INST_top.INST_toImem_rv.rst_tick_clk((tUInt8)1u);
	   INST_top.INST_fromImem_rv.rst_tick_clk((tUInt8)1u);
	   INST_top.INST_toDmem_rv.rst_tick_clk((tUInt8)1u);
	   INST_top.INST_fromDmem_rv.rst_tick_clk((tUInt8)1u);
	   INST_top.INST_toMMIO_rv.rst_tick_clk((tUInt8)1u);
	   INST_top.INST_fromMMIO_rv.rst_tick_clk((tUInt8)1u);
	   INST_top.INST_pc.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_0.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_1.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_2.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_3.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_4.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_5.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_6.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_7.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_8.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_9.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_10.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_11.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_12.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_13.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_14.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_15.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_16.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_17.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_18.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_19.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_20.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_21.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_22.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_23.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_24.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_25.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_26.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_27.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_28.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_29.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_30.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rf_31.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_state.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rv1.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rv2.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_rvd.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_dInst.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_mem_business.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_lfh.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_current_id.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_fresh_id.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_commit_id.rst_tick__clk__1((tUInt8)1u);
	   INST_top.INST_retired.rst_tick_clk((tUInt8)1u);
	   INST_top.INST_squashed.rst_tick_clk((tUInt8)1u);
	   INST_top.INST_starting.rst_tick__clk__1((tUInt8)1u);
	 }
       };

/* Model creation/destruction functions */

void MODEL_mkmulticycle::create_model(tSimStateHdl simHdl, bool master)
{
  sim_hdl = simHdl;
  init_reset_request_counters(sim_hdl);
  mkmulticycle_instance = new MOD_mkmulticycle(sim_hdl, "top", NULL);
  bk_get_or_define_clock(sim_hdl, "CLK");
  if (master)
  {
    bk_alter_clock(sim_hdl, bk_get_clock_by_name(sim_hdl, "CLK"), CLK_LOW, false, 0llu, 5llu, 5llu);
    bk_use_default_reset(sim_hdl);
  }
  bk_set_clock_event_fn(sim_hdl,
			bk_get_clock_by_name(sim_hdl, "CLK"),
			schedule_posedge_CLK,
			NULL,
			(tEdgeDirection)(POSEDGE));
  (mkmulticycle_instance->INST_toImem_rv.set_clk_0)("CLK");
  (mkmulticycle_instance->INST_fromImem_rv.set_clk_0)("CLK");
  (mkmulticycle_instance->INST_toDmem_rv.set_clk_0)("CLK");
  (mkmulticycle_instance->INST_fromDmem_rv.set_clk_0)("CLK");
  (mkmulticycle_instance->INST_toMMIO_rv.set_clk_0)("CLK");
  (mkmulticycle_instance->INST_fromMMIO_rv.set_clk_0)("CLK");
  (mkmulticycle_instance->INST_retired.set_clk_0)("CLK");
  (mkmulticycle_instance->INST_squashed.set_clk_0)("CLK");
  (mkmulticycle_instance->set_clk_0)("CLK");
}
void MODEL_mkmulticycle::destroy_model()
{
  delete mkmulticycle_instance;
  mkmulticycle_instance = NULL;
}
void MODEL_mkmulticycle::reset_model(bool asserted)
{
  (mkmulticycle_instance->reset_RST_N)(asserted ? (tUInt8)0u : (tUInt8)1u);
}
void * MODEL_mkmulticycle::get_instance()
{
  return mkmulticycle_instance;
}

/* Fill in version numbers */
void MODEL_mkmulticycle::get_version(char const **name, char const **build)
{
  *name = "2023.01-6-g034050db";
  *build = "034050db";
}

/* Get the model creation time */
time_t MODEL_mkmulticycle::get_creation_time()
{
  
  /* Wed Mar  8 13:45:53 UTC 2023 */
  return 1678283153llu;
}

/* State dumping function */
void MODEL_mkmulticycle::dump_state()
{
  (mkmulticycle_instance->dump_state)(0u);
}

/* VCD dumping functions */
MOD_mkmulticycle & mkmulticycle_backing(tSimStateHdl simHdl)
{
  static MOD_mkmulticycle *instance = NULL;
  if (instance == NULL)
  {
    vcd_set_backing_instance(simHdl, true);
    instance = new MOD_mkmulticycle(simHdl, "top", NULL);
    vcd_set_backing_instance(simHdl, false);
  }
  return *instance;
}
void MODEL_mkmulticycle::dump_VCD_defs()
{
  (mkmulticycle_instance->dump_VCD_defs)(vcd_depth(sim_hdl));
}
void MODEL_mkmulticycle::dump_VCD(tVCDDumpType dt)
{
  (mkmulticycle_instance->dump_VCD)(dt, vcd_depth(sim_hdl), mkmulticycle_backing(sim_hdl));
}
