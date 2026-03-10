`timescale 1ns / 1ps

module SA_tb();

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter ARRAY_SIZE = 4;

    logic clk;
    logic rst_n;
    logic valid_in;
    logic acc_clear;
    logic [2:0] shift_amount;

    logic signed [DATA_WIDTH-1:0] in_a [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] in_b [ARRAY_SIZE-1:0];
    
    logic signed [DATA_WIDTH-1:0] out_matrix [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic valid_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];

    SystolicArray #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .clear_acc(acc_clear),
        .shift_amount(shift_amount),
        .in_a(in_a),
        .in_b(in_b),
        .out_matrix(out_matrix),
        .valid_out(valid_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Ma trận nguồn chưa lệch pha (Dạng vuông 4x4)
    logic signed [DATA_WIDTH-1:0] Matrix_X [3:0][3:0];
    logic signed [DATA_WIDTH-1:0] Matrix_W [3:0][3:0];

    initial begin
        // Khởi tạo 2 ma trận vuông
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
            in_a[i] = 0; in_b[i] = 0;
        end

        #25 rst_n = 1;
        
        $display("--- BAT DAU BOM DU LIEU LECH PHA (SKEWING) VÀO MANG 4x4 ---");
        
        // Tổng số chu kỳ cần để dữ liệu chảy hết qua mảng = K + (ARRAY_SIZE - 1) * 2 = 4 + 6 = 10 chu kỳ
        for(int t = 0; t < 12; t++) begin
            @(posedge clk);
            
            // Cờ clear chỉ bật lên ở phần tử đầu tiên của vector
            // Vì dữ liệu bị lệch pha, mỗi hàng/cột sẽ có thời điểm clear khác nhau
            // Để đơn giản testbench, ta bật clear_acc trong 1 nhịp đầu lúc t=0 và mặc định FSM kiểm soát
            if (t == 0) acc_clear <= 1; else acc_clear <= 0;
            valid_in <= 1;

            // BƠM DỮ LIỆU VÀO LỀ TRÁI (X) VỚI ĐỘ TRỄ i
            for(int i=0; i<ARRAY_SIZE; i++) begin
                // Nếu thời gian t nằm trong khung thời gian của hàng i
                if (t >= i && t < i + 4) 
                    in_a[i] <= Matrix_X[i][t - i];
                else 
                    in_a[i] <= 0; // Độn số 0 (Zero-padding)
            end

            // BƠM DỮ LIỆU VÀO LỀ TRÊN (W) VỚI ĐỘ TRỄ j
            for(int j=0; j<ARRAY_SIZE; j++) begin
                if (t >= j && t < j + 4) 
                    in_b[j] <= Matrix_W[t - j][j];
                else 
                    in_b[j] <= 0;
            end
            
            $display("[Time: %0t] Nhap vao -> in_a: %d %d %d %d | in_b: %d %d %d %d", 
                     $time, in_a[0], in_a[1], in_a[2], in_a[3], in_b[0], in_b[1], in_b[2], in_b[3]);
        end

        // Ngừng cấp dữ liệu
        @(posedge clk);
        valid_in <= 0;

        repeat(10) @(posedge clk);
        
        $display("--- KET QUA MA TRAN 4x4 (Ky vong toan bo la 24) ---");
        for(int i=0; i<ARRAY_SIZE; i++) begin
            $display("%d  %d  %d  %d", 
                out_matrix[i][0], out_matrix[i][1], out_matrix[i][2], out_matrix[i][3]);
        end
        
        $finish;
    end
endmodule