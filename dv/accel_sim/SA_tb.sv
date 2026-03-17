`timescale 1ns / 1ps

module SA_tb;

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter ARRAY_SIZE = 8;

    logic clk;
    logic rst_n;
    logic signed [DATA_WIDTH-1:0] vec_in_a [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] vec_in_b [ARRAY_SIZE-1:0];
    logic valid_in;
    logic acc_clear;
    logic [$clog2(ACC_WIDTH)-1:0] shift_amount;

    logic [DATA_WIDTH-1:0] out_row_aligned [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic valid_row_aligned [ARRAY_SIZE-1:0];

    // Các biến dùng cho Software Model
    logic signed [DATA_WIDTH-1:0] A [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] B [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [ACC_WIDTH-1:0]  Expected_Acc [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0]; // Kết quả cộng dồn 32-bit
    logic signed [DATA_WIDTH-1:0] Expected_Out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0]; // Kết quả 8-bit sau Shift & Saturation

    int error_count = 0;

    SystolicArray #(
        .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(ARRAY_SIZE)
    ) dut (
        .* // Tự động nối các port có cùng tên
    );

    always #5 clk = ~clk;

    // --- TASK: CHẠY MỘT KỊCH BẢN (TESTCASE) ---
    task run_testcase(input string tc_name, input int shift_val, input int mode);
        $display("\n========================================================");
        $display(">>> BẮT ĐẦU TESTCASE: %s <<<", tc_name);
        $display("Shift Amount = %0d", shift_val);
        
        shift_amount = shift_val;

        // 1. Sinh ma trận ngẫu nhiên dựa trên Mode
        for(int i=0; i<ARRAY_SIZE; i++) begin
            for(int j=0; j<ARRAY_SIZE; j++) begin
                case(mode)
                    0: begin // Nhỏ, âm dương lẫn lộn
                        A[i][j] = $urandom_range(0, 6) - 3; 
                        B[i][j] = $urandom_range(0, 6) - 3;
                    end
                    1: begin // Rất lớn dương (Gây Saturation +)
                        A[i][j] = $urandom_range(20, 40);
                        B[i][j] = $urandom_range(20, 40);
                    end
                    2: begin // Rất lớn âm (Gây Saturation -)
                        A[i][j] = $urandom_range(20, 40);
                        B[i][j] = -($urandom_range(20, 40));
                    end
                endcase
            end
        end

        // 2. Software Model: Tính toán Expected Matrix như cấu trúc MAC phần cứng
        for(int i=0; i<ARRAY_SIZE; i++) begin
            for(int j=0; j<ARRAY_SIZE; j++) begin
                Expected_Acc[i][j] = 0;
                for(int k=0; k<ARRAY_SIZE; k++) begin
                    Expected_Acc[i][j] += A[i][k] * B[k][j];
                end
                
                // Mô phỏng Stage 3: Shift & Saturation
                begin
                    automatic logic signed [ACC_WIDTH-1:0] shifted_val = Expected_Acc[i][j] >>> shift_val;
                    if (shifted_val > 127) 
                        Expected_Out[i][j] = 127;
                    else if (shifted_val < -128) 
                        Expected_Out[i][j] = -128;
                    else 
                        Expected_Out[i][j] = shifted_val[7:0];
                end
            end
        end

        // 3. Bơm dữ liệu vào SA
        for (int k = 0; k < ARRAY_SIZE; k++) begin
            @(posedge clk); #1;
            valid_in = 1; acc_clear = 0;
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                vec_in_a[i] = A[i][k];
                vec_in_b[i] = B[k][i];
            end
        end

        // 4. Chốt kết quả
        @(posedge clk); #1;
        valid_in = 0; acc_clear = 1; 
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            vec_in_a[i] = 0; vec_in_b[i] = 0;
        end
        @(posedge clk); #1;
        acc_clear = 0;

        // 5. Chờ đủ thời gian để SA nhả hết 8 hàng ra
        // (Thời gian trôi qua array 8x8 cỡ 25-30 chu kỳ, đợi 40 chu kỳ cho an toàn)
        repeat(40) @(posedge clk);
        $display("<<< HOÀN THÀNH TESTCASE: %s >>>", tc_name);
    endtask

    initial begin
        clk = 0; rst_n = 0; valid_in = 0; acc_clear = 0; shift_amount = 0;
        for(int i=0; i<ARRAY_SIZE; i++) begin vec_in_a[i]=0; vec_in_b[i]=0; end
        
        #20 rst_n = 1; #15;

        // Chạy các Testcase
        run_testcase("TC1: So nho am duong", 0, 0);
        run_testcase("TC2: Tran so duong (Saturation Max)", 0, 1);
        run_testcase("TC3: Tran so am (Saturation Min)", 0, 2);
        run_testcase("TC4: So lon nhung dung Shift", 4, 1);

        $display("\n********************************************************");
        if (error_count == 0)
            $display("   [PASSED] TAT CA TESTCASE HOAN HAO!");
        else
            $display("   [FAILED] CO %0d LOI TRONG QUA TRINH TEST!", error_count);
        $display("********************************************************\n");
        $finish;
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            if (valid_row_aligned[i]) begin
                automatic bit row_pass = 1;
                $write("[TIME %0t] SA Row %0d: ", $time, i);
                
                // In ra kết quả nhận được
                for (int j = 0; j < ARRAY_SIZE; j++) begin
                    $write("%4d ", $signed(out_row_aligned[i][j]));
                    if (out_row_aligned[i][j] !== Expected_Out[i][j]) begin
                        row_pass = 0;
                    end
                end
                
                // So sánh và báo lỗi chi tiết
                if (row_pass) begin
                    $display("  -> [OK]");
                end else begin
                    $display("  -> [ERROR]");
                    $write("           Expected : ");
                    for (int j = 0; j < ARRAY_SIZE; j++) begin
                        $write("%4d ", $signed(Expected_Out[i][j]));
                    end
                    $display("");
                    error_count++;
                end
            end
        end
    end

endmodule