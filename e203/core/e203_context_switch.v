`include "e203_defines.v"

module e203_context_switch(
  input [`E203_THREADS_NUM-1:0] exu_thread_sel,
  input allow_switch,
  input dbg_mode,
  input commit_trap,
  input commit_mret,
  input long_inst,
  input bjp,
  input ifetch_wait,
  output switch_en,
  output [`E203_THREADS_NUM-1:0] thread_sel,
  output [`E203_THREADS_NUM-1:0] thread_sel_next,
`ifdef E203_SUPPORT_TTIO
  input rv32_ttiat,
  input rv32_ttoat,
  input ttio_wait,
`endif
  input clk,
  input rst_n
);

 
//round-robin
  localparam TIME_SLICE = 10'h3FF;
  reg [9:0] cycles;
  wire new_slice = (cycles==0);
  
  always @(posedge clk or negedge rst_n)
  begin
    if(~rst_n | ~allow_switch | switch_en) cycles = TIME_SLICE;
    else begin
      if(new_slice) cycles = 0;
      else cycles = cycles-1;
    end
  end
  
//ttio 
`ifdef E203_SUPPORT_TTIO 
wire ttio_switch_en;
  ttio_switch_ctl u_ttio_switch_ctl(
    .ttio_wait  (ttio_wait ),
    .rv32_ttiat (rv32_ttiat),
    .rv32_ttoat (rv32_ttoat),
    .thread_sel (thread_sel),
    .ttio_switch_en (ttio_switch_en),
    .clk        (clk       ),
    .rst_n      (rst_n     )
  );
`endif

  wire excp_handling_set = commit_trap;
  wire excp_handling_clr = commit_mret;
  wire excp_handling_en = excp_handling_set | excp_handling_clr;
  wire excp_handling;
  wire excp_handling_next = excp_handling_set | (~excp_handling_clr);
  sirv_gnrl_dfflr #(1) excp_handling_dfflr(excp_handling_en, excp_handling_next, excp_handling, clk, rst_n);
  
  wire thread_same = (thread_sel==exu_thread_sel);
  wire trap_switch = commit_trap & ~thread_same;
  `ifdef E203_SUPPORT_TTIO
    assign switch_en = allow_switch & (ttio_switch_en | trap_switch) & (~ifetch_wait) & (~excp_handling) & (~dbg_mode);
  `else
    assign switch_en = allow_switch & (new_slice | trap_switch) & (~ifetch_wait) & (~excp_handling) & (~dbg_mode);
  `endif
  
  assign thread_sel_next[0] = thread_sel[0]^switch_en;
  assign thread_sel_next[1] = thread_sel[1]^switch_en;

  sirv_gnrl_dfflr_init #(`E203_THREADS_NUM, `E203_THREADS_NUM'b01) thread_sel_dff (switch_en, thread_sel_next, thread_sel, clk, rst_n);

endmodule
