`timescale 1ns / 1ps

module decap_tb;

    reg clk = 0;
    always #5 clk = ~clk; // Clock 100MHz

    reg [31:0] gpio_ctrl = 0;
    reg [31:0] gpio_addr = 0;
    reg [31:0] gpio_wdata = 0;
    wire [31:0] gpio_rdata;

    parameter N_MEM_WIDTH = 139; 
    
    // Khai b?o c?c m?ng d? li?u ??u v?o (?? th?m Y v? D)
    reg [127:0] h_mem_in [0:N_MEM_WIDTH-1]; // Public Key
    reg [127:0] s_mem_in [0:N_MEM_WIDTH-1]; // Secret Key 1
    reg [127:0] u_mem_in [0:N_MEM_WIDTH-1]; // Ciphertext U
    reg [127:0] v_mem_in [0:N_MEM_WIDTH-1]; // Ciphertext V
    reg [31:0]  y_mem_in [0:65];            // Secret Key 2 (Y) - Ch? c?n 66 ph?n t?
    reg [31:0]  d_mem_in [0:15];            // D data (T? Encap) - 16 ph?n t?

    integer fd_ss;
    integer i, w;
    integer timeout_cnt;

    // --- [NEW] Bi?n ??m chu k? ch?nh x?c ---
    integer exact_cycle_count = 0;
    reg is_core_running = 0;

    always @(posedge clk) begin
        if (is_core_running) begin
            exact_cycle_count = exact_cycle_count + 1;
        end
    end

    // --- DUT (Wrapper V3.0) ---
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
    
    // --- Task n?p RAM 128-bit (Cho H, S, U, V) ---
    task load_ram_128(input [2:0] target_ram_sel);
        reg [127:0] current_val;
        begin
            $display("--- [TB] Dang nap RAM ID %0d ---", target_ram_sel);
            for (i = 0; i < N_MEM_WIDTH; i = i + 1) begin
                if (target_ram_sel == 0) current_val = h_mem_in[i];
                else if (target_ram_sel == 1) current_val = s_mem_in[i];
                else if (target_ram_sel == 2) current_val = u_mem_in[i];
                else if (target_ram_sel == 3) current_val = v_mem_in[i];
                
                gpio_addr = i;
                for (w = 0; w < 4; w = w + 1) begin
                    gpio_wdata = current_val[31:0];
                    current_val = current_val >> 32;
                    gpio_ctrl = (w << 10); 
                    #10;
                end
                
                gpio_ctrl = (3 << 10) | (target_ram_sel << 7) | (1 << 6); 
                #10;
                gpio_ctrl = 0; 
                #10;
            end
        end
    endtask

    // --- [NEW] Task n?p RAM 32-bit (Cho Y v? D) ---
    task load_ram_32(input [2:0] target_ram_sel);
        reg [31:0] current_val;
        integer limit;
        begin
            if (target_ram_sel == 4) begin
                $display("--- [TB] Dang nap Secret Key Y (RAM ID 4)... ---");
                limit = 66; // Y_DEPTH
            end else begin
                $display("--- [TB] Dang nap D Data (RAM ID 5)... ---");
                limit = 16; // D_DEPTH
            end

            for (i = 0; i < limit; i = i + 1) begin
                if (target_ram_sel == 4) current_val = y_mem_in[i];
                else current_val = d_mem_in[i];
                
                gpio_addr = i;
                gpio_wdata = current_val;
                
                // Ch? n?p ? word_sel = 0
                gpio_ctrl = (0 << 10);
                #10;
                
                // K?ch ho?t ghi (ram_wen=1)
                gpio_ctrl = (0 << 10) | (target_ram_sel << 7) | (1 << 6); 
                #10;
                gpio_ctrl = 0; 
                #10;
            end
        end
    endtask

    // --- Lu?ng ch?nh ---
    initial begin
        $display("=== KHOI DONG HE THONG DECAP TESTBENCH V3.0 ===");
        // 1. ??c file (Ch? ?: Y v? D ??c theo ??nh d?ng Hex)
        $readmemb("h_128.in", h_mem_in);
        $readmemb("s_128.in", s_mem_in);
        $readmemb("u_128.in", u_mem_in);
        $readmemb("v_128.in", v_mem_in);
        
        // D?ng l?nh ??c file Hex cho Y v? D ?? tr?nh r?c!
        $readmemb("y_128.in", y_mem_in); // File Y sinh ra t? Keygen
        $readmemb("d_128.in", d_mem_in); // File D sinh ra t? Encap
        
        fd_ss = $fopen("ss_decap_output.out", "w");

        // 2. Reset
        gpio_ctrl = 1; #50; 
        gpio_ctrl = 0; #50;

        // 3. N?p d? li?u qua Giao ti?p AXI
        load_ram_128(0); // H 
        load_ram_128(1); // S
        load_ram_128(2); // U
        load_ram_128(3); // V
        load_ram_32(4);  // Y (RAM ID = 4)
        load_ram_32(5);  // D (RAM ID = 5)

        // Debug RAM U[0]
        $display("--- [DEBUG] Kiem tra RAM U[0] ---");
        $display("RAM U[0] thuc te: %h", DUT.RAM_U.mem[0]);

        // 4. Trigger Decap (Op = 2)
        $display("--- [TB] Bat dau Decap (Op=2) ---");
        exact_cycle_count = 0;     // <-- Reset b? ??m
        is_core_running = 1;       // <-- B?t ??u ??m

        gpio_ctrl = (1 << 3) | (1 << 1); // Op=10, Start=1
        #20;
        gpio_ctrl = (1 << 3);            // H? Start
        
        // 5. Polling Done
        $display("--- [TB] Dang cho tin hieu DONE... ---");
        gpio_addr = 32'hFFFFFFFF;
        timeout_cnt = 0;
        while (gpio_rdata[0] !== 1'b1) begin
            #10; // Ki?m tra m?i chu k? (10ns)
            timeout_cnt = timeout_cnt + 1;
            if (timeout_cnt > 4000000) begin 
                $display("--- [LOI] Timeout ---");
                $finish;
            end
        end
        is_core_running = 0;       // <-- D?ng ??m

        $display("--- [TB] DECAP DONE! ---");
        $display("--- [TB] EXACT CYCLES: %0d ---", exact_cycle_count);
        #1000;

        // 6. L?u Shared Secret (S?a l?i %h)
        $display("--- [TB] Saving SS ---");
        begin : read_ss_blk
            reg [31:0] raw_slice, swapped_slice;
            for (i=0; i<16; i=i+1) begin
               gpio_addr = i;
               gpio_ctrl = 4104; // Out_en=1, Op=2
               #50;
               raw_slice = gpio_rdata;
               swapped_slice = swap_endian_32(raw_slice);
               
               // D?ng %08x ?? b?o to?n s? 0
               $fwrite(fd_ss, "%08x", swapped_slice);
               if (i % 4 == 0) $write("\nSS_Decap[%0d-%0d]: ", i, i+3);
               $write("%08x ", swapped_slice);
            end
            $display("\n");
        end

        $fclose(fd_ss);
        $display("=== FINISHED ===");
        $finish;
    end

endmodule