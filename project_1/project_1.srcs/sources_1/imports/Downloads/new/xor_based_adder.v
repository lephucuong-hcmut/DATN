`timescale 1ns / 1ps

module xor_based_adder #(
    parameter N = 17_669,
    parameter M = 15, 
    parameter WEIGHT = 66,
    parameter WIDTH = 128,
    parameter N_MEM = N + (WIDTH - N%WIDTH)%WIDTH, 
    parameter DEPTH = N_MEM/WIDTH,
    parameter LOG_DEPTH = `CLOG2(DEPTH),    
    parameter LOG_WEIGHT = `CLOG2(WEIGHT)
)
(
    input clk,
    input rst,
    input [(WIDTH-1):0] in_1,
    input [(WIDTH-1):0] in_2,
    output reg [LOG_DEPTH-1:0] in_addr,
    output reg in_rd_en,
    input start,
    output reg [(WIDTH-1):0] add_out,
    output reg [LOG_DEPTH-1:0] add_out_addr,
    output reg add_out_valid,
    output reg done
);
    reg add_out_valid_reg;
    reg [LOG_DEPTH-1:0] add_out_addr_reg;
    reg done_reg;

    localparam s_wait_start = 0;
    localparam s_load_loc   = 1;
    localparam s_stall      = 2;

    reg [3:0] state = 0;

    always@(posedge clk) begin  
        add_out <= in_1 ^ in_2; 
        add_out_addr <= add_out_addr_reg;
        add_out_valid <= add_out_valid_reg;
        done <= done_reg;
    end

    always@(posedge clk) begin
        add_out_addr_reg <= in_addr;
    end

    always@(posedge clk) begin
        if (rst) begin
            state <= s_wait_start;
            in_addr <= 0;
            done_reg <= 0;
            add_out_valid_reg <= 1'b0;
        end else begin
             if (state == s_wait_start) begin
                in_addr <= 0;
                done_reg <= 0;
                add_out_valid_reg <= 1'b0;
                if (start) begin 
                    state <=  s_load_loc;
                end
             end else if (state == s_load_loc) begin
                done_reg <= 0;
                add_out_valid_reg <= 1'b1;
                if (in_addr == DEPTH-1) begin
                    state <= s_stall;
                end else begin
                    in_addr <= in_addr + 1;
                    state <= s_load_loc;
                end  
             end else if (state == s_stall) begin
                state <=  s_wait_start;
                done_reg <= 1;
                add_out_valid_reg <= 1'b0;
             end
        end
    end 

    always@(*) begin
        case (state)
            s_wait_start: begin
                if (start) begin
                    in_rd_en = 1'b1;
                end else begin
                    in_rd_en = 1'b0;
                end
            end  
            s_load_loc: begin
                in_rd_en = 1'b1;
            end 
            s_stall: begin
                in_rd_en = 1'b1;
            end
            default: begin
                in_rd_en = 1'b0;
            end
        endcase
    end     
endmodule