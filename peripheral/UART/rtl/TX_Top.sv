import UART_pkg::*;

module TX_Top (

    input  logic                  UCLK,       // System Clock (CPU)
    input  logic                  BCLK,       // Baud Clock 
    input  logic                  reset_n,      

    // SYSTEM BUS
    input  logic [DATA_WIDTH-1:0] W_data,     // Data from CPU
    input  logic                  wr_uart,    // Write command to FIFO
    output logic                  tx_full,    // FIFO full flag
    
    output logic                  tx          // UART LINE
);

    logic                  tx_done_tk; 
    logic [DATA_WIDTH-1:0] tx_din;     
    logic                  empty;      

    // SERIAL (UART TX)
    // BCLK (Slow Clock)
    TX tx_blk (
        .BCLK       (BCLK),
        .reset_n    (reset_n),
        .tx_start   (~empty),     
        .tx_din     (tx_din),
        .tx_done_tk (tx_done_tk),
        .tx         (tx)
    );

    // FIFO FOR UCLK (Quick) và BCLK (Slow)
    async_fifo #(
        .ADDR_WIDTH (4)           
    ) tx_fifo (
        .wclk       (UCLK),
        .wreset_n   (reset_n),
        .winc       (wr_uart),    // Start CPU
        .wdata      (W_data),     // Data from CPU
        .wfull      (tx_full),    // Full flag for CPU

        // Read Domain - UART TX reads very slowly
        .rclk       (BCLK),
        .rreset_n   (reset_n),
        .rinc       (tx_done_tk), 
        .rdata      (tx_din),     
        .rempty     (empty)       
    );

endmodule

    // you can use the fifo generator block that is in ip catalog in VIVADO and customize it
    /* fifo_generator_0 tx_fifo (
      .rst(reset_n),                  // input wire rst
      .wr_clk(UCLK),                // input wire wr_clk
      .rd_clk(BCLK),                // input wire rd_clk
      .din(W_data),                 // input wire [7 : 0] din
      .wr_en(wr_uart),              // input wire wr_en
      .rd_en(tx_done_tk),           // input wire rd_en
      .dout(tx_din),                // output wire [7 : 0] dout
      .full(tx_full),               // output wire full
      .empty(empty),                // output wire empty
      .wr_rst_busy(wr_rst_busy),    // output wire wr_rst_busy
      .rd_rst_busy(rd_rst_busy)     // output wire rd_rst_busy
    );*/
