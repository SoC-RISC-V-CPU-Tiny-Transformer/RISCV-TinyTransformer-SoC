`timescale 1ns / 1ps

module Transposer_tb();

    parameter DATA_WIDTH = 8;
    parameter ARRAY_SIZE = 8;
    parameter MAT_SIZE = 64;

    // Khai báo tín hiệu
    logic clk;
    logic rst_n;
    
    logic valid_in;
    logic [$clog2(ARRAY_SIZE)-1:0] in_row_idx;
    logic signed [DATA_WIDTH-1:0] in_row_data [ARRAY_SIZE-1:0];
    logic [$clog2(MAT_SIZE/ARRAY_SIZE)-1:0] in_br, in_bc;
    
    logic [$clog2(MAT_SIZE/ARRAY_SIZE)-1:0] out_br, out_bc;
    logic valid_out;
    logic [$clog2(ARRAY_SIZE)-1:0] out_col_idx;
    logic signed [DATA_WIDTH-1:0] out_col_data [ARRAY_SIZE-1:0];

    // Instantiate module (DUT)
    Transposer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .MAT_SIZE(MAT_SIZE)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .in_row_idx(in_row_idx), .in_row_data(in_row_data),
        .in_br(in_br), .in_bc(in_bc),
        .out_br(out_br), .out_bc(out_bc),
        .valid_out(valid_out), .out_col_idx(out_col_idx), .out_col_data(out_col_data)
    );

    // Tạo Clock (Chu kỳ 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Kịch bản Test (Stimulus)
    initial begin
        // 1. Reset hệ thống
        rst_n = 0;
        valid_in = 0;
        in_row_idx = 0;
        in_br = 0; in_bc = 0;
        for (int i = 0; i < ARRAY_SIZE; i++) in_row_data[i] = 0;
        
        #15; 
        rst_n = 1;
        @(posedge clk);

        $display("=== BAT DAU NAP BLOCK 1 (Tọa độ: br=0, bc=0) ===");
        // 2. Bơm Block 1 (Dữ liệu từ 10 đến 17 cho hàng 1, 20 đến 27 cho hàng 2...)
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            valid_in = 1;
            in_row_idx = i;
            in_br = 0; 
            in_bc = 0;
            for (int j = 0; j < ARRAY_SIZE; j++) begin
                in_row_data[j] = (i + 1) * 10 + j; 
            end
            
            $write("IN_ROW [%0d]: ", i);
            for (int j = 0; j < ARRAY_SIZE; j++) $write("%0d ", in_row_data[j]);
            $display("");
            
            @(posedge clk);
        end

        $display("=== BAT DAU NAP BLOCK 2 (Tọa độ: br=0, bc=1) LIEN TIEP ===");
        // 3. Bơm Block 2 ngay lập tức (Dữ liệu từ 110 đến 117...)
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            valid_in = 1;
            in_row_idx = i;
            in_br = 0; 
            in_bc = 1; // Thay đổi tọa độ
            for (int j = 0; j < ARRAY_SIZE; j++) begin
                in_row_data[j] = 100 + (i + 1) * 10 + j; 
            end
            
            $write("IN_ROW [%0d]: ", i);
            for (int j = 0; j < ARRAY_SIZE; j++) $write("%0d ", in_row_data[j]);
            $display("");
            
            @(posedge clk);
        end

        // 4. Dừng bơm dữ liệu, chờ xả hết
        valid_in = 0;
        #200;
        $display("=== KET THUC SIMULATION ===");
        $finish;
    end

    // Mạch Monitor tự động in kết quả ngõ ra
    always_ff @(negedge clk) begin
        if (valid_out) begin
            $write("OUT_COL [%0d] (br=%0d, bc=%0d): ", out_col_idx, out_br, out_bc);
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                $write("%0d ", out_col_data[i]);
            end
            $display("");
        end
    end

endmodule