`timescale 1ns / 1ps

module hqc_rsdecod_syndromes #(
    parameter PARAM_SECURITY = 128,
    parameter PARAM_DELTA    = 15,
    parameter PARAM_G        = 31,
    parameter PARAM_K        = 16,
    parameter PARAM_N1       = 46,
    parameter ALPHA_DW       = 240,
    parameter ALPHA_AW       = 6,
    parameter DIN_W          = 8,
    parameter DOUT_W         = 240,
    parameter MSG_W          = 128
)(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    input   [DIN_W-1:0]     din_i,
    input                   din_valid_i,
    input                   din_done_i,
    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o,
    output  [MSG_W-1:0]     msg_o
);
    reg     [DOUT_W-1:0]    synd_buf;
    reg     [MSG_W-1:0]     msg_buf;
    reg                     din_valid_d;
    reg                     gf_en;
    wire                    synd_en;
    wire    [7:0]           cdw_in;
    wire    [7:0]           alpha_ij_pow;
    wire    [7:0]           gf_mul_out;
    reg     [ALPHA_DW-1:0]  alpha_rom, alpha_buf;
    reg     [ALPHA_AW-1:0]  din_cnt;
    reg     [5:0]           cnt;
    reg                     cnt_en;
    wire                    last_cnt;
    reg                     input_done;
    reg                     dout_valid;

    always @(posedge clk_i)
        if(din_valid_i)
            msg_buf <= {din_i, msg_buf[MSG_W-1:DIN_W]};

    assign msg_o = msg_buf;
    assign cdw_in = msg_buf[MSG_W-1 -: 8];

    always @(posedge clk_i)
        if(~rst_ni | start_i)
            synd_buf <= 0;
        else if(synd_en) begin
            synd_buf[DOUT_W-1 -: 8] <= gf_mul_out ^ synd_buf[7:0];
            synd_buf[DOUT_W-1-8: 0] <= synd_buf[DOUT_W-1:8];
        end

    assign dout_o = synd_buf;

    always @(posedge clk_i)
        if(din_valid_d)
            alpha_buf <= alpha_rom;
        else if(gf_en)
            alpha_buf <= {alpha_buf[ALPHA_DW-1-8:0], alpha_buf[ALPHA_DW-1 -: 8]};

    assign alpha_ij_pow = alpha_buf[ALPHA_DW-1 -: 8];

    gfmul_01 GFMUL_SYND (
        .clk   (clk_i       ),
        .start (gf_en       ),
        .in_1  (cdw_in      ),
        .in_2  (alpha_ij_pow),
        .out   (gf_mul_out  ),
        .done  (synd_en     )
    );

    always @(posedge clk_i)
        if(~rst_ni | start_i)
            din_cnt <= 0;
        else if(din_valid_i)
            din_cnt <= din_cnt + 1;

    always @(posedge clk_i)
        if(~rst_ni | din_valid_i | last_cnt)
            cnt <= 0;
        else if(cnt_en)
            cnt <= cnt + 1;

    assign last_cnt = (cnt==(2*PARAM_DELTA-1));

    always @(posedge clk_i)
        if(~rst_ni | last_cnt)
            cnt_en <= 0;
        else if(din_valid_i)
            cnt_en <= 1;

    always @(posedge clk_i) begin
        gf_en       <= cnt_en;
        din_valid_d <= din_valid_i;
    end

    always @(posedge clk_i)
        if(~rst_ni | start_i)
            input_done <= 0;
        else if(din_done_i)
            input_done <= 1;

    always @(posedge clk_i)
        dout_valid <= ~gf_en & synd_en & input_done;

    assign dout_valid_o = dout_valid;

    always @(posedge clk_i)
        case(din_cnt)
            0  : alpha_rom <= 240'h010101010101010101010101010101010101010101010101010101010101;
            1  : alpha_rom <= 240'h020408102040801D3A74E8CD8713264C982D5AB475EAC98F03060C183060;
            2  : alpha_rom <= 240'h0410401D74CD134C2DB4EA8F0618609D4E25946AB5EE9F460514505D69B9;
            3  : alpha_rom <= 240'h08403ACD262D758F0C60272535B5C1460A50BAB9A1612F650F78E76B7FDF;
            4  : alpha_rom <= 240'h101DCD4CB48F189D256AEE46145DB95F99651EFD6BFE5BD9110DD081F83B;
            5  : alpha_rom <= 240'h207426B403609C6AC105A0B9BE5E0FFDD6DFE2111A677C3B332EA9844D55;
            6  : alpha_rom <= 240'h40CD2D8F6025B54650B96165786BDFD944D03E3B66B821A855E4BFFCF196;
            7  : alpha_rom <= 240'h801375189CB58C5DA15E3C6BA3431A8193666D842939D1FCFF6257C8E059;
            8  : alpha_rom <= 240'h1D4C8F9D6A465D5F65FDFED90D813B854FA849E6FCE395821C51C312F72C;
            9  : alpha_rom <= 240'h3A2D0C25C150A165E7DF86D0ED66A9A892BFB3965707A6C324FB7DAD4026;
            10 : alpha_rom <= 240'h74B4606A05B95EFDDF11673B2E8455E6D796AE1C59ACF42C6C2026039CC1;
            11 : alpha_rom <= 240'hE8EA27EEA0613CFE866776B8543991E3DC07A2ACF5B0473AB4C0B5285F0F;
            12 : alpha_rom <= 240'hCD8F2546B9656BD9D03BB8A8E4FC9682DDC33D2CAD3A7527C1BA2FE7B61A;
            13 : alpha_rom <= 240'h87063514BE78A30DED2E54E4E562645145FB83202DC0EEBA5EBBD9BDECA9;
            14 : alpha_rom <= 240'h1318B55D5E6B4381668439FC62C859120BADE8033528C2E7E2BDC59EAA91;
            15 : alpha_rom <= 240'h2660C1B90FDF1A3BA95591966459242C012660C1B90FDF1A3BA955919664;
            16 : alpha_rom <= 240'h4C9D465FFDD98185A8E6E38251122C0298278CBEE7AF1F174DD1DB19A224;
            17 : alpha_rom <= 240'h984E0A99D644934F92D7DCDD450B01984E0A99D644934F92D7DCDD450B01;
            18 : alpha_rom <= 240'h2D255065DFD066A8BF9607C3FBAD26270A2F7F1AC51573DB64F2F536CD60;
            19 : alpha_rom <= 240'h5A94BA1EE23E6D49B3AEA23D83E8608C997F3433A8636238AC1608EAD4B9;
            20 : alpha_rom <= 240'hB46AB9FD113B84E6961CAC2C2003C1BED61A334D9137A724E97460055EDF;
            21 : alpha_rom <= 240'h75B5A16B1A6629FC5759F5AD2D35B9E744C5A8916EA63D362625BA78863B;
            22 : alpha_rom <= 240'hEAEE61FE67B839E307ACB03AC0280FAF93156337A67AD82D6ADE6B348555;
            23 : alpha_rom <= 240'hC99F2F5B7C21D195A6F44775EEC2DF1F4F7362A73DD85AB5BEFECEDAD596;
            24 : alpha_rom <= 240'h8F4665D93BA8FC82C32C3A27BAE71A1792DB3824362DB561DF3E21BF6E59;
            25 : alpha_rom <= 240'h03050F113355FF1C246CB4C15EE23B4DD764ACE9266ABEDF7C8491AEEF2C;
            26 : alpha_rom <= 240'h0614780D2EE46251FB20C0BABBBDA9D1DCF2167425DEFE3E843F822BFA26;
            27 : alpha_rom <= 240'h0C50E7D0A9BF57C37D26B52FD9C555DBDDF50860BA6BCE21918256CF2DC1;
            28 : alpha_rom <= 240'h185D6B8184FCC812AD0328E7BD9E91194536EA057834DABFAE2BCF5A230F;
            29 : alpha_rom <= 240'h30697FF84DF1E0F7409C5FB6ECAA96A20BCDD45E8685D56EEFFA2D231E1A;
            30 : alpha_rom <= 240'h60B9DF3B5596592C26C10F1AA99164240160B9DF3B5596592C26C10F1AA9;
            31 : alpha_rom <= 240'hC0DEB697726E9B1B8FA0B1ED524B59589846F067157BE0FB74D46588DA91;
            32 : alpha_rom <= 240'h9D5FD985E682120227BEAF17D11924044E61432EBF3248089CC2865C6364;
            33 : alpha_rom <= 240'h276186B89107F53AB50FD015F1A62C2D0A6BED55C4C3360CB9B666738224;
            34 : alpha_rom <= 240'h4E99444FD7DD0B980AD69392DC45014E99444FD7DD0B980AD69392DC4501;
            35 : alpha_rom <= 240'h9C5E1A84FF59E903B9E22E911CEB2605D63B72AE24206A0F674D96EF6C60;
            36 : alpha_rom <= 240'h2565D0A896C3AD272F1A15DBF23660614421F159CF0CA186A9B3A67D8FB9;
            37 : alpha_rom <= 240'h4A89CE52378A10D4787C4957481DC1D393E419F4CD8CB1C5E68DFB4C28DF;
            38 : alpha_rom <= 240'h941E3E49AE3DE88C7F33633816EAB9434FF1796C27BCBD29370940EED33B;
            39 : alpha_rom <= 240'h3578EDE464FB2DBAD9A9F1F2AD250F3E9282F52650B6B8B359362765CE55;
            40 : alpha_rom <= 240'h6AFD3BE61C2C03BE1A4D37247405DF2ED7596C9C0F7C7264EBB4B9118496;
            41 : alpha_rom <= 240'hD4D3C5C6A7CF9DCA3E72C88BC95F1A9ADC3D13A0D99EAB56209F7F85E559;
            42 : alpha_rom <= 240'hB56B66FC59AD35E7C591A63625783BBFDDCF270FED73387D60653EE4072C;
            43 : alpha_rom <= 240'h77B1177BEF089FE1B8FF2B408C5BA9AB453A14E2213112CDA04315959026;
            44 : alpha_rom <= 240'hEEFEB8E3AC3A28AF15377A2DDE3455320B0CBC7C73E08325FD97FC7902C1;
            45 : alpha_rom <= 240'hC1DFA9962426B91A55642C600F3B915901C1DFA9962426B91A55642C600F;
            default : alpha_rom <= 240'h010101010101010101010101010101010101010101010101010101010101;
        endcase
endmodule