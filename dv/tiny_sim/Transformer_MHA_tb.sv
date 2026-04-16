`timescale 1ns / 1ps

module Transformer_MHA_tb;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter ARRAY_SIZE = 8;
    parameter MAT_SIZE = 64;
    parameter ADDR_WIDTH = 9;
    parameter NUM_HEADS = 2; 

    logic clk;
    logic rst_n;
    logic system_start;
    logic system_done;

    // --- INSTANTIATE TOP MODULE ---
    // Khai báo sẵn các giá trị cấu hình Q_frac cho 2 head
    logic [3:0] tb_head_q_frac [1:0] = '{4, 4}; // Q_FRAC = 4 (theo Python)
    logic [4:0] tb_cfg_shifts [0:9] = '{8, 8, 8, 8, 8, 8, 8, 8, 8, 8};

    Transformer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .MAT_SIZE(MAT_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_HEADS(NUM_HEADS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_shifts(tb_cfg_shifts),
        .head_q_frac(tb_head_q_frac),
        .system_start(system_start),
        .system_done(system_done)
    );

    initial clk = 0;
    always #5 clk = ~clk; //100MHz

    // --- TEMPORARY MEMORY FOR HEX LOADING ---
    logic [7:0] flat_mem [0:4095]; 

    // =========================================================
    // TASK 1: LOAD HEX FILE TO SRAM
    // =========================================================
    task automatic load_sram(input string filename, input int sram_idx);
        $readmemh(filename, flat_mem);
        for (int i = 0; i < 4096; i++) begin
            int row = i / ARRAY_SIZE; 
            int col = i % ARRAY_SIZE; 
            
            if (sram_idx == 10) dut.datapath_unit.sram_x.ram[row][col] = flat_mem[i];
            if (sram_idx == 0)  dut.datapath_unit.sram_0.ram[row][col] = flat_mem[i];
            if (sram_idx == 1)  dut.datapath_unit.sram_1.ram[row][col] = flat_mem[i];
            if (sram_idx == 2)  dut.datapath_unit.sram_2.ram[row][col] = flat_mem[i];
            if (sram_idx == 3)  dut.datapath_unit.sram_3.ram[row][col] = flat_mem[i];
            if (sram_idx == 4)  dut.datapath_unit.sram_4.ram[row][col] = flat_mem[i];
        end
    endtask

    // =========================================================
    // TASK 2: COMPARE SRAM WITH GOLDEN MODEL
    // =========================================================
    task automatic check_sram(input string filename, input int sram_idx, input string name);
        int errors = 0;
        logic signed [7:0] expected_val, actual_val;
        
        $readmemh(filename, flat_mem);
        
        for (int i = 0; i < 4096; i++) begin
            int row = i / ARRAY_SIZE;
            int col = i % ARRAY_SIZE;
            expected_val = flat_mem[i];
            
            if (sram_idx == 3) actual_val = dut.datapath_unit.sram_3.ram[row][col];
            if (sram_idx == 0) actual_val = dut.datapath_unit.sram_0.ram[row][col];
            if (sram_idx == 1) actual_val = dut.datapath_unit.sram_1.ram[row][col];
            if (sram_idx == 2) actual_val = dut.datapath_unit.sram_2.ram[row][col];

            if (actual_val !== expected_val) begin
                $display("[ERROR] %s mismatch at [%0d]: Expected = %0d, Actual = %0d", name, i, expected_val, actual_val);
                errors++;
                if (errors >= 15) begin
                    $display("... Too many errors, suppressing further output for %s.", name);
                    break;
                end
            end
        end
        
        if (errors == 0) $display("[PASS] %s matches Golden Model exactly!", name);
        else             $display("[FAIL] %s has %0d errors in total.", name, errors);
    endtask

    // =========================================================
    // SIMULATE DMA OVERWRITING W_O INTO SRAM 4 
    // =========================================================
    // Can thiệp ngầm (Backdoor) ghi dữ liệu W_o vào SRAM 4 ngay
    // khi nhịp Tính Z của dãy Head cuối cùng kết thúc.
    always @(posedge clk) begin
        // Kiểm tra FSM có đang ở WAIT_Z (16) không. 
        if (dut.controller.state == 5'd16 && dut.controller.stage_done == 1 && dut.controller.head_idx == NUM_HEADS - 1) begin
            $display("----------------------------------------");
            $display("[SIM-DMA] Kích hoạt giả lập DMA!");
            $display("-> Ghi đè W_proj.hex lên SRAM_4 trong 0 chu kỳ hệ thống...");
            load_sram("tb_data_v1/W_proj.hex", 4);
            $display("[SIM-DMA] Hoàn tất nạp W_o!");
            $display("----------------------------------------");
        end
    end

    // =========================================================
    // MAIN TEST SCENARIO
    // =========================================================
    initial begin
        rst_n = 0;
        system_start = 0;
        
        $display("----------------------------------------");
        $display("STEP 1: LOADING DATA TO SRAM...");
        load_sram("tb_data_v1/X_input.hex", 10); 
        load_sram("tb_data_v1/Wq.hex", 0);       
        load_sram("tb_data_v1/Wk.hex", 1);       
        load_sram("tb_data_v1/Wv.hex", 2);       
        $display("-> Initial Loading Complete!");
        $display("----------------------------------------");

        #20 rst_n = 1; 
        
        #10 system_start = 1;
        #10 system_start = 0;
        
        $display("STEP 2: CONTROLLER FSM STARTED...");
        $display("-> Computing multi-head attention... (Please wait)");

        fork
            wait(system_done == 1'b1);
            begin
                // Nới lỏng thời gian timeout vì MHA mất cực kì nhiều chu kỳ
                #50000000; 
                $display("[TIMEOUT] System took too long to finish!");
                $finish;
            end
        join_any
        disable fork;

        $display("-> COMPUTATION FINISHED!");
        $display("----------------------------------------");

        $display("STEP 3: CHECKING RESULTS:");
        //check_sram("tb_data_v1/E_h0_sram1_gold.hex", 1, "Matrix E_H0 = Q0 * K0^T (SRAM_1)");
        //check_sram("tb_data_v1/Attn_h0_sram1_gold_noTrans.hex", 2, "Matrix Attn_H0 = Softmax(E_0) (SRAM_2)");
        //check_sram("tb_data_v1/Attn_h0_sram1_gold.hex", 1, "Matrix Attn_H0^T = Softmax(E_0)^T (SRAM_1)");

        // check_sram("tb_data_v1/Q_sram3_gold.hex", 3, "Matrix Q (SRAM_3)"); // Đã bị Z ghi đè!
        
        //Kiểm tra dữ liệu Softmax MHA Head 1 (bị ghi đè trong SRAM 1)
        check_sram("tb_data_v1/Attn_h1_sram1_gold.hex", 1, "Matrix Softmax H1 (SRAM_1)");
        
        // Kiểm tra Z^T ghép nối 2 Head
        check_sram("tb_data_v1/Z_sram3_gold.hex", 3, "Matrix Z^T Fused (SRAM_3)");

        // // Kiểm tra Hàng Hoàn Chỉnh MHA OUT
        check_sram("tb_data_v1/MHA_out_sram0_gold.hex", 0, "Matrix MHA_OUT (SRAM_0)");
        $display("----------------------------------------");

        #50 $finish; 
    end

endmodule
