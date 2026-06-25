package UART_pkg;

    localparam DATA_WIDTH = 8; // 8 bits for UART data
    localparam OVERSAMPLE = 16; // Oversampling factor for UART receiver
    localparam DATA_BITS = $clog2(DATA_WIDTH);
    localparam ADDR_WIDTH = 4; // 4 bits for APB address space
endpackage
