`timescale 1ns / 1ps

module fft_leaves_butterfly #(
    parameter DIN_W          = 8,
    parameter DOUT_W         = 8
)(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    output                  busy_o,

    input   [DIN_W-1:0]     a0_i,
    input   [DIN_W-1:0]     a1_i,
    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o
);
    reg     [7:0]           dout;
    reg     [31:0]          tmp;
    wire    [7:0]           t0, t01, t012, t0123, tmp_out;
    wire    [7:0]           gf_in, gf_out;
    reg     [3:0]           cnt;
    reg                     init_state, compute_state;
    reg                     busy;

    always @(posedge clk_i) begin
        if(start_i)
            tmp <= 32'h0;
        else if(init_state)
            tmp <= {tmp[23:0], gf_out ^ tmp[7:0]};
    end

    assign {t0, t01, t012, t0123} = tmp;
    
    assign tmp_out = (cnt==7)? t0123 :
                     (cnt==3 | cnt==11)? t012 :
                     (cnt==1 | cnt==5 | cnt==9 | cnt==13)? t01 : t0;

    always @(posedge clk_i) begin
        if(start_i | init_state)
            dout <= a0_i;
        else if(compute_state & cnt!=15)
            dout <= dout ^ tmp_out;
    end

    assign dout_o = dout;

    gfmul_00 DD_MUL(
        .start (1'b1         ),
        .in_1  (a1_i         ),
        .in_2  (gf_in        ),
        .out   (gf_out       ),
        .done  (             )
    );

    assign gf_in = (cnt==0)? 8'h08 :
                   (cnt==1)? 8'h54 :
                   (cnt==2)? 8'h9d : 8'h4e;

    always @(posedge clk_i) begin
        if(~rst_ni)
            busy <= 0;
        else if(start_i)
            busy <= 1;
        else if(compute_state & cnt==15)
            busy <= 0;
    end

    assign busy_o = busy;

    always @(posedge clk_i) begin
        if(~rst_ni | start_i | (init_state & cnt==3) | (compute_state & cnt==15))
            cnt <= 0;
        else if(busy)
            cnt <= cnt + 1;
    end

    always @(posedge clk_i) begin
        if(~rst_ni)
            init_state <= 0;
        else if(start_i)
            init_state <= 1;
        else if(init_state & cnt==3)
            init_state <= 0;
    end

    always @(posedge clk_i) begin
        if(~rst_ni | start_i)
            compute_state <= 0;
        else if(init_state & cnt==3)
            compute_state <= 1;
        else if(compute_state & cnt==15)
            compute_state <= 0;
    end

    assign dout_valid_o = compute_state;

endmodule