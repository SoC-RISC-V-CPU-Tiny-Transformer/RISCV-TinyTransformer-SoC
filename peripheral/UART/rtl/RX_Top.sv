import UART_pkg::*;

module RX_Top (

    input  logic                  UCLK,       // System Clock 
    input  logic                  BCLK,       // Baud Clock 
    input  logic                  reset_n,    // Global Reset (Active low)

    input  logic                  rx,         

    // (SYSTEM BUS)
    input  logic                  rd_uart,    
    output logic [DATA_WIDTH-1:0] R_data,     // Ouput
    output logic                  rx_empty    
);

    // Internal Wires
    logic [DATA_WIDTH-1:0] rx_dout;   
    logic                  full;       

    // SERIAL (UART RX)
    RX rx_blk (
        .BCLK       (BCLK),
        .reset_n    (reset_n),
        .rx         (rx),
        .rx_write   (full),       
        .rx_dout    (rx_dout),
        .rx_done_tk (rx_done_tk)
    );

    // ASYNC FIFO
    // BCLK & UCLK
    async_fifo #(
        .ADDR_WIDTH (4)           
    ) rx_fifo (
        .wclk       (BCLK),
        .wreset_n   (reset_n),
        .winc       (rx_done_tk), 
        .wdata      (rx_dout),
        .wfull      (full),

        .rclk       (UCLK),
        .rreset_n   (reset_n),
        .rinc       (rd_uart),    
        .rdata      (R_data),
        .rempty     (rx_empty)
    );

endmodule
