`timescale 1ns / 1ps

module gfmul_00
(
    input start,
    input [7:0] in_1,
    input [7:0] in_2,
    output [7:0] out,
    output done
);
    function [7:0] mul;
        input [7:0] v_temp, in_1, in_2;
        input integer i;
        integer j;
        begin
            for (j=0; j < 8; j =j+1)
               mul[j] = v_temp[j] ^ (in_1[j] & in_2[8-i-1]);
        end
    endfunction

    function [7:0] v_temp_rearrange; 
        input [7:0] v_temp;
        reg dummy;
        begin
            dummy = v_temp[7];
            v_temp_rearrange[7] = v_temp[6];
            v_temp_rearrange[6] = v_temp[5];
            v_temp_rearrange[5] = v_temp[4];
            v_temp_rearrange[4] = v_temp[3] ^ dummy;
            v_temp_rearrange[3] = v_temp[2] ^ dummy;
            v_temp_rearrange[2] = v_temp[1] ^ dummy;
            v_temp_rearrange[1] = v_temp[0];
            v_temp_rearrange[0] = dummy;
        end
    endfunction
  
    reg [7:0] in_1_reg;    
    reg [7:0] in_2_reg;
       
    wire [7:0] v_temp_0, v_temp_1, v_temp_2, v_temp_3, v_temp_4, v_temp_5, v_temp_6, v_temp_7;
    wire [7:0] mul_0, mul_1, mul_2, mul_3, mul_4, mul_5, mul_6, mul_7;  

    reg [7:0] out_reg;
    reg done_reg_1 = 0;
    reg done_reg_2 = 0;

    always@(*) begin
        in_1_reg = in_1;
        in_2_reg = in_2;
        done_reg_1 = start;
    end

    assign v_temp_0 = v_temp_rearrange(0);
    assign mul_0 = mul(v_temp_0, in_1_reg, in_2_reg, 0); 

    assign v_temp_1 = v_temp_rearrange(mul_0);
    assign mul_1 = mul(v_temp_1, in_1_reg, in_2_reg, 1);

    assign v_temp_2 = v_temp_rearrange(mul_1);
    assign mul_2 = mul(v_temp_2, in_1_reg, in_2_reg, 2);

    assign v_temp_3 = v_temp_rearrange(mul_2);
    assign mul_3 = mul(v_temp_3, in_1_reg, in_2_reg, 3);

    assign v_temp_4 = v_temp_rearrange(mul_3);
    assign mul_4 = mul(v_temp_4, in_1_reg, in_2_reg, 4);

    assign v_temp_5 = v_temp_rearrange(mul_4);
    assign mul_5 = mul(v_temp_5, in_1_reg, in_2_reg, 5);

    assign v_temp_6 = v_temp_rearrange(mul_5);
    assign mul_6 = mul(v_temp_6, in_1_reg, in_2_reg, 6);

    assign v_temp_7 = v_temp_rearrange(mul_6);
    assign mul_7 = mul(v_temp_7, in_1_reg, in_2_reg, 7);

    always@(*) begin
        out_reg = mul_7;
        done_reg_2 = done_reg_1;
    end

    assign out = out_reg;
    assign done = done_reg_2; 
    
endmodule