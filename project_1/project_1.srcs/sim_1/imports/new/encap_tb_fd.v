`timescale 1ns / 1ps

module encap_tb_fd;

    reg clk = 0;
    always #5 clk = ~clk; // Clock 100MHz

    // AXI GPIO Signals
    reg [31:0] gpio_ctrl = 0;
    reg [31:0] gpio_addr = 0;
    reg [31:0] gpio_wdata = 0;
    wire [31:0] gpio_rdata;

    parameter parameter_set = "hqc128";
    parameter N_MEM_WIDTH = 139; 
    parameter MSG_DEPTH   = 4;    

    reg [127:0] h_mem_in [0:N_MEM_WIDTH-1];
    reg [127:0] s_mem_in [0:N_MEM_WIDTH-1];
    reg [31:0]  msg_mem_in [0:MSG_DEPTH-1];

    integer i, w;
    integer timeout_cnt;
    integer fd_ss;
    
    reg [255:0] ss_filename;

    // --- [NEW] Bi?n ??m chu k? ch?nh x?c ---
    integer exact_cycle_count = 0;
    reg is_core_running = 0;

    always @(posedge clk) begin
        if (is_core_running) begin
            exact_cycle_count = exact_cycle_count + 1;
        end
    end

    HQC_wrapper DUT (
        .clk(clk),
        .gpio_ctrl(gpio_ctrl),
        .gpio_addr(gpio_addr),
        .gpio_wdata(gpio_wdata),
        .gpio_rdata(gpio_rdata)
    );

    function [31:0] swap_endian_32(input [31:0] in);
        begin
            swap_endian_32 = {in[7:0], in[15:8], in[23:16], in[31:24]};
        end
    endfunction

    // Gi? nguy?n h?m n?p RAM_128
    task load_ram_128(input [2:0] target_ram_sel);
        reg [127:0] current_val;
        begin
            $display("--- [TB] Loading RAM ID %0d (0=H, 1=S) ---", target_ram_sel);
            for (i = 0; i < N_MEM_WIDTH; i = i + 1) begin
                if (target_ram_sel == 3'd0) current_val = h_mem_in[i];
                else current_val = s_mem_in[i];
                
                gpio_addr = i;
                for (w = 0; w < 4; w = w + 1) begin
                    gpio_wdata = current_val[31:0];
                    current_val = current_val >> 32;
                    gpio_ctrl = (w << 10); // set word_sel
                    #10;
                end
                
                gpio_ctrl = (3 << 10) | (target_ram_sel << 7) | (1 << 6); 
                #10;
                gpio_ctrl = 0; 
                #10;
            end
        end
    endtask

    task load_message;
        begin
            $display("--- [TB] Loading Message m (RAM_SEL=6)... ---");
            for (i = 0; i < MSG_DEPTH; i = i + 1) begin
                gpio_wdata = msg_mem_in[i];
                gpio_addr  = i;
                // [FIX 1]: ??i ID Message t? 4 th?nh 6
                gpio_ctrl = (6 << 7) | (1 << 6); 
                #10;
                gpio_ctrl = 0;
                #10;
            end
        end
    endtask

    initial begin
        $display("=== STARTING ENCAP TB (FRONTDOOR + INTERNAL DUMP) ===");
        $readmemb("h_128.in", h_mem_in);
        $readmemb("s_128.in", s_mem_in);
        $readmemb("msg_128.in", msg_mem_in);
        
        gpio_ctrl = 1; #50; 
        gpio_ctrl = 0; #50;

        load_ram_128(0); 
        load_ram_128(1); 
        load_message();

        // K?ch ho?t Encap (Op=01)
        $display("--- [TB] Triggering Encap Start ---");
        exact_cycle_count = 0;     // <-- Reset b? ??m
        is_core_running = 1;       // <-- B?t ??u ??m

        gpio_ctrl = (1 << 2) | (1 << 1); 
        #20;
        gpio_ctrl = (1 << 2);            
        
        // Ch? Done
        $display("--- [TB] Polling for Done... ---");
        gpio_addr = 32'hFFFFFFFF;
        timeout_cnt = 0;
        while (gpio_rdata[0] !== 1'b1) begin
            #10; // Ki?m tra m?i chu k? (10ns)
            timeout_cnt = timeout_cnt + 1;
            if (timeout_cnt > 2000000) begin
                $display("--- [ERROR] TIMEOUT ---");
                $finish;
            end
        end
        is_core_running = 0;       // <-- D?ng ??m
        
        $display("--- [TB] DONE DETECTED! ---");
        $display("--- [TB] EXACT CYCLES: %0d ---", exact_cycle_count);
        #100;

        // L?u Shared Secret
        case (parameter_set)
            "hqc128": ss_filename = "ss_output_128.out";
            "hqc192": ss_filename = "ss_output_192.out";
            "hqc256": ss_filename = "ss_output_256.out";
            default:  ss_filename = "ss_output.out";
        endcase

        $display("--- [TB] Writing Shared Secret to %0s ---", ss_filename);
        fd_ss = $fopen(ss_filename, "w"); 
        begin : read_ss_blk
            reg [31:0] raw_slice, swapped_slice;
            for (i=0; i<16; i=i+1) begin
                gpio_addr = i;
                // C?u h?nh Ctrl ?? ??c Output Encap
                gpio_ctrl = (1 << 12) | (1 << 2); 
                #50;
                raw_slice = gpio_rdata;
                swapped_slice = swap_endian_32(raw_slice);
                
                // [FIX 3]: D?ng %08x ?? tr?nh r?t s? 0
                $fwrite(fd_ss, "%08x", swapped_slice);
            end
        end
        $fclose(fd_ss);

        // =========================================================
        // [FIX 2]: ??c D b?ng PS Interface (Hex format)
        // =========================================================
        $display("--- [TB] Dumping D via PS Interface... ---");
        begin : read_d_interface
            integer fd_d;
            fd_d = $fopen("d_128.in", "w");
            for (i = 0; i < 16; i = i + 1) begin
                gpio_addr = i;
                // ??c t? RAM_D (ram_sel = 5), word_sel=0 (v? D ch? r?ng 32-bit)
                // Bit 15=1 (Read Src), Bit 9:7=5 (RAM D)
                gpio_ctrl = (1 << 15) | (5 << 7) | (0 << 10);
                #50;
                // Ghi ra file theo format Hex (Decap c?n c?i n?y)
                $fwrite(fd_d, "%08x\n", gpio_rdata);
            end
            $fclose(fd_d);
        end

        // V?n d?ng writememb cho U v? V (Binary Format)
        $display("--- [TB] Dumping u, v, d to internal .in files ---");
        case (parameter_set)
            "hqc128": begin
                $writememb("u_128.in", DUT.DUT.ENCAP_MODULE.genblk1.ENCRYPT.u_mem.mem);
                $writememb("v_128.in", DUT.DUT.POLY_MULT.INTERLEAVED_RED_MEM.mem);
                $writememb("d_128.in", DUT.DUT.ENCAP_MODULE.D_MEM.mem); // <--- M?c tr?c ti?p (Hex format)
                $writememb("hash_mem_dump.in", DUT.DUT.ENCAP_MODULE.HASH_MEM.mem);
                $fflush();
            end
            
            "hqc192": begin
                $writememb("u_192.in", DUT.DUT.ENCAP_MODULE.genblk1.ENCRYPT.u_mem.mem);
                $writememb("v_192.in", DUT.DUT.POLY_MULT.INTERLEAVED_RED_MEM.mem);
                $writememb("d_192.in", DUT.DUT.ENCAP_MODULE.D_MEM.mem);
                $fflush();
            end

            "hqc256": begin
                $writememb("u_256.in", DUT.DUT.ENCAP_MODULE.genblk1.ENCRYPT.u_mem.mem);
                $writememb("v_256.in", DUT.DUT.POLY_MULT.INTERLEAVED_RED_MEM.mem);
                $writememb("d_256.in", DUT.DUT.ENCAP_MODULE.D_MEM.mem);
                $fflush();
            end
        endcase

        $display("=== SUCCESS: ALL FILES WRITTEN ===");
        $finish;
    end

// Dump shake_din stream v?o file ri?ng
integer fd_shake_in;
integer shake_in_count;
initial begin
    fd_shake_in = $fopen("shake_din_dump.in", "w");
    shake_in_count = 0;
end

always @(posedge clk) begin
    if (DUT.DUT.ENCAP_MODULE.shake_din_valid_h && DUT.DUT.ENCAP_MODULE.shake_din_ready_h) begin
        $fwrite(fd_shake_in, "%032b\n", DUT.DUT.ENCAP_MODULE.shake_din_h);
        shake_in_count = shake_in_count + 1;
    end
end

endmodule