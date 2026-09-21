`timescale 1ns / 1ps

module decrypt #( 
    parameter N1_BYTES = 46,
    parameter K_BYTES = 16,
    parameter WEIGHT_ENC = 75,
    parameter N = 17_669,
    parameter N1N2 = 17_664,
    parameter M = 15,
    parameter N1 = 8*N1_BYTES,
    parameter K = 8*K_BYTES,
    parameter LOG_WEIGHT_ENC = `CLOG2(WEIGHT_ENC),
    parameter LOG_N1_BYTES = `CLOG2(N1_BYTES),
    parameter WEIGHT = 66,
    parameter LOG_WEIGHT = `CLOG2(WEIGHT),

    parameter RAMWIDTH = 128,
    parameter TWO_N = 2*N,
    parameter W_RAMWIDTH = TWO_N + (RAMWIDTH-TWO_N%RAMWIDTH)%RAMWIDTH, 
    parameter W = W_RAMWIDTH + RAMWIDTH*((W_RAMWIDTH/RAMWIDTH)%2),
    parameter X = W/RAMWIDTH,
    parameter LOGX = `CLOG2(X), 
    parameter Y = X/2,
    parameter LOGW = `CLOG2(W),
    parameter W_BY_X = W/X, 
    parameter W_BY_Y = W/Y, 
    parameter RAMSIZE = X,
    parameter ADDR_WIDTH = `CLOG2(RAMSIZE),
    parameter LOG_MAX_WEIGHT = `CLOG2(WEIGHT_ENC),
    
    parameter MEM_WIDTH = RAMWIDTH,	
    parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, 
    parameter N_B = N + (8-N%8)%8, 
    parameter N_Bd = N_B - N, 
    parameter N_MEMd = N_MEM - N_B, 
	 
    parameter RAMDEPTH = (N+(RAMWIDTH-N%RAMWIDTH)%RAMWIDTH)/RAMWIDTH, 
    parameter LOG_RAMDEPTH = `CLOG2(RAMDEPTH)
)
(
    input clk,
    input rst,
    input start,
	
    output [LOG_WEIGHT-1:0] y_addr,
    input [M-1:0] y,
	
    input [RAMWIDTH-1:0] uv_0,
    input [RAMWIDTH-1:0] uv_1,	
    output [`CLOG2(X)-1:0] uv_addr_0,
    output [`CLOG2(X)-1:0] uv_addr_1,
    output sel_uv, 
	    
    output done,
    output [K-1:0] dout,
	
    output pm_start,    
    output [M-1:0] pm_loc_in,
    output [LOG_MAX_WEIGHT:0] pm_weight,
    output [W_BY_X-1:0]pm_mux_word_0,
    output [W_BY_X-1:0]pm_mux_word_1,
    output pm_rd_dout,
    output [`CLOG2(RAMSIZE/2)-1:0]pm_addr_result,
    output pm_add_wr_en,
    output [`CLOG2(RAMSIZE/2)-1:0] pm_add_addr,
    output [RAMWIDTH-1:0] pm_add_in,
	
    input [LOG_WEIGHT-1:0] pm_loc_addr,
    input [W_BY_X-1:0]pm_dout,
    input pm_valid,
    input  [ADDR_WIDTH-1:0]pm_addr_0,
    input  [ADDR_WIDTH-1:0]pm_addr_1
);
    wire ram_din_rd_o;
    wire [127:0] ram_din_i;
    wire [LOG_RAMDEPTH-1:0] ram_din_addr_o;
    wire done_u_minus_vy;

    v_minus_uy V_MINUS_UY ( 
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done_u_minus_vy),
        .y_addr(y_addr),
        .y(y),
        .uv_0(uv_0),
        .uv_1(uv_1),
        .uv_addr_0(uv_addr_0),
        .uv_addr_1(uv_addr_1),
        .sel_uv(sel_uv),
        .out_en(ram_din_rd_o),
        .out_addr(ram_din_addr_o),
        .u_minus_vy_out(ram_din_i),
        .pm_start(pm_start),    
        .pm_loc_in(pm_loc_in),
        .pm_weight(pm_weight),
        .pm_mux_word_0(pm_mux_word_0),
        .pm_mux_word_1(pm_mux_word_1),
        .pm_rd_dout(pm_rd_dout),
        .pm_addr_result(pm_addr_result),
        .pm_add_wr_en(pm_add_wr_en),
        .pm_add_addr(pm_add_addr),
        .pm_add_in(pm_add_in),
        .pm_loc_addr(pm_loc_addr),
        .pm_addr_0(pm_addr_0),
        .pm_addr_1(pm_addr_1),
        .pm_valid(pm_valid),
        .pm_dout(pm_dout)	
    );

    hqc_decod_top #(.PARAM_SECURITY(K)) DECODE (
        .clk_i(clk),
        .rst_ni(~rst),
        .start_i(done_u_minus_vy),
        .busy_o(),
        .ram_din_i(ram_din_i),
        .ram_din_rd_o(ram_din_rd_o),
        .ram_din_addr_o(ram_din_addr_o),
        .dout_o(dout),      
        .dout_valid_o(done)
    );
endmodule