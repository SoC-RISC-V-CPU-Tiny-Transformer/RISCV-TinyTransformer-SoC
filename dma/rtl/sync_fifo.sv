import dma_pkg::*;

module sync_fifo #(
    parameter int WIDTH = 65, 
    parameter int DEPTH_L2 = 4
)(
    input  logic clk,
    input  logic rst_n,

    // Write
    input  logic wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic full,

    // Read
    input  logic rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic empty
);
    localparam DEPTH = 1 << DEPTH_L2;
    
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [DEPTH_L2:0] wr_ptr, rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[DEPTH_L2] != rd_ptr[DEPTH_L2]) && 
                   (wr_ptr[DEPTH_L2-1:0] == rd_ptr[DEPTH_L2-1:0]);

    always_ff @(posedge clk) begin
        if (wr_en && !full) begin
            mem[wr_ptr[DEPTH_L2-1:0]] <= wr_data;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (wr_en && !full) wr_ptr <= wr_ptr + 1'b1;
            if (rd_en && !empty) rd_ptr <= rd_ptr + 1'b1;
        end
    end

    assign rd_data = mem[rd_ptr[DEPTH_L2-1:0]];
endmodule
