`include "e203_defines.v"

module ttio(
    input  ttio_i_valid,
    output ttio_i_ready,

    input  [`E203_XLEN-1:0] ttio_i_rs1,
    input  [`E203_XLEN-1:0] ttio_i_rs2,
    input  [`E203_XLEN-1:0] ttio_i_imm,
    input  [`E203_DECINFO_TTIO_WIDTH-1:0] ttio_i_info,
    input  [`E203_ITAG_WIDTH-1:0] ttio_i_itag,

    output ttio_i_longpipe,
    output ttio_wait,

    input  ttio_i_flush_req,
    input  ttio_i_flush_pulse,

    // The TTIO Write-Back/Commit Interface
    output ttio_o_valid,
    input  ttio_o_ready,
    output [`E203_XLEN-1:0] ttio_o_wbck_wdat,
    output ttio_o_wbck_err,
    output ttio_o_cmt_misalgn,
    output ttio_o_cmt_ld,
    output ttio_o_cmt_st,
    output ttio_o_cmt_buserr,
    output [`E203_ADDR_SIZE-1:0] ttio_o_cmt_badaddr,

    // The ICB Interface to LSU-ctrl
    //    * Bus CMD channel
    output                       ttio_icb_cmd_valid,
    input                        ttio_icb_cmd_ready,
    output [`E203_ADDR_SIZE-1:0] ttio_icb_cmd_addr,
    output                       ttio_icb_cmd_read,
    output [`E203_XLEN-1:0]      ttio_icb_cmd_wdata, 
    output [`E203_XLEN/8-1:0]    ttio_icb_cmd_wmask, 
    output                       ttio_icb_cmd_back2ttio, 
    output                       ttio_icb_cmd_lock,
    output                       ttio_icb_cmd_excl,
    output [1:0]                 ttio_icb_cmd_size,
    output [`E203_ITAG_WIDTH-1:0]ttio_icb_cmd_itag,
    output                       ttio_icb_cmd_usign,
    //    * Bus RSP channel
    input                        ttio_icb_rsp_valid,
    output                       ttio_icb_rsp_ready,
    input                        ttio_icb_rsp_err  ,
    input                        ttio_icb_rsp_excl_ok,
    input  [`E203_XLEN-1:0]      ttio_icb_rsp_rdata,

    input  clk,
    input  rst_n
);


wire state_is_idle;
wire flush_block = ttio_i_flush_req & state_is_idle;

wire ttio_i_settr = ttio_i_info[`E203_DECINFO_TTIO_SETTR] & (~flush_block);
wire ttio_i_setti = ttio_i_info[`E203_DECINFO_TTIO_SETTI] & (~flush_block);
wire ttio_i_getti = ttio_i_info[`E203_DECINFO_TTIO_GETTI] & (~flush_block);
wire ttio_i_move = ttio_i_info[`E203_DECINFO_TTIO_MOVE] & (~flush_block);
wire ttio_i_ttiat = ttio_i_info[`E203_DECINFO_TTIO_TTIAT] & (~flush_block);
wire ttio_i_ttoat = ttio_i_info[`E203_DECINFO_TTIO_TTOAT] & (~flush_block);

wire [2:0] ttio_i_rtidx = ttio_i_info[`E203_DECINFO_TTIO_RTIDX];
wire [1:0] ttio_i_size = 2'b10;
wire ttio_i_usign = 1'b0;
wire ttio_i_excl = 1'b0;

wire ttio_i_size_b = (ttio_i_size == 2'b00);
wire ttio_i_size_hw = (ttio_i_size == 2'b01);
wire ttio_i_size_w  = (ttio_i_size == 2'b10);

wire ttio_i_addr_unalgn = (ttio_i_size_hw & ttio_icb_cmd_addr[0])
                        | (ttio_i_size_w & (|ttio_icb_cmd_addr[1:0]));

wire ttio_addr_unalgn = ttio_i_addr_unalgn;

wire ttio_i_unalgni = (ttio_addr_unalgn & ttio_i_ttiat);
wire ttio_i_unalgno = (ttio_addr_unalgn & ttio_i_ttoat);
wire ttio_i_unalgnio = ttio_i_unalgni | ttio_i_unalgno;
wire ttio_i_algni = (~ttio_addr_unalgn) & ttio_i_ttiat;
wire ttio_i_algno = (~ttio_addr_unalgn) & ttio_i_ttoat;
wire ttio_i_algnio = ttio_i_algni | ttio_i_algno;

// timer
reg [31:0] tr;
wire tr_w_ena = ttio_i_settr;
wire [31:0] tr_w_data = ttio_i_rs1;
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        tr <= 32'd0;
    end
    else
    begin
        if(tr_w_ena == 1'b1)
        begin
            tr <= tr_w_data;
        end
        else
        begin
            tr <= tr;
        end
    end
end

reg [31:0] count;
reg [31:0] timer;
wire reset_timer = ttio_i_setti;
wire timer_w_ena = 1'b0;
wire [31:0] timer_w_data = 32'd0;
always@(posedge clk or negedge rst_n or posedge reset_timer)
begin
    if(rst_n == 1'b0 || reset_timer == 1'b1)
    begin
        count <= 32'd0;
    end
    else
    begin
        if(count == tr - 1)
        begin
            count <= 32'd0;
        end
        else
        begin
            count <= count + 1;
        end
    end
end

always@(posedge clk or negedge rst_n or posedge reset_timer)
begin
    if(rst_n == 1'b0 || reset_timer == 1'b1)
    begin
        timer <= 32'd0;
    end
    else
    begin
        if(count == tr - 1)
        begin
            timer <= timer + 1;
        end
        else
        begin
            timer <= timer;
        end
    end
end

// t_regfile
reg [31:0] t0;
wire t0_w_ena = ttio_i_move;
wire [31:0] t0_w_data = ttio_i_rs1;
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        t0 <= 32'd0;
    end
    else
    begin
        if(t0_w_ena == 1'b1)
        begin
            t0 <= t0_w_data;
        end
        else
        begin
            t0 <= t0;
        end
    end
end

assign ttio_wait = (timer<t0);
// FSM
localparam ICB_STATE_WIDTH = 4;
reg [ICB_STATE_WIDTH-1:0] icb_state_next;
reg [ICB_STATE_WIDTH-1:0] icb_state_curr;

// settr setti getti move
// if timein == timenow : ttiat, ttoat
localparam ICB_STATE_IDLE = 4'd0;
// else wait
localparam ICB_STATE_WAIT = 4'd1;
//
localparam ICB_STATE_IO = 4'd2;

assign state_is_idle = (icb_state_curr == ICB_STATE_IDLE);
wire state_is_wait = (icb_state_curr == ICB_STATE_WAIT);
wire state_is_io = (icb_state_curr == ICB_STATE_IO);

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
        icb_state_curr <= ICB_STATE_IDLE;
    end
    else
    begin
        icb_state_curr <= icb_state_next;
    end
end

always@(*)
begin
    case(icb_state_curr)
        ICB_STATE_IDLE:
        begin
            if(ttio_i_ttiat == 1'b1 || ttio_i_ttoat == 1'b1)
            begin
                if(t0 > timer)
                begin
                    icb_state_next = ICB_STATE_WAIT;
                end
                else
                begin
                    icb_state_next = ICB_STATE_IO;
                end
            end
            else
            begin
                icb_state_next = ICB_STATE_IDLE;
            end
        end
        ICB_STATE_WAIT:
        begin
            if(t0 <= timer)
            begin
                icb_state_next = ICB_STATE_IO;
            end
            else
            begin
                icb_state_next = ICB_STATE_WAIT;
            end
        end
        ICB_STATE_IO:
        begin
            icb_state_next = ICB_STATE_IDLE;
        end
        default:
        begin
            icb_state_next = ICB_STATE_IDLE;
        end
    endcase
end

// output
assign ttio_i_ready = (state_is_io & ttio_icb_cmd_ready & ttio_o_ready) | (~ttio_i_ttiat & ~ttio_i_ttoat & ttio_icb_cmd_ready & ttio_o_ready & state_is_idle);
assign ttio_i_longpipe = ttio_i_algnio;

assign ttio_o_valid = (state_is_io & ttio_i_valid & ttio_icb_cmd_ready)| (~ttio_i_ttiat & ~ttio_i_ttoat & ttio_i_valid & ttio_icb_cmd_ready);

assign ttio_o_wbck_wdat = ttio_i_getti ? timer : {`E203_XLEN{1'b0 }};
assign ttio_o_wbck_err = ttio_o_cmt_buserr | ttio_o_cmt_misalgn;

assign ttio_o_cmt_buserr  = 1'b0;
assign ttio_o_cmt_badaddr = ttio_icb_cmd_addr;
assign ttio_o_cmt_misalgn = ttio_i_unalgnio;
assign ttio_o_cmt_ld      = ttio_i_ttiat & (~ttio_i_excl); 
assign ttio_o_cmt_st      = ttio_i_ttoat | ttio_i_excl;

assign ttio_icb_rsp_ready = 1'b1;

assign ttio_icb_cmd_valid = (state_is_io & ttio_i_algnio & ttio_i_valid & ttio_o_ready);
assign ttio_icb_cmd_addr = ttio_i_rs1;
assign ttio_icb_cmd_read = (ttio_i_algnio & ttio_i_ttiat);

wire [`E203_XLEN-1:0] algnst_wdata = 
        ({`E203_XLEN{ttio_i_size_b }} & {4{ttio_i_rs2[7:0]}})
        | ({`E203_XLEN{ttio_i_size_hw}} & {2{ttio_i_rs2[15:0]}})
        | ({`E203_XLEN{ttio_i_size_w }} & {1{ttio_i_rs2[31:0]}});
wire [`E203_XLEN/8-1:0] algnst_wmask = 
        ({`E203_XLEN/8{ttio_i_size_b }} & (4'b0001 << ttio_icb_cmd_addr[1:0]))
        | ({`E203_XLEN/8{ttio_i_size_hw}} & (4'b0011 << {ttio_icb_cmd_addr[1],1'b0}))
        | ({`E203_XLEN/8{ttio_i_size_w }} & (4'b1111));

assign ttio_icb_cmd_wdata = algnst_wdata;
assign ttio_icb_cmd_wmask = algnst_wmask; 
assign ttio_icb_cmd_back2ttio = 1'b0;
assign ttio_icb_cmd_lock     = 1'b0;
assign ttio_icb_cmd_excl     = 1'b0;

assign ttio_icb_cmd_itag     = ttio_i_itag;
assign ttio_icb_cmd_usign    = ttio_i_usign;
assign ttio_icb_cmd_size     = ttio_i_size;

endmodule
