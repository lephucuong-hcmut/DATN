`timescale 1ns / 1ps

module fft_retrieve_error_poly #(
    parameter PARAM_SECURITY = 128,
    parameter PARAM_N1       = 46,
    parameter IN_AW          = 8,
    parameter IN_DW          = 8,
    parameter DOUT_W         = 8*PARAM_N1
)(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    output                  busy_o,

    input   [IN_DW-1:0]     ram_din_i,
    output                  ram_din_rd_o,
    output  [IN_AW-1:0]     ram_din_addr_o,

    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o
);
    reg     [DOUT_W-1:0]    error_buf;
    wire    [IN_DW-1:0]     error_data, error_temp;

    reg     [7:0]           addr;
    reg     [7:0]           cnt;
    wire                    last_cnt;
    reg     [3:0]           start_d;
    reg     [2:0]           cnt_en_d;
    reg                     cnt_en, busy, dout_valid;

    always @(posedge clk_i) begin
        if(cnt_en_d[1])
            error_buf <= {error_data, error_buf[DOUT_W-1:8]};
    end

    assign dout_o = error_buf;

    assign error_temp = (ram_din_i==0)? 8'h0000_0001 : 8'b1111_1110;
    assign error_data = start_d[3]? error_buf[DOUT_W-1 -:8] ^ error_temp : error_temp;

    always @(posedge clk_i) begin
        if(~rst_ni | (cnt_en_d[1] & ~cnt_en_d[0]))
            busy <= 0;
        else if(start_i)
            busy <= 1;
    end

    assign busy_o = busy;

    always @(posedge clk_i) begin
        if(~rst_ni | start_i | (last_cnt & cnt_en))
            cnt <= 0;
        else if(cnt_en)
            cnt <= cnt + 1;
    end

    assign last_cnt = (cnt==(PARAM_N1));

    always @(posedge clk_i) begin
        if(~rst_ni | last_cnt)
            cnt_en <= 0;
        else if(start_i)
            cnt_en <= 1;
    end

    always @(posedge clk_i) begin
        if(~rst_ni)
            cnt_en_d <= 0;
        else
            cnt_en_d <= {cnt_en_d[2:0], cnt_en};
    end

    assign ram_din_rd_o   = cnt_en_d[0];
    assign ram_din_addr_o = addr;

    always @(posedge clk_i) begin
        if(~rst_ni)
            start_d <= 0;
        else
            start_d <= {start_d[2:0], start_i};
    end

    always @(posedge clk_i) begin
        dout_valid <= cnt_en_d[1] & ~cnt_en_d[0];
    end

    assign dout_valid_o = dout_valid;

    always @(posedge clk_i) begin
        case(cnt[6:0])
            0  : addr <= 0  ;   1  : addr <= 128;   2  : addr <= 113;   3  : addr <= 226;
            4  : addr <= 181;   5  : addr <= 27 ;   6  : addr <= 54 ;   7  : addr <= 108;
            8  : addr <= 216;   9  : addr <= 193;   10 : addr <= 243;   11 : addr <= 151;
            12 : addr <= 95 ;   13 : addr <= 190;   14 : addr <= 13 ;   15 : addr <= 26 ;
            16 : addr <= 52 ;   17 : addr <= 104;   18 : addr <= 208;   19 : addr <= 209;
            20 : addr <= 211;   21 : addr <= 215;   22 : addr <= 223;   23 : addr <= 207;
            24 : addr <= 239;   25 : addr <= 175;   26 : addr <= 47 ;   27 : addr <= 94 ;
            28 : addr <= 188;   29 : addr <= 9  ;   30 : addr <= 18 ;   31 : addr <= 36 ;
            32 : addr <= 72 ;   33 : addr <= 144;   34 : addr <= 81 ;   35 : addr <= 162;
            36 : addr <= 53 ;   37 : addr <= 106;   38 : addr <= 212;   39 : addr <= 217;
            40 : addr <= 195;   41 : addr <= 247;   42 : addr <= 159;   43 : addr <= 79 ;
            44 : addr <= 158;   45 : addr <= 77 ;   46 : addr <= 154;   47 : addr <= 69 ;
            48 : addr <= 138;   49 : addr <= 101;   50 : addr <= 202;   51 : addr <= 229;
            52 : addr <= 187;   53 : addr <= 7  ;   54 : addr <= 14 ;   55 : addr <= 28 ;
            56 : addr <= 56 ;   57 : addr <= 112;   58 : addr <= 224;   59 : addr <= 177;
            60 : addr <= 19 ;   61 : addr <= 38 ;   62 : addr <= 76 ;   63 : addr <= 152;
            64 : addr <= 65 ;   65 : addr <= 130;   66 : addr <= 117;   67 : addr <= 234;
            68 : addr <= 165;   69 : addr <= 59 ;   70 : addr <= 118;   71 : addr <= 236;
            72 : addr <= 169;   73 : addr <= 35 ;   74 : addr <= 70 ;   75 : addr <= 140;
            76 : addr <= 105;   77 : addr <= 210;   78 : addr <= 213;   79 : addr <= 219;
            80 : addr <= 199;   81 : addr <= 255;   82 : addr <= 143;   83 : addr <= 111;
            84 : addr <= 222;   85 : addr <= 205;   86 : addr <= 235;   87 : addr <= 167;
            88 : addr <= 63 ;   89 : addr <= 126;   90 : addr <= 252;   91 : addr <= 137;
            92 : addr <= 99 ;   93 : addr <= 198;   94 : addr <= 253;   95 : addr <= 139;
            96 : addr <= 103;   97 : addr <= 206;   98 : addr <= 237;   99 : addr <= 171;
            100: addr <= 39 ;   101: addr <= 78 ;   102: addr <= 156;   103: addr <= 73 ;
            104: addr <= 146;   105: addr <= 85 ;   106: addr <= 170;   107: addr <= 37 ;
            108: addr <= 74 ;   109: addr <= 148;   110: addr <= 89 ;   111: addr <= 178;
            112: addr <= 21 ;   113: addr <= 42 ;   114: addr <= 84 ;   115: addr <= 168;
            116: addr <= 33 ;   117: addr <= 66 ;   118: addr <= 132;   119: addr <= 121;
            120: addr <= 242;   121: addr <= 149;   122: addr <= 91 ;   123: addr <= 182;
            124: addr <= 29 ;   125: addr <= 58 ;   126: addr <= 116;   127: addr <= 232;
            default : addr <= 0;
        endcase
    end

endmodule