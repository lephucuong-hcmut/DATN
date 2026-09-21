`timescale 1ns / 1ps
(* use_dsp = "no" *)
module mod34 ( 
    input [11:0] a_i, 
    output [5:0] c_o
);
    wire [18:0] a121;
    wire [6:0] t;
    wire [12:0] tN;
    wire [13:0] c_temp;
    wire [5:0] cN;
    
    assign a121 = {a_i, 7'd0} - {a_i, 3'd0} + a_i;
    assign t = a121[18:12];
    assign tN = {t, 5'd0} + {t, 1'd0};
    assign c_temp = a_i - tN;
    assign cN = c_temp[5:0] + 34;
    assign c_o = c_temp[13] ? cN[5:0] : c_temp[5:0];
endmodule