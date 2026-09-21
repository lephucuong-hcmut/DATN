module transform(
    input wire clk,
    input wire rst,
    input wire computation_en,
    input wire [`ROUND_COUNT_WIDTH-1:0] round,
    input wire [`DATAPATH_WIDTH-1:0] din,
    input wire [`DATAPATH_WIDTH-1:0] rcin,
    output reg [`DATAPATH_WIDTH -1:0] dout,
    output reg [4:0] dout_z0
);
    reg [`DATAPATH_WIDTH - 1:0] chi_iota_out;  
    reg [4:0] carry, carry_reg;  
    reg [2:0] x_plus_1, x_plus_2;
    integer x, y;

    always @(*) begin : step_0
        if((round >> `CLOG2(`NUM_SUB_ROUNDS)) != 0 ) begin
            for (x=0; x <= 4; x = x + 1) begin
                for (y=0; y <= 4; y = y + 1) begin
                    if((x == 4)) x_plus_1 = 0; else x_plus_1 = x + 1;
                    if((x_plus_1 == 4)) x_plus_2 = 0; else x_plus_2 = x_plus_1 + 1;
                    
                    chi_iota_out[(x + 1 + y * 5) * `PARALLEL_SLICES - 1 -: `PARALLEL_SLICES] 
                    = din[(x + 1 + y * 5) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] 
                    ^ ( ((( ~din[((x_plus_1 + 1 + y * 5)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES])) 
                        & din[((x_plus_2 + 1 + y * 5)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES]) ) 
                    ^ rcin[((x + 1 + y * 5)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES];
                end
            end
        end else begin
            chi_iota_out = din;
        end
    end

    always @(posedge clk) begin
        if((rst == 1'b1)) carry_reg <= 0;
        else if((computation_en == 1'b 1)) carry_reg <= carry;
    end

    reg [5 * `PARALLEL_SLICES - 1:0] sum_x_z;
    reg [2:0] x0_plus_1, x0_plus_2;
    integer x0, y0;

    always @(*) begin : step_1
        if( (round >> `CLOG2(`NUM_SUB_ROUNDS)) == `KECCAK_ROUNDS) begin
            dout = chi_iota_out; dout_z0 = 0; carry = 0;
        end else begin
            sum_x_z = {5 * `PARALLEL_SLICES{1'b0}};
            for (x0=0; x0 <= 4; x0 = x0 + 1) begin
                for (y0=0; y0 <= 4; y0 = y0 + 1) begin
                    sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] = sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] ^ chi_iota_out[(x0 + 1 + 5 * y0) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES];
                end
            end
            if((round & (`NUM_SUB_ROUNDS-1)) == `MAX_SUB_ROUNDS) begin
                carry = 0;
                dout_z0 = {sum_x_z[5 * `PARALLEL_SLICES - 1], sum_x_z[4 * `PARALLEL_SLICES - 1], sum_x_z[3 * `PARALLEL_SLICES - 1], sum_x_z[2 * `PARALLEL_SLICES - 1], sum_x_z[1 * `PARALLEL_SLICES - 1]};
            end else begin
                carry = {sum_x_z[5 * `PARALLEL_SLICES - 1], sum_x_z[4 * `PARALLEL_SLICES - 1], sum_x_z[3 * `PARALLEL_SLICES - 1], sum_x_z[2 * `PARALLEL_SLICES - 1], sum_x_z[1 * `PARALLEL_SLICES - 1]};
                dout_z0 = 0;
            end
            for (x0=0; x0 <= 4; x0 = x0 + 1) begin
                for (y0=0; y0 <= 4; y0 = y0 + 1) begin
                    if((x0 == 4)) x0_plus_1 = 0; else x0_plus_1 = x0 + 1;
                    if((x0_plus_1 == 4)) x0_plus_2 = 0; else x0_plus_2 = x0_plus_1 + 1;
                    
                    dout[(x0_plus_1 + 1 + 5 * y0) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES-1] 
                    = sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES -1] 
                    ^ sum_x_z[((x0_plus_2 + 1)) * `PARALLEL_SLICES - 2 -:`PARALLEL_SLICES-1] 
                    ^ chi_iota_out[((x0_plus_1 + 1 + 5 * y0)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES-1];

                    if((`NUM_SUB_ROUNDS > 1)) begin
                        dout[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES] = sum_x_z[x0 * `PARALLEL_SLICES] ^ carry_reg[x0_plus_2] ^ chi_iota_out[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES];
                    end else begin
                        dout[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES] = sum_x_z[((x0)) * `PARALLEL_SLICES] ^ sum_x_z[((x0_plus_2 + 1)) * `PARALLEL_SLICES - 1] ^ chi_iota_out[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES];
                    end
                end
            end
        end
    end
endmodule