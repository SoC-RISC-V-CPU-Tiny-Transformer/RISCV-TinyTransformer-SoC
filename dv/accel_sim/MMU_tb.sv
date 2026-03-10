`timescale 1ns / 1ps

module MMU_tb();

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter ARRAY_SIZE = 4;

    logic clk;
    logic rst_n;
    logic valid_in;
    logic acc_clear;
    logic [2:0] shift_amount;

    // ĐẦU VÀO PHẲNG (KHÔNG CẦN LỆCH PHA)
    logic signed [DATA_WIDTH-1:0] in_a_flat [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] in_b_flat [ARRAY_SIZE-1:0];
    
    logic signed [DATA_WIDTH-1:0] out_matrix [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic valid_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];

    MatrixMultUnit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .clear_acc(acc_clear),
        .shift_amount(shift_amount),
        .in_a(in_a_flat),
        .in_b(in_b_flat),
        .out_matrix(out_matrix),
        .valid_out(valid_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Ma trận nguồn
    logic signed [DATA_WIDTH-1:0] Matrix_X [3:0][3:0];
    logic signed [DATA_WIDTH-1:0] Matrix_W [3:0][3:0];

    initial begin
        // Khởi tạo ma trận (X toàn 2, W toàn 3 -> Kết quả kỳ vọng: 24)
        for(int i=0; i<4; i++) begin
            for(int j=0; j<4; j++) begin
                Matrix_X[i][j] = 8'd2; 
                Matrix_W[i][j] = 8'd3; 
            end
        end

        rst_n = 0;
        valid_in = 0;
        acc_clear = 0;
        shift_amount = 0;
        for(int i=0; i<4; i++) begin
            in_a_flat[i] = 0; in_b_flat[i] = 0;
        end

        #25 rst_n = 1;
        
        $display("=== BAT DAU BOM MA TRAN VUONG VAO MMU ===");
        
        // Chỉ cần ĐÚNG 4 NHỊP để bơm toàn bộ ma trận 4x4, thay vì 10 nhịp
        for(int t = 0; t < 4; t++) begin
            @(posedge clk);
            
            if (t == 0) acc_clear <= 1; 
            else acc_clear <= 0;
            
            valid_in <= 1;

            // Bơm cột thứ t của ma trận X và hàng thứ t của ma trận W
            for(int i=0; i<ARRAY_SIZE; i++) begin
                in_a_flat[i] <= Matrix_X[i][t];
                in_b_flat[i] <= Matrix_W[t][i];
            end
            
            $display("[Time %0t] Nhap cot X: %d %d %d %d  || Nhap hang W: %d %d %d %d", 
                     $time, Matrix_X[0][t], Matrix_X[1][t], Matrix_X[2][t], Matrix_X[3][t],
                            Matrix_W[t][0], Matrix_W[t][1], Matrix_W[t][2], Matrix_W[t][3]);
        end

        // Ngừng cấp dữ liệu
        @(posedge clk);
        valid_in <= 0;
        for(int i=0; i<ARRAY_SIZE; i++) begin
            in_a_flat[i] <= 0; in_b_flat[i] <= 0;
        end

        $display("\n... Dang cho MMU tu dong xu ly do tre Skewing ...");
        repeat(12) @(posedge clk);
        
        $display("\n=== KET QUA MA TRAN TAI MMU (Ky vong toan bo 24) ===");
        for(int i=0; i<ARRAY_SIZE; i++) begin
            $display("%d  %d  %d  %d", 
                out_matrix[i][0], out_matrix[i][1], out_matrix[i][2], out_matrix[i][3]);
        end
        
        $finish;
    end
endmodule