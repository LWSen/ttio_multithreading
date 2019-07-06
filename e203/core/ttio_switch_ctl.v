`include "e203_defines.v"
module ttio_switch_ctl(
  input ttio_wait,
  input rv32_ttiat,
  input rv32_ttoat,
  input [`E203_THREADS_NUM-1:0]thread_sel,
  output ttio_switch_en,
  input clk,
  input rst_n
);

wire ttio_ldst = rv32_ttiat | rv32_ttoat;
assign ttio_switch_en = (ttio_ldst & thread_sel[0] & ttio_wait)
                        | (thread_sel[1] & (~ttio_wait));

endmodule

