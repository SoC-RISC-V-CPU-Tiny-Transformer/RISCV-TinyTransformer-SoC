package dma_pkg;
    // Config AXI Bus
    localparam int AXI_DATA_WIDTH = 64;
    localparam int AXI_ADDR_WIDTH = 32; // RAM 32-bit
    localparam int BYTES_PER_BEAT = AXI_DATA_WIDTH / 8; // 8 bytes

    // Config Matrix Ma 
    localparam int MATRIX_SIZE_BYTES = 4096; // 64x64 bytes
    localparam int TOTAL_BEATS       = MATRIX_SIZE_BYTES / BYTES_PER_BEAT; // 512 beats

    // Config Burst
    localparam int MAX_BURST_LEN     = 256; // MAX 256 beats for INCR mode
    localparam int NUM_BURSTS        = TOTAL_BEATS / MAX_BURST_LEN; // 2 bursts
    localparam int BURST_OFFSET      = MAX_BURST_LEN * BYTES_PER_BEAT; // Address distance between 2 burst (2048 bytes)

    // AXI Size code (3'b011 - 8 bytes / 64 bits)
    localparam logic [2:0] AXI_SIZE_8BYTES = 3'b011; 
    // AXI Burst type (2'b01 - INCR mode - Incrementing)
    localparam logic [1:0] AXI_BURST_INCR  = 2'b01;
endpackage
