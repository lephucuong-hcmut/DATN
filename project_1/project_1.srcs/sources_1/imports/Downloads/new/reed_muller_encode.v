`timescale 1ns / 1ps

module reed_muller_encode #( 
    parameter N1_BYTES = 46,
    parameter K_BYTES = 16,
    parameter LOG_N1_BYTES = `CLOG2(N1_BYTES),
    parameter N1 = 8*N1_BYTES,
    parameter K = 8*K_BYTES
)
(
    input clk,
    input rst,
    input start,
    input [N1-1:0] rs_cdw_in,
    input cdw_out_en,
    input [LOG_N1_BYTES-1:0] cdw_out_addr,
    output [127:0] cdw_out,
    output reg done
);
    reg [N1-1:0] cdw_in;
    wire [7:0] gate_value;
    reg [N1-1:0] cdw_bytes;
    wire [N1-K-1:0] cdw_out_int;

    reg init;
    reg shift_cdw;
    reg wr_en;

    always@(posedge clk) begin
        if (init) begin
            cdw_in <= rs_cdw_in;
        end else if (shift_cdw) begin
            cdw_in <= {cdw_in[7:0],cdw_in[N1-1:8]};
        end
    end

    wire [127:0] encoder_out;
    wire [LOG_N1_BYTES-1:0] addr;

    rm_encoder ENCODER (
        .byte_in(cdw_in[7:0]),
        .cdw_out(encoder_out)
    );

    reg [LOG_N1_BYTES-1:0] count_cdw_bytes = 0;
    assign addr = (cdw_out_en)? cdw_out_addr : count_cdw_bytes;

    mem_single #(.WIDTH(128), .DEPTH(N1_BYTES)) CODEWORD (
        .clock(clk),
        .data(encoder_out),
        .address(addr),
        .wr_en(wr_en),
        .q(cdw_out)
    );

    reg [3:0] state = 0;
    localparam s_wait_start = 0;
    localparam s_encode     = 1;
    localparam s_done       = 3;

    always@(posedge clk) begin
        if (rst) begin
            state <= s_wait_start;
            count_cdw_bytes <= 0;
            done <= 0;
        end else begin
            if (state == s_wait_start) begin
               done <= 0;
               if (start) begin
                   state <= s_encode;
                   count_cdw_bytes <= 0;
               end   
            end else if (state == s_encode) begin
                done <= 0;
                if (count_cdw_bytes == N1_BYTES) begin
                    state <= s_done;
                end else begin 
                    state <= s_encode;
                    count_cdw_bytes <= count_cdw_bytes+1;
                end
            end else if (state == s_done) begin
                state <= s_wait_start;
                done <= 1;
                count_cdw_bytes <= 0;
            end
        end  
    end

    always@(*) begin
        case (state)
            s_wait_start:begin
                if (start) begin
                    init = 1;
                    shift_cdw = 0;
                    wr_en = 0;
                end else begin
                    init = 0;
                    shift_cdw = 0;
                    wr_en = 0;
                end
            end
            s_encode:begin
               wr_en = 1;
               shift_cdw = 1;
               init = 0;
            end
            s_done:begin
               shift_cdw = 0;
               init = 0;
               wr_en = 0;
            end
            default: begin
               shift_cdw = 0;
               init = 0;
               wr_en = 0;
            end
        endcase
    end 
endmodule