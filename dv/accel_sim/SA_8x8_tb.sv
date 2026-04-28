`timescale 1ns / 1ps

module SA_8x8_tb;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter ARRAY_SIZE = 8;

    logic clk = 0; logic rst_n = 0;
    
    // DUT Interface
    logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] vec_in_a, vec_in_b;
    logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_psum_in;
    logic valid_in, acc_clear, ws_mode, preload_w, update_w;
    logic [$clog2(ACC_WIDTH)-1:0] shift_amount = 0; // No shift for raw value check

    // DUT Outputs
    logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_psum_out_skewed;
    logic [ARRAY_SIZE-1:0] valid_out_skewed;
    logic signed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][DATA_WIDTH-1:0] out_row_aligned;
    logic [ARRAY_SIZE-1:0] valid_row_aligned;
    logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_ws_out_aligned;
    logic vec_ws_out_valid;

    SystolicArray #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(ARRAY_SIZE)) dut (.*);

    always #5 clk = ~clk;

    // --- RESULT MEMORY ---
    logic signed [ACC_WIDTH-1:0] Expected_C [0:7][0:7];
    logic signed [ACC_WIDTH-1:0] Hardware_C [0:7][0:7];
    int hw_row_idx;

    // --- AUTO DATA CAPTURE LOGIC ---
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            hw_row_idx <= 0;
            for(int i=0; i<8; i++) begin
                for(int j=0; j<8; j++) begin
                    Hardware_C[i][j] <= '0;
                end
            end
        end else begin
            // Capture OS results
            if (!ws_mode) begin
                for (int i = 0; i < ARRAY_SIZE; i++) begin
                    if (valid_row_aligned[i]) begin
                        for (int j = 0; j < ARRAY_SIZE; j++) begin
                            // Manual Sign-Extension to avoid Simulator artifacts
                            Hardware_C[i][j] <= { {24{out_row_aligned[i][j][DATA_WIDTH-1]}}, out_row_aligned[i][j] };
                        end
                    end
                end
            end
            // Capture WS results (row by row)
            else begin
                if (vec_ws_out_valid) begin
                    for (int j = 0; j < ARRAY_SIZE; j++) begin
                        Hardware_C[hw_row_idx][j] <= vec_ws_out_aligned[j];
                    end
                    hw_row_idx <= hw_row_idx + 1;
                end
            end
        end
    end

    // --- VERIFICATION & DISPLAY TASK ---
    task automatic check_and_display(input string mode_name);
        int errors = 0;
        $display("\n========================================================");
        $display("   VISUAL COMPARE - MODE: %s", mode_name);
        $display("========================================================");
        
        for (int i = 0; i < 8; i++) begin
            $write("Row %0d | HW: ", i);
            for (int j = 0; j < 8; j++) $write("%5d ", $signed(Hardware_C[i][j]));
            $display("");
            
            $write("      | SW: ");
            for (int j = 0; j < 8; j++) $write("%5d ", $signed(Expected_C[i][j]));
            $display("\n");
            
            // Auto error counting
            for (int j = 0; j < 8; j++) begin
                if (Hardware_C[i][j] !== Expected_C[i][j]) errors++;
            end
        end

        if (errors == 0) $display(">>> [SUCCESS] %s: 64/64 elements matched perfectly! <<<", mode_name);
        else $display(">>> [FAILED] %s: Detected %0d errors! <<<", mode_name, errors);
        $display("========================================================\n");
    endtask

    // --- SIMULATION SEQUENCE ---
    initial begin
        logic signed [DATA_WIDTH-1:0] A [0:7][0:7];
        logic signed [DATA_WIDTH-1:0] B [0:7][0:7];
        
        // 1. Init Test Data
        for(int i=0; i<8; i++) begin
            for(int j=0; j<8; j++) begin
                A[i][j] = $urandom_range(0, 6) - 3; 
                B[i][j] = $urandom_range(0, 6) - 3;
            end
        end

        // Calculate Expected_C (Software Model)
        for(int i=0; i<8; i++) begin
            for(int j=0; j<8; j++) begin
                Expected_C[i][j] = 0;
                for(int k=0; k<8; k++) Expected_C[i][j] += A[i][k] * B[k][j];
            end
        end

        vec_psum_in = '0; valid_in = 0; acc_clear = 0; preload_w = 0; update_w = 0;
        #20 rst_n = 1; #15;

        // ==========================================
        // TEST OS MODE
        // ==========================================
        ws_mode = 0;
        // Pump data
        for(int k=0; k<8; k++) begin
            @(posedge clk); #1; valid_in = 1;
            for(int i=0; i<8; i++) begin
                vec_in_a[i] = A[i][k];
                vec_in_b[i] = B[k][i];
            end
        end
        @(posedge clk); #1; valid_in = 0; acc_clear = 1; // Flush Psum
        @(posedge clk); #1; acc_clear = 0;
        
        repeat(20) @(posedge clk); // Wait for SA to flush results
        check_and_display("OUTPUT STATIONARY (OS)");

        // ==========================================
        // MODE TRANSITION
        // ==========================================
        // Toggle rst_n to clear Hardware_C and hw_row_idx automatically
        rst_n = 0; 
        #20 rst_n = 1; #15;

        // ==========================================
        // TEST WS MODE
        // ==========================================
        ws_mode = 1;
        // Preload Weight B into SA (Top to Bottom)
        for(int k=0; k<8; k++) begin
            @(posedge clk); #1; preload_w = 1;
            for(int i=0; i<8; i++) vec_in_b[i] = B[7-k][i];
        end
        @(posedge clk); #1; preload_w = 0; update_w = 1;
        @(posedge clk); #1; update_w = 0;

        // Pump Data A
        for(int k=0; k<8; k++) begin
            @(posedge clk); #1; valid_in = 1;
            for(int i=0; i<8; i++) vec_in_a[i] = A[k][i];
            vec_psum_in = '0; // 8x8 does not need top-down Psum feedback
        end
        @(posedge clk); #1; valid_in = 0;
        
        repeat(20) @(posedge clk); // Wait for results to stream out
        check_and_display("WEIGHT STATIONARY (WS)");

        $finish;
    end
endmodule