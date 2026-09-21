`timescale 1ns / 1ps

module hqc_rsdecod_zpoly #(
    parameter PARAM_SECURITY = 128,
    parameter PARAM_DELTA    = 15,
    parameter SYN_W          = 120,
    parameter DIN_W          = 128,
    parameter DOUT_W         = 128
)(
    input                   clk_i,
    input                   rst_ni,
    input   [SYN_W-1:0]     synd_i,
    input   [119:0]         sigma_i, 
    input                   start_i,
    input   [7:0]           deg_sigma_i,
    output                  busy_o,
    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o
);
    reg     [DOUT_W-1:0]    dout;
    reg     [SYN_W-1:0]     syndrome_buf1, syndrome_buf2;
    reg     [119:0]         sigma_buf;
    reg     [7:0]           i_sigma, z_buf;
    wire    [7:0]           z, gf_mul_out;
    wire                    mask;
    reg     [5:0]           i_cnt, j_cnt;
    wire                    i_cnt_en, j_cnt_en, j_cnt_end, busy_end;
    reg                     busy, dout_valid;

    always @(posedge clk_i)
        if(start_i)
            syndrome_buf1 <= synd_i;
        else if(i_cnt_en)
            syndrome_buf1 <= {syndrome_buf1[7:0], syndrome_buf1[119:8]};

    always @(posedge clk_i)
        if(i_cnt_en)
            syndrome_buf2 <= syndrome_buf1;
        else if(j_cnt_en)
            syndrome_buf2 <= {syndrome_buf2[111:0], syndrome_buf2[119 -: 8]};

    always @(posedge clk_i)
        if(start_i | i_cnt_en)
            sigma_buf <= sigma_i;
        else if(j_cnt_en)
            sigma_buf <= {sigma_buf[7:0], sigma_buf[119:8]};

    always @(posedge clk_i)
        if(i_cnt_en)
            i_sigma <= (i_cnt==0)? sigma_buf[15:8] : sigma_buf[23:16];

    always @(posedge clk_i)
        if(start_i)
            dout <= 'h0;
        else if(i_cnt_en)
            dout <= {z, dout[DOUT_W-1:8]};

    assign dout_o = dout;
    assign z = (i_cnt==0)? 1 : mask? ((j_cnt==0)? i_sigma ^ syndrome_buf2[7:0] : z_buf ^ gf_mul_out) : 0;

    always @(posedge clk_i)
        if(j_cnt_en)
            z_buf <= mask? z : 0;

    assign mask = (i_cnt < (deg_sigma_i+1));

    gfmul_00 GF_MUL(
        .start (1'b1              ),
        .in_1  (syndrome_buf2[7:0]),
        .in_2  (sigma_buf[7:0]    ),
        .out   (gf_mul_out        ),
        .done  (                  )
    );

    always @(posedge clk_i)
        if(~rst_ni | busy_end)
            busy <= 0;
        else if(start_i)
            busy <= 1;

    assign busy_o = busy;

    always @(posedge clk_i)
        if(~rst_ni | start_i | busy_end)
            i_cnt <= 0;
        else if(i_cnt_en)
            i_cnt <= i_cnt + 1;

    assign i_cnt_en = j_cnt_end & busy;
    assign busy_end = (i_cnt==PARAM_DELTA) & i_cnt_en;

    always @(posedge clk_i)
        if(~rst_ni | start_i | i_cnt_en)
            j_cnt <= 0;
        else if(j_cnt_en)
            j_cnt <= j_cnt + 1;

    assign j_cnt_en  = busy;
    assign j_cnt_end = (i_cnt==0)? 0 : (i_cnt-1);

    always @(posedge clk_i)
        dout_valid <= busy_end;

    assign dout_valid_o = dout_valid;

endmodule