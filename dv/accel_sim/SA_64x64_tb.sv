`timescale 1ns / 1ps

module SA_64x64_tb;
    // --- SIZE CONFIGURATION ---
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter ARRAY_SIZE = 8;
    parameter MAT_SIZE = 64;
    localparam NUM_BLOCKS = MAT_SIZE / ARRAY_SIZE;

    logic clk = 0; logic rst_n = 0;
    
    logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] vec_in_a, vec_in_b;
    logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_psum_in;
    logic valid_in, acc_clear, ws_mode, preload_w, update_w;
    
    // Bật tính năng Shift & Saturation (Chia 8)
    logic [$clog2(ACC_WIDTH)-1:0] shift_amount = 3; 

    logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_psum_out_skewed;
    logic [ARRAY_SIZE-1:0] valid_out_skewed;
    logic signed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][DATA_WIDTH-1:0] out_row_aligned;
    logic [ARRAY_SIZE-1:0] valid_row_aligned;
    logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_ws_out_aligned;
    logic vec_ws_out_valid;

    SystolicArray #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(ARRAY_SIZE)) dut (.*);
    always #5 clk = ~clk;

    // --- 64x64 MATRIX MEMORY ---
    logic signed [ACC_WIDTH-1:0] Expected_C [0:MAT_SIZE-1][0:MAT_SIZE-1];
    logic signed [ACC_WIDTH-1:0] Hardware_C [0:MAT_SIZE-1][0:MAT_SIZE-1];
    
    int current_br = 0, current_bc = 0;

    // --- VIRTUAL FIFO FOR WS FEEDBACK ---
    logic signed [ACC_WIDTH-1:0] psum_fifo [0:7][0:1023]; 
    int fifo_wr_ptr [0:7];
    int fifo_rd_ptr [0:7];
    logic fifo_clear = 0; // Tín hiệu an toàn để reset FIFO
    int out_row_counter;  // Bộ đếm hàng cho WS

    // --- MONITOR: AUTO CAPTURE & FIFO MANAGEMENT ---
    always_ff @(posedge clk) begin
        if (!rst_n || fifo_clear) begin
            out_row_counter <= 0;
            for(int i=0; i<8; i++) fifo_wr_ptr[i] <= 0;
            
            if(!rst_n) begin
                for(int i=0; i<MAT_SIZE; i++) begin
                    for(int j=0; j<MAT_SIZE; j++) begin
                        Hardware_C[i][j] <= '0;
                    end
                end
            end
        end else begin
            // 1. Capture OS results (Shift & Saturation already done in MAC)
            if (!ws_mode) begin
                for (int i = 0; i < ARRAY_SIZE; i++) begin
                    if (valid_row_aligned[i]) begin
                        for (int j = 0; j < ARRAY_SIZE; j++) begin
                            // Manual Sign Extension
                            Hardware_C[current_br*8 + i][current_bc*8 + j] <= { {24{out_row_aligned[i][j][DATA_WIDTH-1]}}, out_row_aligned[i][j] };
                        end
                    end
                end
            end
            
            // 2. Capture WS results
            else begin
                // 2A. Write RAW 32-bit Psum to FIFO
                for(int j=0; j<ARRAY_SIZE; j++) begin
                    if(valid_out_skewed[j]) begin
                        psum_fifo[j][fifo_wr_ptr[j]] <= vec_psum_out_skewed[j];
                        fifo_wr_ptr[j] <= fifo_wr_ptr[j] + 1;
                    end
                end
                
                // 2B. Capture FINAL output, simulate Shift & Saturation
                if (vec_ws_out_valid) begin
                    for (int j = 0; j < ARRAY_SIZE; j++) begin
                        automatic logic signed [ACC_WIDTH-1:0] shifted_ws = $signed(vec_ws_out_aligned[j]) >>> shift_amount;
                        automatic logic signed [DATA_WIDTH-1:0] sat_ws;
                        
                        // Lượng tử hóa (Saturation)
                        if (shifted_ws > 127) sat_ws = 127;
                        else if (shifted_ws < -128) sat_ws = -128;
                        else sat_ws = shifted_ws[DATA_WIDTH-1:0];

                        // Kéo giãn bit dấu (Sign Extension) và lưu vào bộ nhớ
                        Hardware_C[out_row_counter][current_bc*8 + j] <= { {24{sat_ws[DATA_WIDTH-1]}}, sat_ws };
                    end
                    
                    if(out_row_counter == MAT_SIZE - 1) out_row_counter <= 0;
                    else out_row_counter <= out_row_counter + 1;
                end
            end
        end
    end

    // --- SMART DISPLAY TASK ---
    task automatic check_and_display(input string mode_name);
        int errors = 0;
        $display("\n========================================================");
        $display("   VISUAL COMPARE - %s (Showing first 8 Columns)", mode_name);
        $display("========================================================");
        
        for (int i = 0; i < MAT_SIZE; i++) begin
            for (int j = 0; j < MAT_SIZE; j++) begin
                if (Hardware_C[i][j] !== Expected_C[i][j]) errors++;
            end

            // Print top 4 rows and bottom 4 rows only
            if (i < 4 || i >= MAT_SIZE - 4) begin
                $write("Row %2d | HW: ", i);
                for (int j = 0; j < 8; j++) $write("%5d ", $signed(Hardware_C[i][j]));
                $display("...");
                
                $write("       | SW: ");
                for (int j = 0; j < 8; j++) $write("%5d ", $signed(Expected_C[i][j]));
                $display("...\n");
            end
            if (i == 4) $display("         ... [HIDDEN 56 MIDDLE ROWS] ...\n");
        end

        if (errors == 0) $display(">>> [SUCCESS] %s: All 4096/4096 elements match perfectly! <<<", mode_name);
        else $display(">>> [FAILED] %s: Detected %0d mismatched elements! <<<", mode_name, errors);
        $display("========================================================\n");
    endtask

    // --- SIMULATION SEQUENCE ---
    initial begin
        logic signed [DATA_WIDTH-1:0] A [0:MAT_SIZE-1][0:MAT_SIZE-1];
        logic signed [DATA_WIDTH-1:0] B [0:MAT_SIZE-1][0:MAT_SIZE-1];

        // Init Data & Compute Expected_C
        for(int i=0; i<MAT_SIZE; i++) begin
            for(int j=0; j<MAT_SIZE; j++) begin
                A[i][j] = $urandom_range(0, 6) - 3;
                B[i][j] = $urandom_range(0, 6) - 3;
                Expected_C[i][j] = 0;
            end
        end
        
        for(int i=0; i<MAT_SIZE; i++) begin
            for(int j=0; j<MAT_SIZE; j++) begin
                automatic logic signed [ACC_WIDTH-1:0] temp_acc = 0;
                automatic logic signed [ACC_WIDTH-1:0] shifted = 0;
                for(int k=0; k<MAT_SIZE; k++) temp_acc += A[i][k] * B[k][j];
                
                shifted = temp_acc >>> shift_amount;
                if (shifted > 127) Expected_C[i][j] = 127;
                else if (shifted < -128) Expected_C[i][j] = -128;
                else Expected_C[i][j] = $signed(shifted[DATA_WIDTH-1:0]);
            end
        end

        vec_psum_in = '0; valid_in = 0; acc_clear = 0; preload_w = 0; update_w = 0;
        #20 rst_n = 1; #15;

        // ==========================================
        // WS MODE 64x64 EXECUTION
        // ==========================================
        ws_mode = 1; 
        
        for(int bc=0; bc<NUM_BLOCKS; bc++) begin
            current_bc = bc;
            
            // Dọn dẹp FIFO trước khi tính 1 Cột Block mới
            @(posedge clk); #1; fifo_clear = 1;
            for(int i=0; i<8; i++) fifo_rd_ptr[i] = 0; 
            @(posedge clk); #1; fifo_clear = 0;

            for(int bk=0; bk<NUM_BLOCKS; bk++) begin
                // 1. Nạp Weight B (Top-down)
                for(int k=0; k<8; k++) begin
                    @(posedge clk); #1; preload_w = 1;
                    for(int i=0; i<8; i++) vec_in_b[i] = B[bk*8 + (7-k)][bc*8 + i];
                end
                @(posedge clk); #1; preload_w = 0; update_w = 1;
                @(posedge clk); #1; update_w = 0;

                // 2. Bơm toàn bộ 64 Hàng của ma trận A để che lấp độ trễ!
                for(int br=0; br<NUM_BLOCKS; br++) begin
                    for(int k=0; k<8; k++) begin
                        @(posedge clk); #1; valid_in = 1;
                        for(int i=0; i<8; i++) vec_in_a[i] = A[br*8 + k][bk*8 + i];

                        if(bk == 0) vec_psum_in = '0;
                        else begin
                            for(int j=0; j<8; j++) vec_psum_in[j] = psum_fifo[j][fifo_rd_ptr[j]];
                            for(int j=0; j<8; j++) fifo_rd_ptr[j]++;
                        end
                    end
                end
                @(posedge clk); #1; valid_in = 0;
                
                // Đợi Psum rớt hết vào FIFO rồi mới chuyển qua block bk tiếp theo
                repeat(30) @(posedge clk); 
            end
        end
        repeat(50) @(posedge clk); // Final flush
        check_and_display("WEIGHT STATIONARY (WS)");

        // ==========================================
        // MODE TRANSITION 
        // ==========================================
        rst_n = 0; 
        #20 rst_n = 1; #15;

        // ==========================================
        // OS MODE 64x64 EXECUTION
        // ==========================================
        ws_mode = 0;
        for(int br=0; br<NUM_BLOCKS; br++) begin
            for(int bc=0; bc<NUM_BLOCKS; bc++) begin
                current_br = br; current_bc = bc;
                
                for(int bk=0; bk<NUM_BLOCKS; bk++) begin
                    for(int k=0; k<8; k++) begin
                        @(posedge clk); #1; valid_in = 1;
                        for(int i=0; i<8; i++) begin
                            vec_in_a[i] = A[br*8 + i][bk*8 + k];
                            vec_in_b[i] = B[bk*8 + k][bc*8 + i];
                        end
                    end
                    @(posedge clk); #1; valid_in = 0;
                end
                @(posedge clk); #1; acc_clear = 1; // Flush
                @(posedge clk); #1; acc_clear = 0;
                repeat(20) @(posedge clk); 
            end
        end
        
        check_and_display("OUTPUT STATIONARY (OS)");
        $finish;
    end
endmodule