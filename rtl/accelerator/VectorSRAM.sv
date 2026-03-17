`timescale 1ns / 1ps

module VectorSRAM #(
    parameter DATA_WIDTH = 8,
    parameter ARRAY_SIZE = 8,
    parameter ADDR_WIDTH = 10 // Độ sâu 1024 ô nhớ (mỗi ô chứa 4 phần tử 8-bit)
) (
    input logic clk,
    
    // --- Port Write ---
    input logic we,
    input logic [ADDR_WIDTH-1:0] waddr,
    input logic signed [DATA_WIDTH-1:0] wdata [ARRAY_SIZE-1:0],
    
    // --- Port Read ---
    input logic re,
    input logic [ADDR_WIDTH-1:0] raddr,
    output logic signed [DATA_WIDTH-1:0] rdata [ARRAY_SIZE-1:0]
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    
    // Khai báo bộ nhớ
    logic signed [DATA_WIDTH-1:0] ram [DEPTH-1:0][ARRAY_SIZE-1:0];

    always_ff @(posedge clk) begin
        if (we) begin
            ram[waddr] <= wdata;
        end
        
        if (re) begin
            if (we && (waddr == raddr)) begin
                // Nếu đang ghi và đọc CÙNG MỘT ĐỊA CHỈ -> đẩy thẳng dữ liệu mới ra
                rdata <= wdata;
            end else begin
                // Khác địa chỉ -> Đọc từ RAM như bình thường
                rdata <= ram[raddr];
            end
        end
    end

endmodule