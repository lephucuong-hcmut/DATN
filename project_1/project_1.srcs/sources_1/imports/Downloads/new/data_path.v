`include "keccak_pkg.v"
`include "keccak_math.v"

module data_path (
    input wire clk,
    input wire rst,
    input wire computation_en,
    input wire [`ROUND_COUNT_WIDTH-1:0] round,
    input wire [`COUNTER_WIDTH-1:0] reads,
    input wire bof,
    input wire absorb_data,
    input wire [`PARALLEL_SLICES-1:0] din,
    input wire squeeze_output,
    input wire reset_ram,
    output reg [`WOUT-1:0] dout,
    input wire mux256  
);

    localparam WOUT_DIV_PARALLEL_SLICES = `WOUT / `PARALLEL_SLICES;
    localparam PARALLEL_SLICES_DIV_WOUT = `PARALLEL_SLICES / `WOUT;
    localparam DOUT_IDX_MAX = `MAX(WOUT_DIV_PARALLEL_SLICES, PARALLEL_SLICES_DIV_WOUT)-1;

    wire [`PARALLEL_SLICES-1:0] rcout;
    rc round_constants (
        .clk (clk),
        .round (round),
        .rcout (rcout)
    );

    wire [`DATAPATH_WIDTH - 1:0] dout_ram;
    wire [`DATAPATH_WIDTH - 1:0] rcin;
    wire [`DATAPATH_WIDTH - 1:0] transform_out;
    wire [4:0] transform_z0;

    transform transform_calc(
        .clk(clk),
        .rst(rst),
        .computation_en(computation_en),
        .round(round),
        .din(dout_ram),
        .rcin(rcin),
        .dout(transform_out),
        .dout_z0(transform_z0)
    );

    wire absorb;
    reg first_round;
    reg last_round;
    reg [24:0] we;
    reg [`DATAPATH_WIDTH - 1:0] din_ram;
    reg [4:0] din_z0;
    wire [31:0] raddr;

    state_ram state_ram_instance(
        .clk(clk),
        .rst(reset_ram | rst),
        .bof(bof),
        .absorb(absorb),
        .first_round(first_round),
        .last_round(last_round),
        .load_hash(squeeze_output),
        .computation_en(computation_en),
        .raddr(raddr),
        .dout(dout_ram),
        .we(we),
        .din(din_ram),
        .din_z0(din_z0)
    );

    assign raddr = (reads + 1'b1) & (`NUM_SUB_ROUNDS-1);

    wire [`CLOG2(DOUT_IDX_MAX+1)-1:0] dout_idx;
    wire [`CLOG2(25)-1:0] dout_ram_idx;
    reg [`WOUT - 1:0] dout_internal;
    wire [`CLOG2(`WIN/`PARALLEL_SLICES)-1:0] din_offset;

    assign dout_idx = reads & (DOUT_IDX_MAX);
    assign dout_ram_idx = reads >> `DIVCLOG2(`NUM_SUB_ROUNDS);

    integer i0;
    always @(*) begin
        for (i0=0; i0 <= `WOUT / 8 - 1; i0 = i0 + 1) begin
            dout[i0 * 8 + 7 -: 8] = dout_internal[i0 * 8 + 7 -: 8];
        end
    end

    always @(*) begin:hash_output
        if((WOUT_DIV_PARALLEL_SLICES >= PARALLEL_SLICES_DIV_WOUT)) begin
            dout_internal[dout_idx * `PARALLEL_SLICES + `PARALLEL_SLICES - 1 -: `PARALLEL_SLICES] = dout_ram[dout_ram_idx * `PARALLEL_SLICES + `PARALLEL_SLICES - 1 -: `PARALLEL_SLICES];
        end else begin
            dout_internal = dout_ram[dout_ram_idx * `PARALLEL_SLICES + dout_idx * `WOUT + `PARALLEL_SLICES - 1 -: `PARALLEL_SLICES];
        end
    end

    assign din_offset = 0;

    integer i_0;
    always @(*) begin:ram_input
        if((absorb_data == 1'b1)) begin
            din_ram = {`DATAPATH_WIDTH{1'b0}};
            if (mux256 == 1'b0) begin
                for (i_0 = 0; i_0 < `RATE_128/`NUM_SLICES; i_0 = i_0 + 1) begin
                    din_ram[(((i_0 * `PARALLEL_SLICES)) + `PARALLEL_SLICES - 1) -: `PARALLEL_SLICES] = din;
                end
            end else begin
                for (i_0 = 0; i_0 < `RATE_256/`NUM_SLICES; i_0 = i_0 + 1) begin
                    din_ram[(((i_0 * `PARALLEL_SLICES)) + `PARALLEL_SLICES - 1) -: `PARALLEL_SLICES] = din;
                end
            end
            din_z0 = {5{1'b0}};
            first_round = 1'b1;
            last_round = 1'b0;
        end else begin
            din_ram = transform_out;
            din_z0 = transform_z0;
            if(((round >> `DIVCLOG2(`NUM_SUB_ROUNDS)) == 0)) first_round = 1'b1;
            else first_round = 1'b0;
            if(((round >> `DIVCLOG2(`NUM_SUB_ROUNDS)) == `KECCAK_ROUNDS)) last_round = 1'b1;
            else last_round = 1'b0;
        end
    end

    integer i_1;
    always @(*) begin:write_enables
        if (mux256 == 1'b0) begin
            for (i_1 = 0; i_1 < `RATE_128/`NUM_SLICES; i_1 = i_1 + 1) begin
                if((absorb_data == 1'b1 && i_1 == (reads[(`COUNTER_WIDTH-1):`SUB_READS_COUNT_WIDTH] >> `DIVCLOG2((`NUM_SLICES / `WIN)) )) || computation_en == 1'b1) we[i_1] = 1'b1;
                else we[i_1] = 1'b0;
            end
            for (i_1=`RATE_128/`NUM_SLICES; i_1 <= 24; i_1 = i_1 + 1) begin
                if(((absorb_data == 1'b1 && bof == 1'b1) || computation_en == 1'b1)) we[i_1] = 1'b1;
                else we[i_1] = 1'b0;
            end
        end else begin
            for (i_1 = 0; i_1 < `RATE_256/`NUM_SLICES; i_1 = i_1 + 1) begin
                if((absorb_data == 1'b1 && i_1 == (reads[(`COUNTER_WIDTH-1):`SUB_READS_COUNT_WIDTH] >> `DIVCLOG2((`NUM_SLICES / `WIN)) )) || computation_en == 1'b1) we[i_1] = 1'b1;
                else we[i_1] = 1'b0;
            end
            for (i_1=`RATE_256/`NUM_SLICES; i_1 <= 24; i_1 = i_1 + 1) begin
                if(((absorb_data == 1'b1 && bof == 1'b1) || computation_en == 1'b1)) we[i_1] = 1'b1;
                else we[i_1] = 1'b0;
            end
        end
    end

    assign rcin[`DATAPATH_WIDTH - 1:`PARALLEL_SLICES] = {(`DATAPATH_WIDTH - `PARALLEL_SLICES){1'b0}};
    assign rcin[`PARALLEL_SLICES - 1:0] = rcout;
    assign absorb = absorb_data;

endmodule