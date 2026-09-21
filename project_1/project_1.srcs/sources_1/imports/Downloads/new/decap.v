`timescale 1ns / 1ps

`include "clog2.v"

module decap #( 
    parameter N1_BYTES = 46,
    parameter K_BYTES = 16,
    parameter WEIGHT = 66,
    parameter LOG_WEIGHT = `CLOG2(WEIGHT),
    parameter WEIGHT_ENC = 75,
    parameter N = 17_669,
    parameter N1N2 = 17_664,
    parameter M = 15,
    parameter N1 = 8*N1_BYTES,
    parameter K = 8*K_BYTES,
    parameter LOG_WEIGHT_ENC = `CLOG2(WEIGHT_ENC),
    parameter LOG_N1_BYTES = `CLOG2(N1_BYTES),
    
    parameter RAMWIDTH = 128,
    parameter TWO_N = 2*N,
    parameter W_RAMWIDTH = TWO_N + (RAMWIDTH-TWO_N%RAMWIDTH)%RAMWIDTH, 
    parameter W = W_RAMWIDTH + RAMWIDTH*((W_RAMWIDTH/RAMWIDTH)%2),
    parameter X = W/RAMWIDTH,
    parameter LOGX = `CLOG2(X), 
    parameter Y = X/2,
    parameter LOGW = `CLOG2(W),
    parameter W_BY_X = W/X, 
    parameter W_BY_Y = W/Y, 
    parameter RAMSIZE = X,
    parameter ADDR_WIDTH = `CLOG2(RAMSIZE),
    parameter LOG_MAX_WEIGHT = `CLOG2(WEIGHT_ENC),
  
    parameter MEM_WIDTH = RAMWIDTH,	
    parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, 
    parameter N_B = N + (8-N%8)%8, 
    parameter N_Bd = N_B - N, 
    parameter N_MEMd = N_MEM - N_B, 
	 
    parameter RAMDEPTH = (N+(RAMWIDTH-N%RAMWIDTH)%RAMWIDTH)/RAMWIDTH, 
    parameter LOG_RAMDEPTH = `CLOG2(RAMDEPTH)
)
(
    input clk,
    input rst,
    input start,
	
    input [RAMWIDTH-1:0] decap_in,
    input [LOG_RAMDEPTH-1:0] decap_in_addr,
	
    output [LOG_WEIGHT-1:0] y_addr,
    input [M-1:0] y,
    
    input [RAMWIDTH-1:0] u_0,
    input [RAMWIDTH-1:0] u_1,	
    output [`CLOG2(X)-1:0] u_addr_0,
    output [`CLOG2(X)-1:0] u_addr_1,
	
    input [RAMWIDTH-1:0] v_0,
    input [RAMWIDTH-1:0] v_1,	
    output [`CLOG2(X)-1:0] v_addr_0,
    output [`CLOG2(X)-1:0] v_addr_1,
	
    input decap_out_en,
    input [LOG_RAMDEPTH-1:0]decap_out_addr,
    output [RAMWIDTH-1:0] decap_out,

    output e_start_encap,
    output [32-1:0] e_m_in,
    output [`CLOG2((K-(32-K%32)%32)/32) -1:0] e_m_addr,
    output e_m_wen,
	
    input e_done_encap,
    output [1:0] e_sel_out,
    output e_out_en,
    output [LOG_RAMDEPTH-1:0]e_out_addr,
    input [127:0] e_encap_dout,
    
    output e_u_v_in_wen,
    output [`CLOG2(RAMDEPTH)-1:0] e_u_v_in_addr,
    output [RAMWIDTH-1:0] e_u_v_in,
    output e_resume_encap,
    input e_enc_done,

    output pm_start,    
    output [M-1:0] pm_loc_in,
    output [LOG_MAX_WEIGHT:0] pm_weight,
    output [W_BY_X-1:0]pm_mux_word_0,
    output [W_BY_X-1:0]pm_mux_word_1,
    output pm_rd_dout,
    output [`CLOG2(RAMSIZE/2)-1:0]pm_addr_result,
    output pm_add_wr_en,
    output [`CLOG2(RAMSIZE/2)-1:0] pm_add_addr,
    output [RAMWIDTH-1:0] pm_add_in,
	
    input [LOG_WEIGHT-1:0] pm_loc_addr,
    input [W_BY_X-1:0]pm_dout,
    input pm_valid,
    input  [ADDR_WIDTH-1:0]pm_addr_0,
    input  [ADDR_WIDTH-1:0]pm_addr_1,
	
    output reg encap_inside_decap,
    output reg done
);
    reg resume_encap;
    reg m_wen;
    wire [31:0] m_in;
    wire done_encap;
    reg [`CLOG2((K+(32-K%32)%32)/32):0] m_addr;

    reg [1:0]sel_out;
    reg encap_out_en;
    reg [LOG_RAMDEPTH-1:0]encap_out_addr;
    wire [RAMWIDTH-1:0]encap_dout;
    reg u_v_in_wen, u_v_in_wen_reg;
    reg [LOG_RAMDEPTH-1:0] u_v_in_addr, u_v_in_addr_reg;
    wire [RAMWIDTH-1:0] u_v_in;
    wire [K-1:0] decypted_msg, decypted_msg_rearranged;

    wire pm_start_d;    
    wire [M-1:0] pm_loc_in_d;
    wire [LOG_MAX_WEIGHT:0] pm_weight_d;
    wire [W_BY_X-1:0]pm_mux_word_0_d;
    wire [W_BY_X-1:0]pm_mux_word_1_d;
    wire pm_rd_dout_d;
    wire [`CLOG2(RAMSIZE/2)-1:0]pm_addr_result_d;
    wire pm_add_wr_en_d;
    wire [`CLOG2(RAMSIZE/2)-1:0] pm_add_addr_d;
    wire [RAMWIDTH-1:0] pm_add_in_d;
    wire [LOG_WEIGHT-1:0] pm_loc_addr_d;
    wire [W_BY_X-1:0]pm_dout_d;
    wire pm_valid_d;
    wire [ADDR_WIDTH-1:0]pm_addr_0_d;
    wire [ADDR_WIDTH-1:0]pm_addr_1_d;

    wire [RAMWIDTH-1:0]u_out, u_out_1; 
    reg dec_uv;
    reg copy_uv;

    wire [`CLOG2(X)-1:0] uv_addr_1_dec;
    wire [`CLOG2(X)-1:0] uv_addr_0_dec;
  
    assign u_addr_0 = dec_uv? uv_addr_0_dec: copy_uv ? u_v_in_addr :encap_out_en? encap_out_addr : decap_in_addr;
    assign u_addr_1 = uv_addr_1_dec;
  
    assign v_addr_0 = dec_uv? uv_addr_0_dec: copy_uv ? u_v_in_addr :encap_out_en? encap_out_addr: decap_in_addr;
    assign v_addr_1 = uv_addr_1_dec;

    wire [RAMWIDTH-1:0] uv_0_dec;
    wire [RAMWIDTH-1:0] uv_1_dec;
    wire sel_uv_dec;

    reg start_decrypt;
    wire done_decrypt;

    assign uv_0_dec = sel_uv_dec? v_0 : u_0;
    assign uv_1_dec = sel_uv_dec? v_1 : u_1;

    decrypt DECRYPT ( 
        .clk(clk),
        .rst(rst),
        .start(start_decrypt),
        .done(done_decrypt),
        .y_addr(y_addr),
        .y(y),
        .uv_0(uv_0_dec),
        .uv_1(uv_1_dec),
        .uv_addr_0(uv_addr_0_dec),
        .uv_addr_1(uv_addr_1_dec),
        .sel_uv(sel_uv_dec),
        .pm_start(pm_start_d),    
        .pm_loc_in(pm_loc_in_d),
        .pm_weight(pm_weight_d),
        .pm_mux_word_0(pm_mux_word_0_d),
        .pm_mux_word_1(pm_mux_word_1_d),
        .pm_rd_dout(pm_rd_dout_d),
        .pm_addr_result(pm_addr_result_d),
        .pm_add_wr_en(pm_add_wr_en_d),
        .pm_add_addr(pm_add_addr_d),
        .pm_add_in(pm_add_in_d),
        .pm_loc_addr(pm_loc_addr_d),
        .pm_addr_0(pm_addr_0_d),
        .pm_addr_1(pm_addr_1_d),
        .pm_valid(pm_valid_d),
        .pm_dout(pm_dout_d),
        .dout(decypted_msg)
    );

    genvar i;
    generate
        for (i = 0; i < K/8; i=i+1) begin:vector_gen_rearrange
            assign decypted_msg_rearranged[8*(i+1)-1:8*i] =  decypted_msg[K-8*(i)-1:K-8*(i+1)];
        end
    endgenerate

    reg capture_msg;
    reg load_msg;
    reg [K-1:0] msg_in;

    always@(posedge clk) begin
        if (capture_msg) begin
            msg_in <= decypted_msg_rearranged;
        end else if (load_msg) begin
            msg_in <= {msg_in[K-32-1:0],32'h00000000};
        end
    end

    assign m_in = msg_in[K-1:K-32];
    assign u_v_in = (sel_out == 2)? u_0: v_0;
    assign decap_out = encap_dout;

    reg start_encap;
    wire done_encrypt;

    assign e_start_encap    = start_encap;
    assign e_m_in           = m_in;
    assign e_m_addr         = m_addr[`CLOG2((K+(32-K%32)%32)/32) - 1:0];
    assign e_m_wen          = m_wen;
    assign e_sel_out        = decap_out_en?0:sel_out;
    assign e_out_en         = decap_out_en?1:encap_out_en;
    assign e_out_addr       = decap_out_en?decap_out_addr:encap_out_addr;
    assign e_u_v_in_wen     = u_v_in_wen_reg;
    assign e_u_v_in_addr    = u_v_in_addr_reg;
    assign e_u_v_in         = u_v_in;
    assign e_resume_encap   = resume_encap;
    assign done_encrypt     = e_enc_done;
    assign done_encap       = e_done_encap;
    assign encap_dout       = e_encap_dout;

    assign pm_start  = pm_start_d;
    assign pm_loc_in  = pm_loc_in_d;                  
    assign pm_weight  = pm_weight_d;                  
    assign pm_mux_word_0  = pm_mux_word_0_d;                  
    assign pm_mux_word_1  = pm_mux_word_1_d;
    assign pm_rd_dout  = pm_rd_dout_d;                   
    assign pm_addr_result  = pm_addr_result_d;                   
    assign pm_add_wr_en  = pm_add_wr_en_d;                   
    assign pm_add_addr  = pm_add_addr_d;
    assign pm_add_in  = pm_add_in_d;  
    
    assign pm_loc_addr_d   = pm_loc_addr;
    assign pm_addr_0_d     = pm_addr_0;
    assign pm_addr_1_d     = pm_addr_1;
    assign pm_valid_d      = pm_valid;
    assign pm_dout_d       = pm_dout;

    reg [4:0] state = 0;
    localparam s_wait_start         = 0;
    localparam s_wait_decrypt_done  = 1;
    localparam s_copy_msg_encap     = 2;
    localparam s_wait_encrypt_done  = 3;
    localparam s_compare_u_up       = 4;
    localparam s_compare_v_vp       = 5;
    localparam s_compare_d_dp       = 6;
    localparam s_copy_u             = 7;
    localparam s_copy_v             = 8;
    localparam s_resume_encap       = 9;
    localparam s_done_encap         = 10;
    localparam s_done               = 11;

    always@(posedge clk) begin
        if (rst) begin
            state <= s_wait_start;
            m_addr <= 0;
            encap_out_en <= 0;
            encap_out_addr <= 0;
            sel_out <= 0;
            done <= 0;
            copy_uv <= 0;
            dec_uv <= 0;
            u_v_in_addr <= 0;
        end else begin
            if (state == s_wait_start) begin
                m_addr <= 0;
                encap_out_en <= 0;
                encap_out_addr <= 0;
                sel_out <= 0;
                copy_uv <= 0;
                u_v_in_addr <= 0;
                if (start) begin
                    state <= s_wait_decrypt_done;
                    dec_uv <= 1;
                end else begin
                    dec_uv <= 0;
                end
            end else if (state == s_wait_decrypt_done) begin
                encap_out_en <= 0;
                encap_out_addr <= 0;
                sel_out <= 0;
                copy_uv <= 0;
                u_v_in_addr <= 0;
                if (done_decrypt) begin
                    dec_uv <= 0;
                    state <= s_copy_msg_encap;
                end else begin
                    dec_uv <= 1;
                end
            end else if (state == s_copy_msg_encap) begin
                encap_out_en <= 0;
                encap_out_addr <= 0;
                sel_out <= 0;
                copy_uv <= 0;
                u_v_in_addr <= 0;
                if (m_addr < K/32 -1) begin
                    m_addr <=  m_addr + 1;
                    state <= s_copy_msg_encap;
                end else begin
                    state <= s_wait_encrypt_done;
                    m_addr <= 0;
                end
            end else if (state == s_wait_encrypt_done) begin
                sel_out <= 2;
                encap_out_addr <= 0;
                copy_uv <= 0;
                u_v_in_addr <= 0;
                if (done_encrypt) begin
                    state <= s_compare_u_up;
                    encap_out_en <= 1;
                end else begin 
                    encap_out_en <= 0;
                end
            end else if (state == s_compare_u_up) begin
                copy_uv <= 0;
                u_v_in_addr <= 0;
                if (encap_out_addr < RAMDEPTH - 1) begin
                    sel_out <= 2;
                    encap_out_addr <= encap_out_addr + 1;
                end else begin
                    sel_out <= 2;
                    state <= s_compare_v_vp;
                    encap_out_addr <= 0;
                end
            end else if (state == s_compare_v_vp) begin
                sel_out <= 3;
                copy_uv <= 0;
                u_v_in_addr <= 0;
                if (encap_out_addr < RAMDEPTH - 2) begin
                    encap_out_addr <= encap_out_addr + 1;
                end else begin
                    state <= s_compare_d_dp;
                    encap_out_addr <= 0;
                end
            end else if (state == s_compare_d_dp) begin
                sel_out <= 1;
                u_v_in_addr <= 0;
                if (encap_out_addr < 15) begin
                    encap_out_addr <= encap_out_addr + 1;
                    copy_uv <= 0;		      
                end else begin
                    state <= s_copy_u;
                    encap_out_addr <= 0;
                    copy_uv <= 1;
                end
            end else if (state == s_copy_u) begin
                sel_out <= 2;
                encap_out_en <= 0;
                if (u_v_in_addr < RAMDEPTH - 1) begin
                    u_v_in_addr  <= u_v_in_addr + 1;
                end else begin
                    u_v_in_addr <= 0;
                    state <=  s_copy_v;
                end
            end else if (state == s_copy_v) begin
                sel_out <= 3;
                encap_out_en <= 0;
                if (u_v_in_addr < RAMDEPTH - 2) begin
                    u_v_in_addr  <= u_v_in_addr + 1;
                end else begin
                    u_v_in_addr <= 0;
                    state <=  s_resume_encap;
                end
            end else if (state == s_resume_encap) begin
                sel_out <= 0;
                encap_out_en <= 0;
                state <= s_done_encap;
            end else if (state == s_done_encap) begin
                sel_out <= 0;
                encap_out_en <= 0;
                if (done_encap) begin
                    state <= s_wait_start;
                    done <= 1;
                end 
            end
        end 
        u_v_in_addr_reg <= u_v_in_addr;
        u_v_in_wen_reg <= u_v_in_wen;
    end

    always@(*) begin
        capture_msg = 1'b0;
        load_msg = 0;
        start_encap = 1'b0;
        m_wen = 0;
        resume_encap = 0;
        u_v_in_wen = 0;
        start_decrypt = 1'b0;
        encap_inside_decap = 0;
        
        case(state)
            s_wait_start: begin
                if (start) begin
                    start_decrypt = 1'b1;
                end
            end
            s_wait_decrypt_done: begin
                if (done_decrypt) begin
                    capture_msg = 1'b1;
                end
            end
            s_copy_msg_encap: begin
                m_wen = 1;
                load_msg = 1;
                if (m_addr == K/32 - 1) begin
                    start_encap = 1;
                    encap_inside_decap = 1;
                end
            end
            s_wait_encrypt_done: begin
                encap_inside_decap = 1;
            end
            s_copy_u: begin
                u_v_in_wen = 1;
                encap_inside_decap = 1;
            end
            s_copy_v: begin
                u_v_in_wen = 1;
                encap_inside_decap = 1;
            end
            s_resume_encap: begin
                resume_encap = 1;
                encap_inside_decap = 1;
            end
            s_done_encap: begin
                encap_inside_decap = 1;
            end
            default: begin
                capture_msg = 0;
                load_msg = 0;
                start_encap = 0;
                m_wen = 0;
                resume_encap = 0;
                u_v_in_wen = 0;
                start_decrypt = 1'b0;
                encap_inside_decap = 0;
            end
        endcase
    end
endmodule