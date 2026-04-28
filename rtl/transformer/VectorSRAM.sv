// `timescale 1ns / 1ps

// module VectorSRAM #(
//     parameter DATA_WIDTH = 8,
//     parameter ARRAY_SIZE = 8,
//     parameter ADDR_WIDTH = 9 // Độ sâu 512 ô nhớ (mỗi ô chứa 8 phần tử 8-bit)
// ) (
//     input logic clk,
    
//     // --- Port Write ---
//     input logic we,
//     input logic [ADDR_WIDTH-1:0] waddr,
//     input logic signed [DATA_WIDTH-1:0] wdata [ARRAY_SIZE-1:0],
    
//     // --- Port Read ---
//     input logic re,
//     input logic [ADDR_WIDTH-1:0] raddr,
//     output logic signed [DATA_WIDTH-1:0] rdata [ARRAY_SIZE-1:0]
// );

//     localparam DEPTH = 1 << ADDR_WIDTH;
//     localparam PACKED_WIDTH = DATA_WIDTH * ARRAY_SIZE;
    
//     (* ram_style = "block" *) logic [PACKED_WIDTH-1:0] ram [0:DEPTH-1];

//     // Biến trung gian để Gộp (Pack) và Tách (Unpack)
//     logic [PACKED_WIDTH-1:0] packed_wdata;
//     logic [PACKED_WIDTH-1:0] packed_rdata;

//     // Gộp mảng wdata bên ngoài thành dải bit dài để nhét vào BRAM
//     always_comb begin
//         for (int i = 0; i < ARRAY_SIZE; i++) begin
//             packed_wdata[i*DATA_WIDTH +: DATA_WIDTH] = wdata[i];
//         end
//     end

//     always_ff @(posedge clk) begin
//         if (we) begin
//             ram[waddr] <= packed_wdata;
//         end
//         if (re) begin
//             packed_rdata <= ram[raddr];
//         end
//     end

//     // Tách dải bit dài từ BRAM ra về lại mảng 2D cho Hệ thống
//     always_comb begin
//         for (int i = 0; i < ARRAY_SIZE; i++) begin
//             rdata[i] = packed_rdata[i*DATA_WIDTH +: DATA_WIDTH];
//         end
//     end

// endmodule


`timescale 1ns / 1ps

module VectorSRAM #(
    parameter DATA_WIDTH = 8,
    parameter ARRAY_SIZE = 8,
    parameter ADDR_WIDTH = 9 // Độ sâu 512 ô nhớ (mỗi ô chứa 8 phần tử 8-bit)
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