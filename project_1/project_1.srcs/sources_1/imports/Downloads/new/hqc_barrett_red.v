`timescale 1ns / 1ps

(* use_dsp = "no" *)
module hqc_barrett_red #(    
    parameter N = 17_669,
    parameter M = 15                                              
)(
    input clk_i, 
    input [23:0] a_i, 
    output [M-1:0] c_o
);

reg     [15:0]  a_r;
wire    [25:0]      a3;
wire    [29:0]      a37;
wire    [32:0]      a475;
reg     [9:0]       t;
wire    [12:0]      t5;
wire    [24:0]      tN;
reg     [15:0]      c_temp;
wire    [16:0]      cN;
        
always @(posedge clk_i)
    a_r <= a_i[15:0];
        
assign a37 = {a_i, 5'd0} + {a_i, 2'd0} + a_i;
assign a475 = {a_i, 9'd0} - a37;
        
always @(posedge clk_i)
    t <= a475[32:23];
        
assign t5 = {t, 2'd0} + t;
        
assign  tN = {t, 14'd0} + {t5, 8'd0} + t5;

always @(posedge clk_i)
    c_temp <= a_r[15:0] - tN[15:0];
          
assign cN = c_temp[14:0] + N;
assign c_o = c_temp[15]? cN[14:0] : c_temp[14:0];

endmodule