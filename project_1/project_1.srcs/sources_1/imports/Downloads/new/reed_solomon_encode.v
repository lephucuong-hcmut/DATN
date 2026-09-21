`timescale 1ns / 1ps

module reed_solomon_encode #( 
    parameter N1_BYTES = 46,
    parameter K_BYTES = 16,
    parameter N1 = 8*N1_BYTES,
    parameter K = 8*K_BYTES,
    parameter G_x_WIDTH = 256,    
    parameter G_x = 256'h0001B5FF_52E4454A_6EAED269_7643AD67_8B15D241_E9F2E949_4B6F75B0_74994559  
)
(
    input clk,
    input rst,
    input start,
    input [K-1:0] msg_in,
    output [N1-1:0] cdw_out,
    output reg done
);
    reg [K-1:0] msg;
    wire [7:0] gate_value;
    reg [N1-K-1:0] cdw_bytes;
    wire [N1-K-1:0] cdw_out_int;
    reg capture_cdw;
    reg init_msg;
    reg shift_msg;

    assign cdw_out = {msg,cdw_bytes};

    always@(posedge clk) begin
        if (init_msg) begin
            msg <= msg_in;
        end else if (shift_msg) begin
            msg <= {msg[K-8-1:0],msg[K-1:K-8]};
        end
    end

    always@(posedge clk) begin
        if (init_msg) begin
            cdw_bytes <= 0;
        end else if (capture_cdw) begin
            cdw_bytes <= cdw_out_int;
        end
    end

    assign gate_value = msg[K-1:K-8] ^ cdw_bytes[N1-K-1:N1-K-8];

    wire done_gf_mul;
    wire [G_x_WIDTH*8-1:0] gf_mul_out;
    genvar i;
    generate 
        for (i=G_x_WIDTH/8; i>0; i =i-1) begin:GF_MUL_SERIES
          gf_mul GFMUL (
            .clk(clk),
            .start(1'b1),
            .in_1(gate_value),
            .in_2(G_x[8*i-1:8*i-8]),
            .out(gf_mul_out[8*i-1:8*i-8]),
            .done(done_gf_mul)
          );
        end
    endgenerate 
     
    cdw_xor_tmp CDWXORTMP (
        .cdw_in(cdw_bytes[N1-K-8-1:0]),
        .tmp_arr(gf_mul_out[N1-K-1:0]),
        .cdw_out(cdw_out_int)
    );

    reg [4:0] count_msg_bytes = 0;
    reg [3:0] state = 0;
    localparam s_wait_start   = 0;
    localparam s_gf_mult      = 1;
    localparam s_mult_done    = 2;
    localparam s_update_count = 3;

    always@(posedge clk) begin
         if (rst) begin
            state <= s_wait_start;
            count_msg_bytes <= 0;
            done <= 0;
        end else begin
            if (state == s_wait_start) begin
                done <= 0;
                if (start) begin
                    count_msg_bytes <= 0;
                    state <= s_gf_mult;
                end
            end else if (state == s_gf_mult) begin
                  state <= s_mult_done;
                  done <= 0;
            end else if (state == s_mult_done) begin
                  state <= s_update_count;
                  done <= 0;
            end else if (state == s_update_count) begin
                  if (count_msg_bytes == K_BYTES-1) begin
                        state <= s_wait_start;
                        count_msg_bytes <= 0;
                        done <= 1;
                  end else begin
                       state <= s_gf_mult;
                       count_msg_bytes <= count_msg_bytes + 1;
                       done <= 0;
                  end
            end
        end 
    end

    always@(*) begin
        case (state)
         s_wait_start: begin
            shift_msg = 0;
            capture_cdw = 0;
            if (start) begin
                init_msg = 1;
            end else begin
                init_msg = 0;
            end
         end
         s_gf_mult: begin
                init_msg = 0;
                shift_msg = 0; 
                capture_cdw = 0;
         end
         s_mult_done: begin
                init_msg = 0;
                shift_msg = 0;
                capture_cdw = 0; 
         end
         s_update_count: begin
                init_msg = 0;
                shift_msg = 1;
                capture_cdw = 1;
         end
         default: begin
               init_msg = 0;
               shift_msg = 0;
               capture_cdw = 0;
         end         
        endcase
    end 
endmodule