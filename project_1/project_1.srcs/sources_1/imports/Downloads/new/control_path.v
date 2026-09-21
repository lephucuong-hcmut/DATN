`include "keccak_pkg.v"

module control_path (
    input wire clk, 
    input wire rst,
    input wire din_valid,
    output wire din_ready, 
    input wire [`WIN-1:0] din,
    output reg dout_valid,
    input wire dout_ready,
    output reg computation_en,
    output wire [`COUNTER_WIDTH-1:0] counter_fwd,
    output reg [`PARALLEL_SLICES-1:0] din_padded,
    output wire absorb_data_fwd,
    output reg squeeze_output,
    output wire bof,
    output reg reset_ram,
    output wire mux256,  
    input wire force_done  
);

    localparam s_command_header   = 4'b0000;
    localparam s_read_length      = 4'b0001;
    localparam s_absorb_data      = 4'b0011;
    localparam s_absorb_pad_block = 4'b0100;
    localparam s_process          = 4'b0101;
    localparam s_squeeze          = 4'b0110;
    localparam s_squeeze_extra    = 4'b0111;
    localparam s_prep_add_squeeze = 4'b0010;
    localparam s_stall_0          = 4'b1000;

    reg [3:0] current_state = 0, next_state = 0;
    reg [`COUNTER_WIDTH-1:0] counter = 0;
    reg [1:0] counter_ctrl = 0;
    reg din_ready_internal = 0, bof_internal = 0, bof_internal_reg = 0;
    reg eof_internal = 0, eof_internal_reg = 0;
    reg absorb_data = 0, extra_pad = 0, extra_pad_reg = 0;
    reg [`WIN-3:0] requested_bytes = 0, requested_bytes_reg = 0;
    reg [`RATE_WIDTH-1:0] data_length = 0, data_length_reg = 0;
    reg [`RATE_WIDTH-1:0] to_be_read = 0, to_be_read_reg = 0;
    reg [`RATE_WIDTH-1:0] to_be_absorbed = 0, to_be_absorbed_reg = 0;
    reg cshake = 0, cshake_reg = 0;
    reg [31:0] din_save = 0, din_save_reg = 0;
    reg [10:0] rate = 0, rate_reg = 0;
    reg [10:0] max_reads_count = 0, max_reads_count_reg = 0;
    reg mux256_internal = 0, mux256_reg = 0;
    reg [`COUNTER_WIDTH-1:0] start_addr = 0, start_addr_reg = 0;
    reg [`COUNTER_WIDTH-1:0] prev_start_addr = 0, prev_start_addr_reg = 0;
    reg from_process = 0;

    assign absorb_data_fwd = absorb_data;
    assign counter_fwd = counter;
    assign mux256 = mux256_internal;
    assign bof = bof_internal;
    assign din_ready = din_ready_internal;

    always @(posedge clk) begin
        if(rst == 1'b1) counter <= 0;
        else begin 
            if(counter_ctrl == 2'b11) counter <= counter + 1;
            else if(counter_ctrl == 2'b00) counter <= 0;
            else if(counter_ctrl == 2'b01) counter <= start_addr;
        end
    end

    always @(posedge clk) begin
        if ((din_valid == 1'b1) && (din_ready_internal == 1'b1)) din_save_reg <= din_save;
    end

    always @(posedge clk) begin
        if (rst) begin
            eof_internal_reg <= 0; bof_internal_reg <= 0; to_be_read_reg <= 0;
            to_be_absorbed_reg <= 0; data_length_reg <= 0; cshake_reg <= 0;
            extra_pad_reg <= 0; requested_bytes_reg <= 0; rate_reg <= 0;
            max_reads_count_reg <= 0; mux256_reg <= 0; start_addr_reg <= 0;
            prev_start_addr_reg <= 0;
        end else begin
            eof_internal_reg <= eof_internal; bof_internal_reg <= bof_internal;
            to_be_read_reg <= to_be_read; to_be_absorbed_reg <= to_be_absorbed;
            data_length_reg <= data_length; cshake_reg <= cshake;
            extra_pad_reg <= extra_pad; requested_bytes_reg <= requested_bytes;
            rate_reg <= rate; max_reads_count_reg <= max_reads_count;
            mux256_reg <= mux256_internal; start_addr_reg <= start_addr;
            prev_start_addr_reg <= prev_start_addr;
        end
    end

    always @(posedge clk) begin
        if (rst == 1'b1) current_state <= s_command_header;
        else current_state <= next_state;
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            s_command_header: 
                if(din_valid == 1'b1) next_state = s_read_length;
            s_read_length:
                if (force_done) next_state = s_command_header;
                else if(din_valid == 1'b1) next_state = s_absorb_data;
            s_absorb_data:
                if (force_done) next_state = s_command_header;
                else if((counter == max_reads_count_reg) && (to_be_read_reg <= `PARALLEL_SLICES) && (absorb_data == 1'b1)) next_state = s_process;
            s_absorb_pad_block:
                if (force_done) next_state = s_command_header;
                else if(counter == max_reads_count_reg) next_state = s_process;
            s_process:
                if (force_done) next_state = s_command_header;
                else if(counter == `MAX_ROUND_COUNT) begin
                    if(eof_internal_reg == 1'b0) next_state = s_read_length;
                    else if((eof_internal_reg == 1'b1) && (extra_pad_reg == 1'b1)) next_state = s_absorb_pad_block;
                    else next_state = s_squeeze;
                end
            s_squeeze:
                if(((requested_bytes_reg < `PARALLEL_SLICES) && (dout_ready == 1'b1)) || force_done) next_state = s_prep_add_squeeze;
                else if((requested_bytes_reg >= `PARALLEL_SLICES) && (counter == max_reads_count_reg) && (dout_ready == 1'b1)) next_state = s_process;
            s_prep_add_squeeze:
                if (force_done) next_state = s_command_header;
                else if (din_valid == 1'b1) next_state = s_stall_0;
            s_stall_0: 
                if (force_done) next_state = s_command_header;
                else next_state = s_squeeze_extra;
            s_squeeze_extra:
                if (force_done) next_state = s_command_header;
                else next_state = s_squeeze;
            default: next_state = s_command_header;
        endcase
    end

    reg din_ready_variable = 1'b0;
    reg absorb_data_variable = 1'b0;

    always @(*) begin
        reset_ram = 1'b0; from_process = 1'b0; din_ready_internal = 1'b0; dout_valid = 1'b0;
        cshake = cshake_reg; mux256_internal = mux256_reg; rate = rate_reg; max_reads_count = max_reads_count_reg;
        bof_internal = bof_internal_reg; eof_internal = eof_internal_reg; absorb_data = 1'b0;
        extra_pad = extra_pad_reg; computation_en = 1'b0; squeeze_output = 1'b0; counter_ctrl = 2'b00;
        requested_bytes = requested_bytes_reg; start_addr = start_addr_reg; prev_start_addr = prev_start_addr_reg;
        to_be_read = to_be_read_reg; to_be_absorbed = to_be_absorbed_reg; data_length = data_length_reg;
        din_padded = {`PARALLEL_SLICES{1'b0}}; din_save = din_save_reg;

        if (force_done) begin
            mux256_internal = 0; rate = 0; din_save = 0; to_be_absorbed = 0; max_reads_count = 0;
            din_ready_internal = 1'b0; dout_valid = 1'b0; cshake = 1'b0; bof_internal = 1'b0;
            eof_internal = 1'b0; absorb_data = 1'b0; extra_pad = 1'b0; computation_en = 1'b0;
            squeeze_output = 1'b0; counter_ctrl = 2'b00; requested_bytes = 0; to_be_read = 0;
            data_length = 0; din_padded = 0; start_addr = 0; prev_start_addr = 0;
        end else begin
            case(current_state)
                s_command_header: begin
                    din_ready_internal = 1'b1; cshake = din[`WIN-1]; mux256_internal = din[`WIN-2];  
                    if (din[`WIN-2] == 1'b0) begin rate = `RATE_128; max_reads_count = `MAX_READS_COUNT_128; end
                    else begin rate = `RATE_256; max_reads_count = `MAX_READS_COUNT_256; end
                    bof_internal = 1'b1; eof_internal = 1'b0; extra_pad = 1'b0;
                    requested_bytes = din[`WIN-3:0];
                    start_addr = ((((requested_bytes % `RATE_256)/ `WIN)) << 1);
                    to_be_read = 0; to_be_absorbed = 0; data_length = 0; reset_ram = 1'b1; prev_start_addr = 0;
                end
                s_read_length: begin
                    din_ready_internal = 1'b1; eof_internal = din[`WIN-1];
                    if((cshake_reg == 1'b0) && (din[`RATE_WIDTH-1:0] > (rate_reg-6))) extra_pad = 1'b1;
                    else if((cshake_reg == 1'b1) && (din[`RATE_WIDTH-1:0] > (rate_reg-4))) extra_pad = 1'b1;
                    else extra_pad = 1'b0;
                    to_be_read = din[`RATE_WIDTH-1:0]; to_be_absorbed = din[`RATE_WIDTH-1:0]; data_length = din[`RATE_WIDTH-1:0];
                end
                s_absorb_data: begin 
                    if((`SUB_READS_COUNT_WIDTH == 0) && (to_be_read_reg > 0 )) din_ready_variable = 1'b1;
                    else din_ready_variable = 1'b0;
                    din_ready_internal = din_ready_variable;
                    
                    if((din_valid == 1'b0) && (din_ready_variable == 1'b1)) absorb_data_variable = 1'b0;
                    else absorb_data_variable = 1'b1;
                    absorb_data = absorb_data_variable;

                    if((counter == max_reads_count_reg) && (to_be_read_reg <= `PARALLEL_SLICES) && (absorb_data == 1'b1)) counter_ctrl = 2'b00;
                    else if((counter == max_reads_count_reg) && (to_be_read_reg > `PARALLEL_SLICES)) counter_ctrl = 2'b10;
                    else if((din_valid == 1'b0) && (din_ready_variable == 1'b1)) counter_ctrl = 2'b10;
                    else counter_ctrl = 2'b11;

                    if(absorb_data_variable == 1'b1) begin
                        if(to_be_absorbed_reg > `PARALLEL_SLICES) to_be_absorbed = to_be_absorbed_reg - `PARALLEL_SLICES;
                        else to_be_absorbed = 0;
                    end else to_be_absorbed = to_be_absorbed_reg;

                    if(absorb_data_variable == 1'b1) begin
                        if(to_be_read_reg > `PARALLEL_SLICES) to_be_read = to_be_read_reg - `PARALLEL_SLICES;
                        else to_be_read = 0;
                    end else to_be_read = to_be_read_reg;

                    if((counter == max_reads_count_reg) && (absorb_data == 1'b1)) data_length = data_length_reg + (2048 - rate_reg);
                    else data_length = data_length_reg;

                    if((din_ready_variable == 1'b1) && (to_be_absorbed_reg > 0)) din_padded = din[((0+1)*`PARALLEL_SLICES-1)-:`PARALLEL_SLICES];
                    else if((din_ready_variable == 1'b0) && (to_be_absorbed_reg > 0)) din_padded = din_save_reg[((0+1)*`PARALLEL_SLICES-1)-:`PARALLEL_SLICES];

                    if((eof_internal_reg == 1'b1) && (to_be_absorbed_reg < `PARALLEL_SLICES) && (cshake_reg == 1'b1)) begin
                        if(counter == (data_length_reg>> `CLOG2(`PARALLEL_SLICES))) din_padded[data_length_reg & (`PARALLEL_SLICES-1)] = 1'b0;
                        if(counter == ((data_length_reg+1)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+1) & (`PARALLEL_SLICES-1)] = 1'b0;
                        if(counter == ((data_length_reg+2)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+2) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if((counter == ((rate_reg >> `CLOG2(`PARALLEL_SLICES)) - 1)) && (extra_pad_reg == 1'b0)) din_padded[`PARALLEL_SLICES-1] = 1'b1;
                    end else if((eof_internal_reg == 1'b1) && (to_be_absorbed_reg < `PARALLEL_SLICES) && (cshake_reg == 1'b0)) begin
                        if(counter == (data_length_reg>> `CLOG2(`PARALLEL_SLICES))) din_padded[data_length_reg & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((data_length_reg+1)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+1) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((data_length_reg+2)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+2) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((data_length_reg+3)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+3) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((data_length_reg+4)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+4) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if((counter == ((rate_reg >> `CLOG2(`PARALLEL_SLICES)) - 1)) && (extra_pad_reg == 1'b0)) din_padded[`PARALLEL_SLICES-1] = 1'b1;
                    end

                    if((din_ready_variable == 1'b1) && (din_valid == 1'b1)) din_save = din;
                    else din_save = din_save_reg;
                end
                s_absorb_pad_block: begin
                    bof_internal = 1'b0; eof_internal = 1'b1; absorb_data = 1'b1; extra_pad = 1'b0;
                    if(counter == max_reads_count_reg) counter_ctrl = 2'b00; else counter_ctrl = 2'b11;
                    
                    if(cshake_reg == 1'b1) begin
                        if(counter == (data_length_reg>> `CLOG2(`PARALLEL_SLICES))) din_padded[data_length_reg & (`PARALLEL_SLICES-1)] = 1'b0;
                        if(counter == ((data_length_reg+1)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+1) & (`PARALLEL_SLICES-1)] = 1'b0;
                        if(counter == ((data_length_reg+2)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+2) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((rate_reg >> `CLOG2(`PARALLEL_SLICES)) - 1)) din_padded[`PARALLEL_SLICES-1] = 1'b1;
                    end else begin
                        if(counter == (data_length_reg>> `CLOG2(`PARALLEL_SLICES))) din_padded[data_length_reg & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((data_length_reg+1)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+1) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((data_length_reg+2)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+2) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((data_length_reg+3)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+3) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((data_length_reg+4)>> `CLOG2(`PARALLEL_SLICES))) din_padded[(data_length_reg+4) & (`PARALLEL_SLICES-1)] = 1'b1;
                        if(counter == ((rate_reg >> `CLOG2(`PARALLEL_SLICES)) - 1)) din_padded[`PARALLEL_SLICES-1] = 1'b1;
                    end
                end
                s_process: begin
                    computation_en = 1'b1;
                    if(counter == `MAX_ROUND_COUNT) counter_ctrl = 2'b00; else counter_ctrl = 2'b11;
                    if((counter == `MAX_ROUND_COUNT) && (eof_internal_reg == 1'b1) && (extra_pad_reg == 1'b0)) requested_bytes = requested_bytes_reg - `PARALLEL_SLICES;
                    else requested_bytes = requested_bytes_reg;
                    from_process = 1'b1;
                end
                s_squeeze: begin
                    if((counter & (`NUM_SUB_READS_COUNT-1)) == (`NUM_SUB_READS_COUNT-1)) dout_valid = 1'b1;
                    if(((counter & (`NUM_SUB_READS_COUNT-1)) == (`NUM_SUB_READS_COUNT-1)) && (dout_ready != 1'b1)) begin
                        counter_ctrl = 2'b10;
                    end else if((counter == max_reads_count_reg) || (requested_bytes_reg < `PARALLEL_SLICES)) begin       
                        counter_ctrl = 2'b00; squeeze_output = 1'b1 & dout_valid;
                    end else begin
                        counter_ctrl = 2'b11; squeeze_output = 1'b1;
                        if(requested_bytes_reg >= `PARALLEL_SLICES) requested_bytes = requested_bytes_reg - `PARALLEL_SLICES;
                        else if(requested_bytes_reg < `PARALLEL_SLICES) requested_bytes = 0;
                    end
                end
                s_prep_add_squeeze: begin
                    din_ready_internal  = 1'b1; prev_start_addr = start_addr;
                    if (din_valid == 1'b1) begin requested_bytes = din[`WIN-3:0]; counter_ctrl = 2'b01; end 
                end
                s_stall_0: begin eof_internal = 1'b0; end
                s_squeeze_extra: begin
                    start_addr = (prev_start_addr + (((requested_bytes % `RATE_256)/ `WIN) << 1))%68 ;
                    counter_ctrl = 2'b11; squeeze_output = 1'b1; requested_bytes = requested_bytes_reg - `PARALLEL_SLICES;
                end
                default: begin end
            endcase
        end
    end
endmodule