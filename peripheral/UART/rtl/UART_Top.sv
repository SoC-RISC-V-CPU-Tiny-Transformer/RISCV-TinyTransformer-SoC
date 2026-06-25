import UART_pkg::*;

module UART_Top 
(
    // SYSTEM BUS INTERFACE (AMBA APB)
    input  logic                    PCLK,      
    input  logic                    PRESETn,   
    input  logic [ADDR_WIDTH-1:0]   PADDR,     
    input  logic                    PSEL,      
    input  logic                    PENABLE,   
    input  logic                    PWRITE,    
    input  logic [DATA_WIDTH-1:0]   PWDATA,    
    output logic [DATA_WIDTH-1:0]   PRDATA,    
    output logic                    PREADY,    
    output logic                    PSLVERR,   

    // PHYSICAL INTERFACE 
    input  logic                    rx,        // Wire serial receive
    output logic                    tx         // Wire serial transmit
);

    // Internal Wires
    logic [DATA_WIDTH-1:0] w_data;
    logic                  wr_uart;
    logic                  tx_full;
    logic [DATA_WIDTH-1:0] r_data;
    logic                  rd_uart;
    logic                  rx_empty;
    logic                  BCLK;

    // APB SLAVE INTERFACE BLOCK
    APB_Slave apb_slave_inst (
        .PCLK      (PCLK),
        .PRESETn   (PRESETn),
        .PADDR     (PADDR),
        .PSEL      (PSEL),
        .PENABLE   (PENABLE),
        .PWRITE    (PWRITE),
        .PWDATA    (PWDATA),
        .PRDATA    (PRDATA),
        .PREADY    (PREADY),
        .PSLVERR   (PSLVERR),
        
        // Native signals
        .w_data    (w_data),
        .wr_uart   (wr_uart),
        .rd_uart   (rd_uart),
        .r_data    (r_data),
        .tx_full   (tx_full),
        .rx_empty  (rx_empty)
    );

    // BAUD GENERATOR
    Baud_Gen baud_generator_blk (
        .clk       (PCLK),     
        .reset_n   (PRESETn),
        .BCLK      (BCLK)
    );

    // TRANSMITTER BLOCK
    TX_Top tx_top_blk (
        .UCLK      (PCLK),
        .BCLK      (BCLK),
        .reset_n   (PRESETn),
        .W_data    (w_data),
        .wr_uart   (wr_uart),
        .tx_full   (tx_full),
        .tx        (tx)          
    );

    // RECEIVER BLOCK
    RX_Top rx_top_blk (
        .UCLK      (PCLK),
        .BCLK      (BCLK),
        .reset_n   (PRESETn),
        .rx        (rx),        
        .R_data    (r_data),
        .rd_uart   (rd_uart),
        .rx_empty  (rx_empty)
    );

endmodule
