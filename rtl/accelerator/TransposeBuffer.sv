`timescale 1ns / 1ps


module TransposeBuffer #(parameter DATA_WIDTH = 8, parameter ARRAY_SIZE = 4) (
    input  logic                                  clk,
    input  logic                                  rst_n,
    
    // Control signals
    input  logic                                  load_en,
    input  logic [$clog2(ARRAY_SIZE)-1:0]         row_idx,
    input  logic [$clog2(ARRAY_SIZE)-1:0]         col_idx,
    
    // Data in (Row Vector)
    // Packed array 2D
    input  logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] data_in,
    
    // Out data (Col Vector)
    output logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] data_out
);

    // Array 2D (Buffer)
    // buffer[row][column]
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] buffer [ARRAY_SIZE];

    // Sequential block: Row-wise data loading
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear entire buffer on reset
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                buffer[i] <= '0;
            end
        end else if (load_en) begin
            // Load a full row vector into position row_idx
            buffer[row_idx] <= data_in;
        end
    end

    // Combinational block: Column-wise data read
    always_comb begin
        // Extract element col_idx from each row to form a column vector
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            data_out[i] = buffer[i][col_idx];
        end
    end

endmodule
