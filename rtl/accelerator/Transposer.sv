`timescale 1ns / 1ps

module Transposer #(
    parameter DATA_WIDTH = 8,
    parameter ARRAY_SIZE = 4,
    parameter ROW_WIDTH  = 2 // log2(ARRAY_SIZE)
)(
    input  logic clk,
    input  logic rst_n,
    
    input  logic trans_load_en,                 // Cờ cho phép nạp dữ liệu (Fill phase)
    input  logic [ROW_WIDTH-1:0] trans_row_idx, // Chỉ số hàng đang nạp (0 -> 3)
    input  logic [ROW_WIDTH-1:0] trans_col_idx, // Chỉ số cột đang xả (0 -> 3)
    
    input  logic signed [DATA_WIDTH-1:0] data_in  [ARRAY_SIZE-1:0],
    output logic signed [DATA_WIDTH-1:0] data_out [ARRAY_SIZE-1:0]
);
    logic signed [DATA_WIDTH-1:0] buffer [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];

    // =========================================================================
    // 1. Pha Nạp: Ghi từng hàng (Row) vào Buffer
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                for (int j = 0; j < ARRAY_SIZE; j++) begin
                    buffer[i][j] <= '0;
                end
            end
        end else if (trans_load_en) begin
            // Nạp nguyên 1 hàng vào vị trí trans_row_idx
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                buffer[trans_row_idx][i] <= data_in[i];
            end
        end
    end

    // =========================================================================
    // 2. Pha Xả: Đọc chéo từng cột (Column) ra (Combinational logic)
    // =========================================================================
    always_comb begin
        for (int k = 0; k < ARRAY_SIZE; k++) begin
            data_out[k] = buffer[k][trans_col_idx];
        end
    end

endmodule