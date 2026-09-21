`timescale 1ns / 1ps

module cdw_xor_tmp #( 
    parameter N1_BYTES = 46,
    parameter K_BYTES = 16,
    parameter N1 = 8 * N1_BYTES,
    parameter K = 8 * K_BYTES
)
(
    input [N1-K-8-1:0] cdw_in,
    input [N1-K-1:0] tmp_arr,
    output [N1-K-1:0] cdw_out
);

    genvar i;
    generate
        for (i = N1_BYTES - K_BYTES; i > 1; i = i - 1) begin : cdw_xor_tmparr
            assign cdw_out[8*i-1 : 8*i-8] = cdw_in[8*(i-1)-1 : 8*(i-1)-8] ^ tmp_arr[8*i-1 : 8*i-8];
        end
    endgenerate
    
    assign cdw_out[7:0] = tmp_arr[7:0];
    
endmodule