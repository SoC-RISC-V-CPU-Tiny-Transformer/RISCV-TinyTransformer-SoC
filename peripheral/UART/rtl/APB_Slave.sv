import UART_pkg::*;

module APB_Slave 
(
    // AMBA APB INTERFACE 
    input  logic                    PCLK,    // Clock APB
    input  logic                    PRESETn, 
    input  logic [ADDR_WIDTH-1:0]   PADDR,   
    input  logic                    PSEL,    // Select signal for UART Slave
    input  logic                    PENABLE, 
    input  logic                    PWRITE,  // Write signal (1 = Write, 0 = Read)
    input  logic [DATA_WIDTH-1:0]   PWDATA,  // Data from CPU for writing
    output logic [DATA_WIDTH-1:0]   PRDATA,  // Data read back to CPU
    output logic                    PREADY,  
    output logic                    PSLVERR, // Bus error signal

    // NATIVE INTERFACE 
    output logic [DATA_WIDTH-1:0]   w_data,
    output logic                    wr_uart,
    output logic                    rd_uart,
    input  logic [DATA_WIDTH-1:0]   r_data,
    input  logic                    tx_full,
    input  logic                    rx_empty
);

    // Register Map
    localparam logic [ADDR_WIDTH-1:0] ADDR_DATA   = 8'h00; //  0x00
    localparam logic [ADDR_WIDTH-1:0] ADDR_STATUS = 8'h04; //  0x04

    // Write from APB to UART TX
    assign wr_uart = PSEL && PENABLE && PWRITE && (PADDR == ADDR_DATA);
    assign w_data  = PWDATA;

    // Read data from UART RX to APB
    assign rd_uart = PSEL && PENABLE && (!PWRITE) && (PADDR == ADDR_DATA);

    // Response data Bus APB
    always_comb begin
        PRDATA = '0;
        if (PSEL && !PWRITE) begin
            case (PADDR)
                ADDR_DATA: begin
                    PRDATA = r_data;
                end
                ADDR_STATUS: begin
                    // Pack status flags into the lower bits of PRDATA
                    // bit 1: rx_empty, bit 0: tx_full
                    PRDATA = {{DATA_WIDTH-2{1'b0}}, rx_empty, tx_full}; 
                end
                default: begin
                    PRDATA = '0; // Return 0 if CPU reads wrong address
                end
            endcase
        end
    end

    // PREADY = 1 (Zero-wait-state)
    assign PREADY  = 1'b1; 
    assign PSLVERR = 1'b0; // Return OK

endmodule
