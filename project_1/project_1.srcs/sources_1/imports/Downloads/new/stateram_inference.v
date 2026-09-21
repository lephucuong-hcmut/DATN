`include "keccak_pkg.v"

module stateram_inference #(
    parameter i = 0
)(
    input wire clk,
    input wire rst,
    input wire re,
    input wire [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0] raddr,
    input wire [`PARALLEL_SLICES-1:0] d_in,
    input wire we,
    input wire [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0] raddr_high_offset,
    output wire [`PARALLEL_SLICES-1:0] d_out    
);
    reg [`RHO_OFFSET(i)-1:0] ram_high [`MAX_SUB_ROUNDS:0];
    wire [`RHO_OFFSET(i)-1:0] din_high;
    wire [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0] waddr_high;
    reg [`PARALLEL_SLICES-1-`RHO_OFFSET(i):0] ram_low [`MAX_SUB_ROUNDS:0];
    wire [`PARALLEL_SLICES-1-`RHO_OFFSET(i):0] din_low;
    wire [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0] waddr_low;
    reg [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0] raddr_high_reg;
    reg [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0] raddr_low_reg;
    wire [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0] raddr_high_reg_temp;

    assign raddr_high_reg_temp = raddr - raddr_high_offset;

    generate
        if (`RHO_OFFSET(i) > 0) begin
            assign waddr_high = raddr_high_reg;
            assign din_high = d_in[(`PARALLEL_SLICES-1)-:`RHO_OFFSET(i)];
            assign d_out[`RHO_OFFSET(i)-1:0] = ram_high[raddr_high_reg];

            always @ (posedge clk) begin: ram_high_proc
                if (rst == 1'b1) raddr_high_reg <= 0;
                else begin
                    if (re == 1'b1) raddr_high_reg <= raddr_high_reg_temp[`CLOG2(`MAX_SUB_ROUNDS+1)-1:0];
                    if (we == 1'b1) ram_high[waddr_high] <= din_high;
                end
            end
        end
    endgenerate
    
    assign waddr_low = raddr_low_reg;
    assign din_low = d_in[`PARALLEL_SLICES-`RHO_OFFSET(i)-1:0];
    assign d_out[`PARALLEL_SLICES-1:`RHO_OFFSET(i)] = ram_low[raddr_low_reg];
       
    always @(posedge clk) begin: ram_low_proc
        if(rst == 1'b1) raddr_low_reg <= 0;
        else begin
            if(re == 1'b1) raddr_low_reg <= raddr[`CLOG2(`MAX_SUB_ROUNDS+1)-1:0];
            if(we == 1'b1) ram_low[waddr_low] <= din_low;
        end
    end       
endmodule