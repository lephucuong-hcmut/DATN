`include "keccak_pkg.v"

module state_ram(
    input wire clk,
    input wire rst,
    input wire absorb,
    input wire bof,
    input wire first_round,
    input wire last_round,
    input wire load_hash,
    input wire computation_en,
    input wire [31:0] raddr,
    output reg [`DATAPATH_WIDTH-1:0] dout,
    input wire [24:0] we,
    input wire [`DATAPATH_WIDTH-1:0] din,
    input wire [4:0] din_z0
);
    localparam ADDR_W = `CLOG2(`MAX_SUB_ROUNDS + 1);

    reg [ADDR_W-1:0] raddr_precalc [0:`MAX_SUB_ROUNDS];
    reg [ADDR_W:0] addr_offsets_precalc [0:`MAX_SUB_ROUNDS];
    reg [`PARALLEL_SLICES-1 : 0] din_ram [0:24];
    reg [ADDR_W-1:0] raddr_high_offset;
    wire [`PARALLEL_SLICES-1 : 0] dout_ram [0:24];
    wire re;

    generate 
        genvar i;
        for (i=0; i <= 24; i = i + 1) begin: ram_generator
            stateram_inference #(.i(i)) ram (
                .clk(clk),
                .rst(rst),
                .re(re),
                .raddr (raddr_precalc[`RHO_ADDR_OFFSET(i)]),
                .d_in(din_ram[i]),
                .we(we[i]),
                .raddr_high_offset(raddr_high_offset),
                .d_out(dout_ram[i])
            );
        end
    endgenerate

    reg [`PARALLEL_SLICES-1 : 0] din_grouped [0:24];
    reg [`PARALLEL_SLICES-1 : 0] dout_internal [0:24];
    reg [24:0] z0, z0_reg, z0_half, z0_half_reg, z0_mux;

    assign re = load_hash | absorb | computation_en;

    generate
        genvar i0;
        for (i0=0; i0 <= `MAX_SUB_ROUNDS; i0 = i0 + 1) begin: generate_raddr_precalc
            always @(*) raddr_precalc[i0] = ((raddr[ADDR_W-1:0] + addr_offsets_precalc[i0]) & (`NUM_SUB_ROUNDS - 1));
        end
    endgenerate

    always @(posedge clk) begin
        if((rst == 1'b1)) raddr_high_offset <= 0;
        else if((raddr == `MAX_SUB_ROUNDS && computation_en == 1'b1 && last_round == 1'b0)) raddr_high_offset <= ((raddr_high_offset + 1'b1) & (`NUM_SUB_ROUNDS - 1));
    end

    generate
        genvar i1;
        for (i1=0; i1 <= `MAX_SUB_ROUNDS; i1 = i1 + 1) begin: generate_addr_offsets_precalc
            always @(posedge clk) begin
                if (rst) addr_offsets_precalc[i1] <= 0;
                else if((raddr == `MAX_SUB_ROUNDS && computation_en == 1'b1 && last_round == 1'b0)) addr_offsets_precalc[i1] <= ((addr_offsets_precalc[i1] - i1) & (`NUM_SUB_ROUNDS - 1));
            end
        end 
    endgenerate

    generate
        genvar ii1;
        for (ii1=0; ii1 <= 24; ii1 = ii1 + 1) begin: generate_z0_mux
            always @(posedge clk) begin
                if (rst) z0_mux[ii1] <= 1'b0;
                else if((load_hash == 1'b0 && re == 1'b1)) begin
                    if (raddr == `RHO_ADDR_OFFSET(ii1)) z0_mux[ii1] <= 1'b1;
                    else z0_mux[ii1] <= 1'b0;
                end else z0_mux[ii1] <= 1'b0;
            end
        end
    endgenerate

    generate
        if (`NUM_SUB_ROUNDS > 1) begin: temp_regs
            always @ (posedge clk) begin: registers
                if (rst == 1'b1) begin z0_reg <= 0; z0_half_reg <= 0; end
                else begin z0_half_reg <= z0_half; z0_reg <= z0; end
            end
        end
    endgenerate

    generate
        genvar i3;
        for (i3=0; i3 <= 24; i3 = i3 + 1) begin: generate_din_grouped
            always @(*) begin
                din_grouped[i3] = din[(i3 + 1) * `PARALLEL_SLICES - 1 -: `PARALLEL_SLICES];
                dout[(i3 + 1) * `PARALLEL_SLICES - 1 -: `PARALLEL_SLICES] = dout_internal[i3];
            end
        end
    endgenerate

    wire [`PARALLEL_SLICES-1 : 0] din_ram_wire_0 [0:24];
    wire [`PARALLEL_SLICES-1 : 0] din_ram_wire_1 [0:24];

    generate
        genvar ii4, j4;
        for (ii4=0; ii4 <= 24; ii4 = ii4 + 1) begin: generate_din_ram_wire_0
            if (`RHO_OFFSET(ii4) != 0) begin
                for (j4=1; j4 <=`PARALLEL_SLICES-1; j4 = j4 + 1) begin: generate_din_ram_wire_0_inner
                    if (j4 == `RHO_OFFSET(ii4)) assign din_ram_wire_0[ii4] = {din_grouped[ii4][j4 - 1:0], din_grouped[ii4][`PARALLEL_SLICES - 1:j4]}; 
                end
            end else assign din_ram_wire_0[ii4] = din_grouped[ii4];
            
            if (`RHO_OFFSET(ii4) != 0) begin
                for (j4=1; j4 <=`PARALLEL_SLICES-1; j4 = j4 + 1) begin: generate_din_ram_wire_1
                    if (j4 == `RHO_OFFSET(ii4)) assign din_ram_wire_1[ii4] = {(dout_internal[ii4][j4 - 1:0] ^ din_grouped[ii4][j4 - 1:0]), (dout_internal[ii4][`PARALLEL_SLICES - 1:j4] ^ din_grouped[ii4][`PARALLEL_SLICES - 1:j4])};
                end
            end else assign din_ram_wire_1[ii4] = dout_internal[ii4][`PARALLEL_SLICES - 1:0] ^ din_grouped[ii4][`PARALLEL_SLICES - 1:0];
        end
    endgenerate

    generate
        genvar i4;
        for (i4=0; i4 <= 24; i4 = i4 + 1) begin: generate_din_ram
            always @(*) begin:din_calc
                if((absorb == 1'b1 && bof == 1'b1)) begin
                    din_ram[i4] = din_ram_wire_0[i4];
                    z0[i4] = z0_reg[i4]; z0_half[i4] = z0_half_reg[i4];
                end else if((absorb == 1'b1 && bof == 1'b0)) begin
                    din_ram[i4] = din_ram_wire_1[i4];
                    z0[i4] = z0_reg[i4]; z0_half[i4] = z0_half_reg[i4];
                end else if((last_round == 1'b0)) begin
                    din_ram[i4] = din_grouped[`INVERSE_PI(i4)];
                    if((raddr == 1)) begin z0[i4] = z0_reg[i4]; z0_half[i4] = din_grouped[`INVERSE_PI(i4)][0]; end
                    else if((raddr == 0)) begin z0[i4] = z0_half_reg[i4] ^ din_z0[`MOD5(`INVERSE_PI(i4)+1)]; z0_half[i4] = z0_half_reg[i4]; end
                    else begin z0[i4] = z0_reg[i4]; z0_half[i4] = z0_half_reg[i4]; end
                end else begin
                    din_ram[i4] = din_ram_wire_0[i4]; z0[i4] = z0_reg[i4]; z0_half[i4] = z0_half_reg[i4];
                end
            end
        end
    endgenerate

    generate
        genvar i5;
        for (i5=0; i5 <= 24; i5 = i5 + 1) begin: generate_dout_internal
            always @(*) begin:dout_calc
                dout_internal[i5] = dout_ram[i5];
                if((first_round == 1'b0 && load_hash == 1'b0 && z0_mux[i5] == 1'b1 && `NUM_SUB_ROUNDS > 1)) dout_internal[i5][`RHO_OFFSET(i5)] = z0_reg[i5];
            end    
        end
    endgenerate
endmodule