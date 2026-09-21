`timescale 1ns / 1ps

module hqc_rsdecod_err_val #(
    parameter PARAM_SECURITY = 128,
    parameter PARAM_DELTA    = 15,
    parameter PARAM_G        = 31,
    parameter PARAM_K        = 16,
    parameter PARAM_N1       = 46,
    parameter ERR_W          = 8*PARAM_N1,
    parameter Z_W            = 8*(PARAM_DELTA+1),
    parameter MSG_W          = 8*PARAM_K
)(
    input                   clk_i,
    input                   rst_ni,
    input   [ERR_W-1:0]     error_i,
    input   [Z_W-1:0]       z_i,
    input                   start_i,
    output                  busy_o,
    output  [MSG_W-1:0]     error_o,
    output                  dout_valid_o
);

    reg     [ERR_W-1:0]     error_buf;
    reg     [Z_W-1:0]       z_buf;
    reg     [MSG_W-1:0]     err_val;
    reg                     dout_valid, busy;
    reg     [3:0]           state;
    wire                    state_init, state_beta, state_e, state_err;
    wire                    state_en;
    reg     [7:0]           beta_j [0:PARAM_DELTA-1], beta_ji;
    reg     [7:0]           e_j [0:PARAM_DELTA-1], e_ji;
    wire    [4:0]           beta_addr, e_addr;
    wire                    beta_wr, e_wr;

    integer i;
    wire                    beta_mask;
    reg     [4:0]           delta_cnt;
    reg                     e_mask;
    reg     [7:0]           exp_array;

    wire    [7:0]           err_dout;
    wire    [7:0]           inv_in, inv_out;
    reg     [7:0]           inv_buf;
    reg     [7:0]           tmp1, tmp2;
    reg     [7:0]           inv_power;
    wire    [7:0]           gfmul_ina1, gfmul_ina2, gfmul_inb1, gfmul_inb2;
    wire    [7:0]           gfmul_outa, gfmul_outb;
    reg     [7:0]           gfmul_outb_buf_xor1;

    reg     [6:0]           i_cnt;
    reg                     i_cnt_en;
    reg     [4:0]           ii_cnt, jj_cnt, ii_cnt_d;
    wire                    ii_cnt_en;
    reg                     jj_cnt_en;
    wire                    jj_cnt_end;
    reg                     jj_cnt_end_d;
    reg     [4:0]           ik_cnt;
    wire                    ik_cnt_en;

    always @(posedge clk_i) begin
        if(start_i | ~(state_beta | state_err))
            error_buf <= error_i;
        else if(i_cnt_en)
            error_buf <= {error_buf[7:0], error_buf[ERR_W-1:8]};
    end

    always @(posedge clk_i) begin
        if(start_i | jj_cnt==0)
            z_buf <= z_i;
        else if(~jj_cnt_en)
            z_buf <= {z_buf[7:0], z_buf[Z_W-1:8]};
    end

    assign beta_mask = (delta_cnt < PARAM_DELTA) & (error_buf[7:0] != 0);
    
    always @(posedge clk_i) begin
        if(~rst_ni | start_i | ~(state_beta | state_err) | (state_e & state_en))
            delta_cnt <= 0;
        else if(beta_mask & i_cnt_en)
            delta_cnt <= delta_cnt + 1;
    end

    always @(posedge clk_i) begin
        if(state_err & i_cnt_en)
            err_val <= {err_dout, err_val[MSG_W-1:8]};
    end
    
    assign err_dout = beta_mask? e_ji : 0;
    assign error_o  = err_val;

    always @(posedge clk_i) begin
        e_mask <= (ii_cnt_d < delta_cnt);
    end

    assign inv_in  = (jj_cnt==PARAM_DELTA)? tmp2 : beta_ji;
    assign inv_out = I(inv_in);
    
    always @(posedge clk_i) begin
        if(state_e & ((jj_cnt==0 & jj_cnt_en) | jj_cnt==PARAM_DELTA))
            inv_buf <= inv_out;
    end

    always @(posedge clk_i) begin
        if(jj_cnt==0)
            inv_power <= 1;
        else if(~jj_cnt_en)
            inv_power <= gfmul_outa;
    end

    always @(posedge clk_i) begin
        if(jj_cnt==0)
            tmp1 <= 1;
        else if(jj_cnt_en)
            tmp1 <= tmp1 ^ gfmul_outa;
    end

    always @(posedge clk_i) begin
        if(jj_cnt==0)
            tmp2 <= 1;
        else if(jj_cnt!=PARAM_DELTA & jj_cnt_en)
            tmp2 <= gfmul_outb;
    end

    always @(posedge clk_i) begin
        gfmul_outb_buf_xor1 <= 1 ^ gfmul_outb;
    end

    assign gfmul_ina1 = jj_cnt_end_d? tmp1 : inv_power;
    assign gfmul_ina2 = jj_cnt_end_d? inv_buf : (jj_cnt_en? z_buf[7:0] : inv_buf);

    assign gfmul_inb1 = jj_cnt_en? tmp2 : inv_buf;
    assign gfmul_inb2 = jj_cnt_en? gfmul_outb_buf_xor1 : beta_ji;

    gfmul_00 GFMUL_A(
        .start (1'b1         ),
        .in_1  (gfmul_ina1   ),
        .in_2  (gfmul_ina2   ),
        .out   (gfmul_outa   ),
        .done  (             )
    );

    gfmul_00 GFMUL_B(
        .start (1'b1         ),
        .in_1  (gfmul_inb1   ),
        .in_2  (gfmul_inb2   ),
        .out   (gfmul_outb   ),
        .done  (             )
    );

    always @(posedge clk_i) begin
        if (beta_wr)
            beta_j[beta_addr] <= state_init? 0 : exp_array + beta_ji;
        beta_ji <= beta_j[beta_addr];
    end

    assign beta_wr   = (state_init & i_cnt<PARAM_DELTA) | (state_beta & i_cnt_en & beta_mask);
    assign beta_addr = state_init? i_cnt :
                       (state_beta | state_err)? delta_cnt :
                       (state_e & jj_cnt==0 & ~jj_cnt_en)? ii_cnt : ik_cnt;

    always @(posedge clk_i) begin
        exp_array <= P(i_cnt[6:0]);
    end

    initial begin
        for (i=0; i<PARAM_DELTA; i=i+1) e_j[i] = 0;
    end

    always @(posedge clk_i) begin
        if (e_wr)
            e_j[e_addr] <= e_mask? 0 : gfmul_outa;
        e_ji <= e_j[e_addr];
    end

    assign e_wr   = state_e & jj_cnt_end_d;
    assign e_addr = state_e? ii_cnt_d : delta_cnt;

    always @(posedge clk_i) begin
        if(~rst_ni)
            state <= 4'b1000;
        else if(start_i)
            state <= 4'b0001;
        else if(state_en)
            state <= {1'b0, state[1:0], 1'b0};
    end

    assign state_init = state[3];
    assign state_beta = state[0]; 
    assign state_e    = state[1];
    assign state_err  = state[2]; 
    assign state_en   = ((state_beta | state_err) & i_cnt_en & i_cnt==(PARAM_N1-1)) |
                        (state_e & jj_cnt_end_d & ii_cnt==0);

    always @(posedge clk_i) begin
        dout_valid <= state_err & state_en;
    end

    assign dout_valid_o = dout_valid;
    
    always @(posedge clk_i) begin
        if(~rst_ni | (state_err & state_en))
            busy <= 0;
        else if(start_i)
            busy <= 1;
    end
    
    assign busy_o = busy;

    always @(posedge clk_i) begin
        if(~rst_ni | start_i | ~(state_beta | state_err | state_init))
            i_cnt <= 0;
        else if(i_cnt_en | (state_init & i_cnt!=(PARAM_DELTA-1)))
            i_cnt <= i_cnt + 1;
    end
    
    always @(posedge clk_i) begin
        if(~rst_ni | start_i | ~(state_beta | state_err))
            i_cnt_en <= 0;
        else if(state_beta | state_err)
            i_cnt_en <= ~i_cnt_en;
    end

    always @(posedge clk_i) begin
        if(~rst_ni | ~state_e | (ii_cnt_en & ii_cnt==(PARAM_DELTA-1)))
            ii_cnt <= 0;
        else if(ii_cnt_en)
            ii_cnt <= ii_cnt + 1;
    end

    always @(posedge clk_i) begin
        ii_cnt_d <= ii_cnt;
    end

    assign ii_cnt_en = jj_cnt_end;
    
    always @(posedge clk_i) begin
        if(~rst_ni | start_i | jj_cnt_end)
            jj_cnt <= 0;
        else if(jj_cnt_en)
            jj_cnt <= jj_cnt + 1;
    end
    
    always @(posedge clk_i) begin
        if(~rst_ni | ~state_e)
            jj_cnt_en <= 0;
        else if(state_e)
            jj_cnt_en <= ~jj_cnt_en;
    end
    
    assign jj_cnt_end = jj_cnt_en & (jj_cnt==PARAM_DELTA);

    always @(posedge clk_i) begin
        jj_cnt_end_d <= jj_cnt_end;
    end
    
    always @(posedge clk_i) begin
        if(~rst_ni | start_i | ~state_e | (ik_cnt_en & ik_cnt==(PARAM_DELTA-1)))
            ik_cnt <= 0;
        else if(ik_cnt_en)
            ik_cnt <= ik_cnt + 1;
    end

    assign ik_cnt_en = ~jj_cnt_en;

    function [7:0] I(input [7:0] x);
        begin
            case(x)
                0  :I=0  ;1  :I=1  ;2  :I=142;3  :I=244;4  :I=71 ;5  :I=167;6  :I=122;7  :I=186;
                8  :I=173;9  :I=157;10 :I=221;11 :I=152;12 :I=61 ;13 :I=170;14 :I=93 ;15 :I=150;
                16 :I=216;17 :I=114;18 :I=192;19 :I=88 ;20 :I=224;21 :I=62 ;22 :I=76 ;23 :I=102;
                24 :I=144;25 :I=222;26 :I=85 ;27 :I=128;28 :I=160;29 :I=131;30 :I=75 ;31 :I=42 ;
                32 :I=108;33 :I=237;34 :I=57 ;35 :I=81 ;36 :I=96 ;37 :I=86 ;38 :I=44 ;39 :I=138;
                40 :I=112;41 :I=208;42 :I=31 ;43 :I=74 ;44 :I=38 ;45 :I=139;46 :I=51 ;47 :I=110;
                48 :I=72 ;49 :I=137;50 :I=111;51 :I=46 ;52 :I=164;53 :I=195;54 :I=64 ;55 :I=94 ;
                56 :I=80 ;57 :I=34 ;58 :I=207;59 :I=169;60 :I=171;61 :I=12 ;62 :I=21 ;63 :I=225;
                64 :I=54 ;65 :I=95 ;66 :I=248;67 :I=213;68 :I=146;69 :I=78 ;70 :I=166;71 :I=4  ;
                72 :I=48 ;73 :I=136;74 :I=43 ;75 :I=30 ;76 :I=22 ;77 :I=103;78 :I=69 ;79 :I=147;
                80 :I=56 ;81 :I=35 ;82 :I=104;83 :I=140;84 :I=129;85 :I=26 ;86 :I=37 ;87 :I=97 ;
                88 :I=19 ;89 :I=193;90 :I=203;91 :I=99 ;92 :I=151;93 :I=14 ;94 :I=55 ;95 :I=65 ;
                96 :I=36 ;97 :I=87 ;98 :I=202;99 :I=91 ;100:I=185;101:I=196;102:I=23 ;103:I=77 ;
                104:I=82 ;105:I=141;106:I=239;107:I=179;108:I=32 ;109:I=236;110:I=47 ;111:I=50 ;
                112:I=40 ;113:I=209;114:I=17 ;115:I=217;116:I=233;117:I=251;118:I=218;119:I=121;
                120:I=219;121:I=119;122:I=6  ;123:I=187;124:I=132;125:I=205;126:I=254;127:I=252;
                128:I=27 ;129:I=84 ;130:I=161;131:I=29 ;132:I=124;133:I=204;134:I=228;135:I=176;
                136:I=73 ;137:I=49 ;138:I=39 ;139:I=45 ;140:I=83 ;141:I=105;142:I=2  ;143:I=245;
                144:I=24 ;145:I=223;146:I=68 ;147:I=79 ;148:I=155;149:I=188;150:I=15 ;151:I=92 ;
                152:I=11 ;153:I=220;154:I=189;155:I=148;156:I=172;157:I=9  ;158:I=199;159:I=162;
                160:I=28 ;161:I=130;162:I=159;163:I=198;164:I=52 ;165:I=194;166:I=70 ;167:I=5  ;
                168:I=206;169:I=59 ;170:I=13 ;171:I=60 ;172:I=156;173:I=8  ;174:I=190;175:I=183;
                176:I=135;177:I=229;178:I=238;179:I=107;180:I=235;181:I=242;182:I=191;183:I=175;
                184:I=197;185:I=100;186:I=7  ;187:I=123;188:I=149;189:I=154;190:I=174;191:I=182;
                192:I=18 ;193:I=89 ;194:I=165;195:I=53 ;196:I=101;197:I=184;198:I=163;199:I=158;
                200:I=210;201:I=247;202:I=98 ;203:I=90 ;204:I=133;205:I=125;206:I=168;207:I=58 ;
                208:I=41 ;209:I=113;210:I=200;211:I=246;212:I=249;213:I=67 ;214:I=215;215:I=214;
                216:I=16 ;217:I=115;218:I=118;219:I=120;220:I=153;221:I=10 ;222:I=25 ;223:I=145;
                224:I=20 ;225:I=63 ;226:I=230;227:I=240;228:I=134;229:I=177;230:I=226;231:I=241;
                232:I=250;233:I=116;234:I=243;235:I=180;236:I=109;237:I=33 ;238:I=178;239:I=106;
                240:I=227;241:I=231;242:I=181;243:I=234;244:I=3  ;245:I=143;246:I=211;247:I=201;
                248:I=66 ;249:I=212;250:I=232;251:I=117;252:I=127;253:I=255;254:I=126;255:I=253;
            endcase
        end
    endfunction

    function [7:0] P(input [6:0] x);
        begin
            case(x)
                0  :P=0  ;1  :P=1  ;2  :P=142;3  :P=244;4  :P=71 ;5  :P=167;6  :P=122;7  :P=186;
                8  :P=173;9  :P=157;10 :P=221;11 :P=152;12 :P=61 ;13 :P=170;14 :P=93 ;15 :P=150;
                16 :P=216;17 :P=114;18 :P=192;19 :P=88 ;20 :P=224;21 :P=62 ;22 :P=76 ;23 :P=102;
                24 :P=144;25 :P=222;26 :P=85 ;27 :P=128;28 :P=160;29 :P=131;30 :P=75 ;31 :P=42 ;
                32 :P=108;33 :P=237;34 :P=57 ;35 :P=81 ;36 :P=96 ;37 :P=86 ;38 :P=44 ;39 :P=138;
                40 :P=112;41 :P=208;42 :P=31 ;43 :P=74 ;44 :P=38 ;45 :P=139;46 :P=51 ;47 :P=110;
                48 :P=72 ;49 :P=137;50 :P=111;51 :P=46 ;52 :P=164;53 :P=195;54 :P=64 ;55 :P=94 ;
                56 :P=80 ;57 :P=34 ;58 :P=207;59 :P=169;60 :P=171;61 :P=12 ;62 :P=21 ;63 :P=225;
                64 :P=54 ;65 :P=95 ;66 :P=248;67 :P=213;68 :P=146;69 :P=78 ;70 :P=166;71 :P=4  ;
                72 :P=48 ;73 :P=136;74 :P=43 ;75 :P=30 ;76 :P=22 ;77 :P=103;78 :P=69 ;79 :P=147;
                80 :P=56 ;81 :P=35 ;82 :P=104;83 :P=140;84 :P=129;85 :P=26 ;86 :P=37 ;87 :P=97 ;
                88 :P=19 ;89 :P=193;90 :P=203;91 :P=99 ;92 :P=151;93 :P=14 ;94 :P=55 ;95 :P=65 ;
                96 :P=36 ;97 :P=87 ;98 :P=202;99 :P=91 ;100:P=185;101:P=196;102:P=23 ;103:P=77 ;
                104:P=82 ;105:P=141;106:P=239;107:P=179;108:P=32 ;109:P=236;110:P=47 ;111:P=50 ;
                112:P=40 ;113:P=209;114:P=17 ;115:P=217;116:P=233;117:P=251;118:P=218;119:P=121;
                120:P=219;121:P=119;122:P=6  ;123:P=187;124:P=132;125:P=205;126:P=254;127:P=252;
                default: P=0;
            endcase
        end
    endfunction

endmodule