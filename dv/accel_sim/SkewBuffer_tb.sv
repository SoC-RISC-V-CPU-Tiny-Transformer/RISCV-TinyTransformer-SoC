`timescale 1ns / 1ps

module SkewBuffer_tb();

    parameter DATA_WIDTH = 8;
    parameter ARRAY_SIZE = 4;

    logic clk;
    logic rst_n;
    logic signed [DATA_WIDTH-1:0] data_in  [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] data_out [ARRAY_SIZE-1:0];

    SkewBuffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Kịch bản
    initial begin
        rst_n = 0;
        for (int i = 0; i < ARRAY_SIZE; i++) data_in[i] = 0;
        
        #25 rst_n = 1;
        $display("--- BAT DAU TEST SKEW BUFFER ---");

        // Bơm dữ liệu vào trong 3 nhịp liên tiếp (Ví dụ các cột dữ liệu)
        for (int t = 1; t <= 3; t++) begin
            @(posedge clk);
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                data_in[i] <= t * 10; // Lần lượt bơm toàn 10, rồi toàn 20, rồi toàn 30
            end
            $display("[Time %0t] Nhap vao phang: %d %d %d %d", $time, data_in[0], data_in[1], data_in[2], data_in[3]);
        end

        // Ngừng cấp dữ liệu
        @(posedge clk);
        for (int i = 0; i < ARRAY_SIZE; i++) data_in[i] <= 0;

        // Chờ dữ liệu trôi ra hết
        repeat(8) @(posedge clk);
        $display("--- KET THUC TEST ---");
        $finish;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            $display("   -> [Time %0t] LO KET QUA RA: %d (tre 0), %d (tre 1), %d (tre 2), %d (tre 3)", 
                     $time, data_out[0], data_out[1], data_out[2], data_out[3]);
        end
    end

endmodule