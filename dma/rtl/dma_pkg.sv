package dma_pkg;
    // System & AXI-MM / Stream Data
    localparam DATA_WIDTH          = 64; 
    localparam ADDR_WIDTH          = 32; 
    localparam KEEP_WIDTH          = DATA_WIDTH / 8; // 64 bits = 8 bytes
    
    // AXI-Lite 
    localparam AXI_LITE_DATA_WIDTH = 32;
    localparam AXI_LITE_ADDR_WIDTH = 5; // 5 bits to map 5 registers (0x00, 0x04, 0x08, 0x0C, 0x10)

    // AXI Control Signals
    localparam AXI_LEN_WIDTH       = 8; // AXI4 burst length (AWLEN/ARLEN) 8 bits

    // FIFO
    localparam FIFO_DEPTH_LOG2     = 4; // Default depth log2
endpackage
