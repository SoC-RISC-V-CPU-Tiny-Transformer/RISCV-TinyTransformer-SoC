import dma_pkg::*;

module tiny_dma (
    input logic clk,
    input logic rst_n,

    // Read Input/Weight from RAM
    input  logic                        read_start_i,
    input  logic [AXI_ADDR_WIDTH-1:0]   read_base_addr_i,
    output logic                        read_done_o,
    
    // Write output into RAM
    input  logic                        write_start_i,
    input  logic [AXI_ADDR_WIDTH-1:0]   write_base_addr_i,
    output logic                        write_done_o,

    // Write input/weight into SRAM (Read from AXI)
    output logic                        sram_we_o, // enable
    output logic [$clog2(TOTAL_BEATS)-1:0] sram_waddr_o, // 9 bits for 512 beats
    output logic [AXI_DATA_WIDTH-1:0]   sram_wdata_o,

    // Read output from SRAM to write
    output logic                        sram_re_o,
    output logic [$clog2(TOTAL_BEATS)-1:0] sram_raddr_o, // 9 bits for 512 beats
    input  logic [AXI_DATA_WIDTH-1:0]   sram_rdata_i,

    // AXI4 Master Interface
    // AR channel
    output logic [AXI_ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [7:0]                  m_axi_arlen,
    output logic [2:0]                  m_axi_arsize,
    output logic [1:0]                  m_axi_arburst,
    output logic                        m_axi_arvalid,
    input  logic                        m_axi_arready,

    // R channel
    input  logic [AXI_DATA_WIDTH-1:0]   m_axi_rdata,
    input  logic [1:0]                  m_axi_rresp,
    input  logic                        m_axi_rlast,
    input  logic                        m_axi_rvalid,
    output logic                        m_axi_rready,

    // AW channel
    output logic [AXI_ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [7:0]                  m_axi_awlen,
    output logic [2:0]                  m_axi_awsize,
    output logic [1:0]                  m_axi_awburst,
    output logic                        m_axi_awvalid,
    input  logic                        m_axi_awready,

    // W channel
    output logic [AXI_DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output logic                        m_axi_wlast,
    output logic                        m_axi_wvalid,
    input  logic                        m_axi_wready,

    // B channel
    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    output logic                        m_axi_bready
);

    // Read FSM (AXI R-> SRAM Write)
    typedef enum logic [1:0] {R_IDLE, R_SEND_AR, R_RECV_DATA, R_DONE} r_state_t;
    r_state_t r_state_q, r_state_d;
    
    logic [AXI_ADDR_WIDTH-1:0] r_addr_q, r_addr_d;
    logic [$clog2(NUM_BURSTS):0] r_burst_cnt_q, r_burst_cnt_d;
    logic [$clog2(TOTAL_BEATS)-1:0] sram_waddr_q, sram_waddr_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state_q     <= R_IDLE;
            r_addr_q      <= '0;
            r_burst_cnt_q <= '0;
            sram_waddr_q  <= '0;
        end else begin
            r_state_q     <= r_state_d;
            r_addr_q      <= r_addr_d;
            r_burst_cnt_q <= r_burst_cnt_d;
            sram_waddr_q  <= sram_waddr_d;
        end
    end

    always_comb begin
        r_state_d     = r_state_q;
        r_addr_d      = r_addr_q;
        r_burst_cnt_d = r_burst_cnt_q;
        sram_waddr_d  = sram_waddr_q;
        
        m_axi_arvalid = 1'b0;
        m_axi_rready  = 1'b0;
        read_done_o   = 1'b0;
        
        // signal SRAM
        sram_we_o     = 1'b0;

        case (r_state_q)
            R_IDLE: begin
                if (read_start_i) begin
                    r_addr_d      = read_base_addr_i;
                    r_burst_cnt_d = '0;
                    sram_waddr_d  = '0; // Reset address SRAM to 0 when start new matrix
                    r_state_d     = R_SEND_AR;
                end
            end
            R_SEND_AR: begin
                m_axi_arvalid = 1'b1;
                if (m_axi_arready) r_state_d = R_RECV_DATA;
            end
            R_RECV_DATA: begin
                m_axi_rready = 1'b1;
                
                if (m_axi_rvalid && m_axi_rready) begin
                    sram_we_o    = 1'b1;                // Enable write SRAM
                    sram_waddr_d = sram_waddr_q + 1'b1; // Inc pointer

                    if (m_axi_rlast) begin
                        r_burst_cnt_d = r_burst_cnt_q + 1'b1;
                        if (r_burst_cnt_d == NUM_BURSTS) begin
                            r_state_d = R_DONE;
                        end else begin
                            r_addr_d  = r_addr_q + BURST_OFFSET;
                            r_state_d = R_SEND_AR;
                        end
                    end
                end
            end
            R_DONE: begin
                read_done_o = 1'b1;
                r_state_d   = R_IDLE;
            end
            default: r_state_d = R_IDLE;
        endcase
    end

    assign m_axi_araddr  = r_addr_q;
    assign m_axi_arlen   = MAX_BURST_LEN - 1;
    assign m_axi_arsize  = AXI_SIZE_8BYTES;
    assign m_axi_arburst = AXI_BURST_INCR;
    
    // Output Data SRAM
    assign sram_waddr_o = sram_waddr_q;
    assign sram_wdata_o = m_axi_rdata;

    // Write FSM (SRAM Read -> AXI W) 
    typedef enum logic [2:0] {W_IDLE, W_SEND_AW, W_SEND_DATA, W_WAIT_B, W_DONE} w_state_t;
    w_state_t w_state_q, w_state_d;

    logic [AXI_ADDR_WIDTH-1:0] w_addr_q, w_addr_d;
    logic [$clog2(NUM_BURSTS):0] w_burst_cnt_q, w_burst_cnt_d;
    logic [$clog2(MAX_BURST_LEN):0] w_beat_cnt_q, w_beat_cnt_d;
    logic [$clog2(TOTAL_BEATS)-1:0] sram_raddr_q, sram_raddr_d;
    
    logic wdata_valid_q, wdata_valid_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state_q     <= W_IDLE;
            w_addr_q      <= '0;
            w_burst_cnt_q <= '0;
            w_beat_cnt_q  <= '0;
            sram_raddr_q  <= '0;
            wdata_valid_q <= 1'b0;
        end else begin
            w_state_q     <= w_state_d;
            w_addr_q      <= w_addr_d;
            w_burst_cnt_q <= w_burst_cnt_d;
            w_beat_cnt_q  <= w_beat_cnt_d;
            sram_raddr_q  <= sram_raddr_d;
            wdata_valid_q <= wdata_valid_d;
            
        end
    end

    always_comb begin
        w_state_d     = w_state_q;
        w_addr_d      = w_addr_q;
        w_burst_cnt_d = w_burst_cnt_q;
        w_beat_cnt_d  = w_beat_cnt_q;
        sram_raddr_d  = sram_raddr_q;
        wdata_valid_d = wdata_valid_q;
        
        m_axi_awvalid = 1'b0;
        m_axi_wvalid  = 1'b0;
        m_axi_wlast   = 1'b0;
        m_axi_bready  = 1'b0;
        write_done_o  = 1'b0;
        
        sram_re_o     = 1'b0;

        case (w_state_q)
            W_IDLE: begin
                if (write_start_i) begin
                    w_addr_d      = write_base_addr_i;
                    w_burst_cnt_d = '0;
                    w_beat_cnt_d  = '0;
                    sram_raddr_d  = '0;
                    w_state_d     = W_SEND_AW;
                end
            end
            W_SEND_AW: begin
                m_axi_awvalid = 1'b1;
                if (m_axi_awready) begin
                    // Read the first SRAM memory cell of the burst
                    sram_re_o     = 1'b1;
                    // sram_raddr_d  = sram_raddr_q + 1'b1;
                    wdata_valid_d = 1'b1; // The next cycle will have data
                    w_state_d     = W_SEND_DATA;
                end
            end
            W_SEND_DATA: begin
                // Data out to AXI
                if (wdata_valid_q) m_axi_wvalid = 1'b1;
                
                if (w_beat_cnt_q == MAX_BURST_LEN - 1) m_axi_wlast = 1'b1;

                if (m_axi_wvalid && m_axi_wready) begin
                    w_beat_cnt_d = w_beat_cnt_q + 1'b1;
                    
                    if (m_axi_wlast) begin
                        w_beat_cnt_d  = '0;
                        wdata_valid_d = 1'b0; // End burst
                        sram_raddr_d  = sram_raddr_q + 1'b1;
                        w_state_d     = W_WAIT_B;
                    end else begin
                        // Continue reading SRAM for the next AXI beat
                        sram_re_o    = 1'b1;
                        sram_raddr_d = sram_raddr_q + 1'b1;
                    end
                end
            end
            W_WAIT_B: begin
                m_axi_bready = 1'b1;
                if (m_axi_bvalid) begin
                    w_burst_cnt_d = w_burst_cnt_q + 1'b1;
                    if (w_burst_cnt_d == NUM_BURSTS) begin
                        w_state_d = W_DONE;
                    end else begin
                        w_addr_d  = w_addr_q + BURST_OFFSET;
                        w_state_d = W_SEND_AW;
                    end
                end
            end
            W_DONE: begin
                write_done_o = 1'b1;
                w_state_d    = W_IDLE;
            end
            default: w_state_d = W_IDLE;
        endcase
    end

    assign m_axi_awaddr  = w_addr_q;
    assign m_axi_awlen   = MAX_BURST_LEN - 1;
    assign m_axi_awsize  = AXI_SIZE_8BYTES;
    assign m_axi_awburst = AXI_BURST_INCR;

    // Output AXI W channel
    assign m_axi_wdata  = sram_rdata_i;
    assign m_axi_wstrb  = 8'hFF;
    assign sram_raddr_o = sram_raddr_q;

endmodule
