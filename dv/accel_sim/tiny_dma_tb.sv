import dma_pkg::*;

module tiny_dma_tb();

    // Clock & Reset
    logic clk, rst_n;

    // DMA Control Signals
    logic                           read_start_i;
    logic [AXI_ADDR_WIDTH-1:0]      read_base_addr_i;
    logic                           read_done_o;

    logic                           write_start_i;
    logic [AXI_ADDR_WIDTH-1:0]      write_base_addr_i;
    logic                           write_done_o;

    // SRAM Interface (DMA outputs & inputs)
    logic                           sram_we_o; 
    logic [AXI_DATA_WIDTH-1:0]      sram_wdata_o;
    logic [$clog2(TOTAL_BEATS)-1:0] sram_waddr_o; 

    logic                           sram_re_o; 
    logic [$clog2(TOTAL_BEATS)-1:0] sram_raddr_o;
    logic [AXI_DATA_WIDTH-1:0]      sram_rdata_i;

    // Dummy data for DMA to read from local SRAM and write to AXI RAM
    assign sram_rdata_i = {32'hDEADBEEF, 23'd0, sram_raddr_o};

    // AXI4 Bus Wires

    logic [AXI_ADDR_WIDTH-1:0]      m_axi_araddr;
    logic [7:0]                     m_axi_arlen;
    logic [2:0]                     m_axi_arsize;
    logic [1:0]                     m_axi_arburst;
    logic                           m_axi_arvalid;
    logic                           m_axi_arready;

    logic [AXI_DATA_WIDTH-1:0]      m_axi_rdata;
    logic [1:0]                     m_axi_rresp;
    logic                           m_axi_rlast;
    logic                           m_axi_rvalid;
    logic                           m_axi_rready;

    logic [AXI_ADDR_WIDTH-1:0]      m_axi_awaddr;
    logic [7:0]                     m_axi_awlen;
    logic [2:0]                     m_axi_awsize;
    logic [1:0]                     m_axi_awburst;
    logic                           m_axi_awvalid;
    logic                           m_axi_awready;

    logic [AXI_DATA_WIDTH-1:0]      m_axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0]    m_axi_wstrb;
    logic                           m_axi_wlast;
    logic                           m_axi_wvalid;
    logic                           m_axi_wready;

    logic [1:0]                     m_axi_bresp;
    logic                           m_axi_bvalid;
    logic                           m_axi_bready;

    // DUT DMA
    tiny_dma u_dma (
        .clk            (clk), 
        .rst_n          (rst_n),

        .read_start_i   (read_start_i), 
        .read_base_addr_i(read_base_addr_i), 
        .read_done_o    (read_done_o),

        .write_start_i  (write_start_i), 
        .write_base_addr_i(write_base_addr_i), 
        .write_done_o   (write_done_o),

        .sram_we_o      (sram_we_o), 
        .sram_waddr_o   (sram_waddr_o), 
        .sram_wdata_o   (sram_wdata_o),

        .sram_re_o      (sram_re_o), 
        .sram_raddr_o   (sram_raddr_o), 
        .sram_rdata_i   (sram_rdata_i),

        .m_axi_araddr   (m_axi_araddr), 
        .m_axi_arlen    (m_axi_arlen), 
        .m_axi_arsize   (m_axi_arsize), 
        .m_axi_arburst  (m_axi_arburst), 
        .m_axi_arvalid  (m_axi_arvalid), 
        .m_axi_arready  (m_axi_arready),

        .m_axi_rdata    (m_axi_rdata), 
        .m_axi_rresp    (m_axi_rresp), 
        .m_axi_rlast    (m_axi_rlast), 
        .m_axi_rvalid   (m_axi_rvalid), 
        .m_axi_rready   (m_axi_rready),

        .m_axi_awaddr   (m_axi_awaddr), 
        .m_axi_awlen    (m_axi_awlen), 
        .m_axi_awsize   (m_axi_awsize), 
        .m_axi_awburst  (m_axi_awburst), 
        .m_axi_awvalid  (m_axi_awvalid), 
        .m_axi_awready  (m_axi_awready),

        .m_axi_wdata    (m_axi_wdata), 
        .m_axi_wstrb    (m_axi_wstrb), 
        .m_axi_wlast    (m_axi_wlast), 
        .m_axi_wvalid   (m_axi_wvalid), 
        .m_axi_wready   (m_axi_wready),

        .m_axi_bresp    (m_axi_bresp), 
        .m_axi_bvalid   (m_axi_bvalid), 
        .m_axi_bready   (m_axi_bready)
    );

    // =========================================================
    // Standard AXI4 RAM (Alex Forencich)
    // =========================================================
    axi_ram #(
        .DATA_WIDTH(64),
        .ADDR_WIDTH(20), // 1MB Memory space to prevent simulation OOM
        .ID_WIDTH(8)
    ) u_ram (
        .clk            (clk),
        .rst            (~rst_n), // axi_ram uses active-HIGH reset

        // --- Write Address Channel ---
        .s_axi_awid     (8'd0),   // Hardcoded (Tie-off)
        .s_axi_awaddr   (m_axi_awaddr[19:0]), // Truncate 32-bit to 20-bit
        .s_axi_awlen    (m_axi_awlen),
        .s_axi_awsize   (m_axi_awsize),
        .s_axi_awburst  (m_axi_awburst),
        .s_axi_awlock   (1'b0),   
        .s_axi_awcache  (4'd0),   
        .s_axi_awprot   (3'd0),   
        .s_axi_awvalid  (m_axi_awvalid),
        .s_axi_awready  (m_axi_awready),

        // --- Write Data Channel ---
        .s_axi_wdata    (m_axi_wdata),
        .s_axi_wstrb    (m_axi_wstrb),
        .s_axi_wlast    (m_axi_wlast),
        .s_axi_wvalid   (m_axi_wvalid),
        .s_axi_wready   (m_axi_wready),

        // --- Write Response Channel ---
        .s_axi_bid      (),       // Unused output
        .s_axi_bresp    (m_axi_bresp),
        .s_axi_bvalid   (m_axi_bvalid),
        .s_axi_bready   (m_axi_bready),

        // --- Read Address Channel ---
        .s_axi_arid     (8'd0),   // Hardcoded
        .s_axi_araddr   (m_axi_araddr[19:0]), // Truncate 32-bit to 20-bit
        .s_axi_arlen    (m_axi_arlen),
        .s_axi_arsize   (m_axi_arsize),
        .s_axi_arburst  (m_axi_arburst),
        .s_axi_arlock   (1'b0),   
        .s_axi_arcache  (4'd0),  
        .s_axi_arprot   (3'd0),   
        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),

        // --- Read Data Channel ---
        .s_axi_rid      (),       // Unused output
        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),
        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready)
    );

    // Clock generation
    initial begin 
        clk = 0; 
        forever #5 clk = ~clk; 
    end

    task automatic init_test_matrices();
        // Since axi_ram memory array is [DATA_WIDTH-1:0] mem [(2**VALID_ADDR_WIDTH)-1:0]
        // Address offset is purely based on Word index (64-bit per word)
        // 0x2000 bytes = 8192 bytes = 1024 words
        int base_word_idx[5] = '{0, 1024, 2048, 3072, 4096};
        
        $display("[TB] Loading 5 matrices via backdoor...");
        for (int m = 0; m < 5; m++) begin
            for (int beat = 0; beat < TOTAL_BEATS; beat++) begin 
                logic [63:0] dummy_data;
                dummy_data = {8'(m+1), 40'h0, 16'(beat)}; 
                // Directly write to internal memory of u_ram
                u_ram.mem[base_word_idx[m] + beat] = dummy_data;
            end
        end
        $display("[TB] Preload complete!");
    endtask

    // Test Sequence
    initial begin
        rst_n = 0; 
        read_start_i = 0; 
        write_start_i = 0;
        #20 rst_n = 1;

        // 1. Preload data
        init_test_matrices();
        #10;
          
        // 2. Read 5 matrices sequentially
        for (int i = 0; i < 5; i++) begin
            $display("[TB] --- Read Matrix %0d ---", i+1);
            read_base_addr_i = i * 'h2000; // 0x0000, 0x2000, ...
            
            read_start_i = 1; #10 read_start_i = 0; 
            
            wait(read_done_o == 1'b1);
            #20; 
        end
        
        // 3. Write 1 result matrix back
        $display("[TB] --- Write Result to RAM ---");
        write_base_addr_i = 'hA000; 
        
        write_start_i = 1; #10 write_start_i = 0;
        
        wait(write_done_o == 1'b1);
        
        #20;
        $display("[TB] --- Read the recorded Matrix ---");
        read_base_addr_i = 'hA000;
        
        read_start_i = 1; #10 read_start_i = 0; 
        
        wait(read_done_o == 1'b1);
        
        $display("[TB] Test completed successfully!");

        #100 $finish;
    end
endmodule
