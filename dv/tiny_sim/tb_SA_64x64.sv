`timescale 1ns / 1ps

module tb_SA_64x64;

    // --- CẤU HÌNH KÍCH THƯỚC ---
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter ARRAY_SIZE = 8;
    parameter MAT_SIZE = 64;
    parameter NUM_BLOCKS = MAT_SIZE / ARRAY_SIZE; // Số lượng khối trên mỗi chiều (64/8 = 8 khối)

    logic clk;
    logic rst_n;
    logic signed [DATA_WIDTH-1:0] vec_in_a [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] vec_in_b [ARRAY_SIZE-1:0];
    logic valid_in;
    logic acc_clear;
    logic [$clog2(ACC_WIDTH)-1:0] shift_amount;

    logic [DATA_WIDTH-1:0] out_row_aligned [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic valid_row_aligned [ARRAY_SIZE-1:0];

    // --- BỘ NHỚ LƯU TRỮ MA TRẬN 64x64 ---
    logic signed [DATA_WIDTH-1:0] A [0:MAT_SIZE-1][0:MAT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] B [0:MAT_SIZE-1][0:MAT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] Expected_C [0:MAT_SIZE-1][0:MAT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] Hardware_C [0:MAT_SIZE-1][0:MAT_SIZE-1];

    int error_count = 0;
    
    // Biến giao tiếp giữa luồng Test và luồng Giám sát
    int current_block_r = 0;
    int current_block_c = 0;

    SystolicArray #(
        .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(ARRAY_SIZE)
    ) dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; valid_in = 0; acc_clear = 0; 
        // 64 phần tử nhân cộng dồn có thể cho ra số khá lớn, dịch phải 3 bit (chia 8) để tránh bão hòa
        shift_amount = 3; 
        
        for(int i=0; i<ARRAY_SIZE; i++) begin vec_in_a[i]=0; vec_in_b[i]=0; end
        
        $display("\n========================================================");
        $display("   [TIẾN TRÌNH] Đang tạo và tính ma trận Software 64x64...");
        
        // 1. Khởi tạo ngẫu nhiên ma trận A và B (giá trị nhỏ từ -3 đến 3)
        for(int i=0; i<MAT_SIZE; i++) begin
            for(int j=0; j<MAT_SIZE; j++) begin
                A[i][j] = $urandom_range(0, 6) - 3;
                B[i][j] = $urandom_range(0, 6) - 3;
                Hardware_C[i][j] = '0; // Clear phần cứng
            end
        end

        // 2. Tính Expected C (Phần mềm)
        for(int i=0; i<MAT_SIZE; i++) begin
            for(int j=0; j<MAT_SIZE; j++) begin
                automatic logic signed [ACC_WIDTH-1:0] temp_acc = 0;
                automatic logic signed [ACC_WIDTH-1:0] shifted = 0;
                
                for(int k=0; k<MAT_SIZE; k++) begin
                    temp_acc += A[i][k] * B[k][j];
                end
                
                shifted = temp_acc >>> shift_amount;
                if (shifted > 127) Expected_C[i][j] = 127;
                else if (shifted < -128) Expected_C[i][j] = -128;
                else Expected_C[i][j] = shifted[7:0];
            end
        end
        $display("   [TIẾN TRÌNH] Hoàn thành tính Software. Bắt đầu bơm vào SA...");
        $display("========================================================\n");

        #20 rst_n = 1; #15;

        // 3. VÒNG LẶP CHẠY TỪNG KHỐI (TILING 8x8)
        // Duyệt qua 8 khối hàng và 8 khối cột (Tổng cộng 64 block)
        for (int br = 0; br < NUM_BLOCKS; br++) begin
            for (int bc = 0; bc < NUM_BLOCKS; bc++) begin
                
                current_block_r = br;
                current_block_c = bc;
                
                if (bc == 0) $display("[TIME %0t] Đang xử lý các block ở Hàng ma trận %0d...", $time, br);

                // Bơm K=64 phần tử vào SA để tính 1 khối 8x8
                for (int k = 0; k < MAT_SIZE; k++) begin
                    @(posedge clk); #1;
                    valid_in = 1; acc_clear = 0;
                    for (int i = 0; i < ARRAY_SIZE; i++) begin
                        // Map chỉ số hàng thực tế = Block_Row * 8 + i
                        vec_in_a[i] = A[br * ARRAY_SIZE + i][k];
                        // Map chỉ số cột thực tế = Block_Col * 8 + i
                        vec_in_b[i] = B[k][bc * ARRAY_SIZE + i];
                    end
                end

                // Bơm xong 64 số, Flush kết quả của Khối 8x8 này
                @(posedge clk); #1;
                valid_in = 0; acc_clear = 1;
                for (int i = 0; i < ARRAY_SIZE; i++) begin
                    vec_in_a[i] = 0; vec_in_b[i] = 0;
                end
                @(posedge clk); #1;
                acc_clear = 0;

                repeat(40) @(posedge clk); 
            end
        end

        // 4. KIỂM TRA TOÀN BỘ 4096 PHẦN TỬ
        $display("\n========================================================");
        $display("   [KIỂM TRA CHÉO] Đối chiếu Hardware C vs Expected C...");
        for (int i = 0; i < MAT_SIZE; i++) begin
            for (int j = 0; j < MAT_SIZE; j++) begin
                if (Hardware_C[i][j] !== Expected_C[i][j]) begin
                    if (error_count < 10) begin
                        $display("   -> [LỖI TẠI TỌA ĐỘ (%0d, %0d)] HW: %0d | SW: %0d", 
                                  i, j, $signed(Hardware_C[i][j]), $signed(Expected_C[i][j]));
                    end
                    error_count++;
                end
            end
        end

        if (error_count == 0)
            $display("[THÀNH CÔNG] Khớp toàn bộ 4096/4096 phần tử! SA xử lý Tiling chính xác");
        else
            $display("   [THẤT BẠI] Có tổng cộng %0d/%0d phần tử bị sai lệch.", error_count, MAT_SIZE*MAT_SIZE);
        $display("========================================================\n");
        $finish;
    end

    // --- MONITOR: BẮT DỮ LIỆU TỪ SA VÀ ĐIỀN VÀO MA TRẬN 64x64 ---
    always_ff @(posedge clk) begin
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            if (valid_row_aligned[i]) begin
                for (int j = 0; j < ARRAY_SIZE; j++) begin
                    // Tính tọa độ thực tế trong ma trận lớn 64x64
                    int real_r = current_block_r * ARRAY_SIZE + i;
                    int real_c = current_block_c * ARRAY_SIZE + j;
                    Hardware_C[real_r][real_c] <= out_row_aligned[i][j];
                end
            end
        end
    end

endmodule