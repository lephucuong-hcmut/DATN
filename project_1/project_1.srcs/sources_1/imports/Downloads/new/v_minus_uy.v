`timescale 1ns / 1ps

module v_minus_uy #( 
    parameter N1_BYTES = 46,
    parameter MAX_WEIGHT = 75,
    parameter N = 17_669,
    parameter M = 15,
    parameter N1 = 8*N1_BYTES,
    parameter LOG_MAX_WEIGHT = `CLOG2(MAX_WEIGHT),
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
	
    output reg done,
    output [LOG_WEIGHT-1:0] y_addr,
    input [M-1:0] y,
	
    input [RAMWIDTH-1:0] uv_0,
    input [RAMWIDTH-1:0] uv_1,	
    output [`CLOG2(X)-1:0] uv_addr_0,
    output [`CLOG2(X)-1:0] uv_addr_1,
    output reg sel_uv, 
	
    input out_en,
    input [`CLOG2(RAMDEPTH)-1:0] out_addr,
    output [RAMWIDTH-1:0] u_minus_vy_out,
	
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

    wire [`CLOG2(X)-1:0] uv_addr_0_mul;  
    wire [RAMWIDTH-1:0] uv_in_0;
    wire [RAMWIDTH-1:0] uv_in_1;
    wire [RAMWIDTH-1:0] pm_out;
    reg start_poly_mult;
    wire done_poly_mult;

    wire [LOG_RAMDEPTH-1:0] xor_add_addr;
    wire xor_add_en;
    wire [RAMWIDTH-1:0]  xor_add_out;
    wire [LOG_RAMDEPTH-1:0] xor_add_out_addr;
    wire xor_add_out_valid;

    assign u_minus_vy_out = pm_out;
    assign uv_addr_0 = (sel_uv)? xor_add_addr: uv_addr_0_mul;

    reg  [`CLOG2(X)-1:0] uv_addr_0_mul_reg;
    reg  [`CLOG2(X)-1:0] uv_addr_1_reg;
    always@(posedge clk) begin
        uv_addr_0_mul_reg <= uv_addr_0_mul;
        uv_addr_1_reg <= uv_addr_1; 
    end

    assign uv_in_0 = (uv_addr_0_mul_reg> (X + X%2)/2 - 1)? 0: uv_0;
    assign uv_in_1 = (uv_addr_1_reg> (X + X%2)/2 - 1)? 0: uv_1;

    assign pm_start      = start_poly_mult;
    assign pm_loc_in     = y;
    assign pm_weight     = WEIGHT;
    assign pm_mux_word_0 = uv_in_0;
    assign pm_mux_word_1 = uv_in_1;
    assign pm_rd_dout    = out_en? 1'b1 :xor_add_en;
    assign pm_addr_result= out_en? out_addr : xor_add_addr;
    assign pm_add_wr_en  = xor_add_out_valid;
    assign pm_add_addr   = xor_add_out_addr;
    assign pm_add_in     = xor_add_out;
    assign y_addr = pm_loc_addr;
    assign uv_addr_0_mul = pm_addr_0;
    assign uv_addr_1 = pm_addr_1;
    assign done_poly_mult = pm_valid;
    assign pm_out = pm_dout;

    wire [`CLOG2(N_MEM/MEM_WIDTH) - 1:0] pm_rd_addr;
    wire pm_rd_en;
    wire [MEM_WIDTH-1:0] add_out;
    wire [`CLOG2(N_MEM/MEM_WIDTH) - 1:0] add_out_addr;
    wire add_out_valid;
 
    reg start_adder;
    wire done_adder;
    wire [RAMWIDTH-1:0] add_in_1;
    wire [RAMWIDTH-1:0] add_in_2;
  
    assign add_in_1 = pm_out;
    assign add_in_2 = uv_0;

    xor_based_adder #(.N(N) , .WIDTH(RAMWIDTH)) XOR_BASED_ADDER (
        .clk(clk),
        .rst(rst),
        .start(start_adder),
        .in_1(add_in_1),
        .in_2(add_in_2),
        .in_addr(xor_add_addr),
        .in_rd_en(xor_add_en),
        .add_out(xor_add_out),
        .add_out_addr(xor_add_out_addr),
        .add_out_valid(xor_add_out_valid),
        .done(done_adder)
    );

    reg [3:0] state = 0;
    localparam s_wait_start  = 0;
    localparam s_u_mul_y     = 1;
    localparam s_v_minus_uy  = 2;
    localparam s_done        = 3;

    always@(posedge clk) begin
        if (rst) begin
            state <= s_wait_start;
            sel_uv <= 0;
            done <= 1'b0;
        end else begin
            if (state == s_wait_start) begin
                sel_uv <= 0;
                done <= 1'b0;
                if (start) begin
                    state <= s_u_mul_y;
                end
            end else if (state == s_u_mul_y) begin
                done <= 1'b0;
                if (done_poly_mult) begin
                    state <= s_v_minus_uy;
                    sel_uv <= 1;
                end else begin
                    sel_uv <= 0;
                end
            end else if (state == s_v_minus_uy) begin
                sel_uv <= 1;
                done <= 1'b0;
                if (done_adder) begin
                    state <= s_done;
                end
            end else if (state == s_done) begin
                state <= s_wait_start;
                sel_uv <= 0;
                done <= 1'b1;
            end
        end 
    end

    always@(*) begin
        case (state)
            s_wait_start: begin
                start_adder = 0;
                if (start) begin
                    start_poly_mult = 1;
                end else begin
                    start_poly_mult = 0;
                end
            end
            s_u_mul_y: begin
                start_poly_mult = 0;
                if (done_poly_mult) begin
                    start_adder = 1;
                end else begin
                    start_adder = 0;
                end
            end
            s_v_minus_uy: begin
                start_poly_mult = 0;
                start_adder = 0;
            end 
            s_done: begin
                start_poly_mult = 0;
                start_adder = 0;
            end 
            default: begin
                start_poly_mult = 0;
                start_adder = 0;
            end         
        endcase
    end 
endmodule