import dma_pkg::*;

module axi_dma (
    input logic clk, rst_n,

    // S_AXI_LITE Write Channel
    input  logic [AXI_LITE_ADDR_WIDTH-1:0] s_axi_lite_awaddr,
    input  logic                           s_axi_lite_awvalid,
    output logic                           s_axi_lite_awready,
    input  logic [AXI_LITE_DATA_WIDTH-1:0] s_axi_lite_wdata,
    input  logic                           s_axi_lite_wvalid,
    output logic                           s_axi_lite_wready,
    output logic [1:0]                     s_axi_lite_bresp,
    output logic                           s_axi_lite_bvalid,
    input  logic                           s_axi_lite_bready,

    // S_AXI_LITE Read Channel
    input  logic [AXI_LITE_ADDR_WIDTH-1:0] s_axi_lite_araddr,
    input  logic                           s_axi_lite_arvalid,
    output logic                           s_axi_lite_arready,
    output logic [AXI_LITE_DATA_WIDTH-1:0] s_axi_lite_rdata,
    output logic [1:0]                     s_axi_lite_rresp,
    output logic                           s_axi_lite_rvalid,
    input  logic                           s_axi_lite_rready,

    // M_AXI_MM2S (Read Channel)
    output logic [ADDR_WIDTH-1:0]          m_axi_mm2s_araddr,
    output logic [AXI_LEN_WIDTH-1:0]       m_axi_mm2s_arlen,
    output logic                           m_axi_mm2s_arvalid,
    input  logic                           m_axi_mm2s_arready,
    input  logic [DATA_WIDTH-1:0]          m_axi_mm2s_rdata,
    input  logic                           m_axi_mm2s_rlast,
    input  logic                           m_axi_mm2s_rvalid,
    output logic                           m_axi_mm2s_rready,

    // M_AXIS_MM2S (Stream to ASCON)
    output logic [DATA_WIDTH-1:0]          m_axis_mm2s_tdata,
    output logic [KEEP_WIDTH-1:0]          m_axis_mm2s_tstrb,
    output logic [KEEP_WIDTH-1:0]          m_axis_mm2s_tkeep,
    output logic                           m_axis_mm2s_tvalid,
    input  logic                           m_axis_mm2s_tready,
    output logic                           m_axis_mm2s_tlast,

    // M_AXI_S2MM (Write Channel)
    output logic [ADDR_WIDTH-1:0]          m_axi_s2mm_awaddr,
    output logic [AXI_LEN_WIDTH-1:0]       m_axi_s2mm_awlen,
    output logic                           m_axi_s2mm_awvalid,
    input  logic                           m_axi_s2mm_awready,
    output logic [DATA_WIDTH-1:0]          m_axi_s2mm_wdata,
    output logic [KEEP_WIDTH-1:0]          m_axi_s2mm_wstrb, 
    output logic                           m_axi_s2mm_wlast,
    output logic                           m_axi_s2mm_wvalid,
    input  logic                           m_axi_s2mm_wready,
    input  logic [1:0]                     m_axi_s2mm_bresp,
    input  logic                           m_axi_s2mm_bvalid,
    output logic                           m_axi_s2mm_bready,

    // S_AXIS_S2MM (Stream from ASCON)
    input  logic [DATA_WIDTH-1:0]          s_axis_s2mm_tdata,
    input  logic [KEEP_WIDTH-1:0]          s_axis_s2mm_tstrb,
    input  logic [KEEP_WIDTH-1:0]          s_axis_s2mm_tkeep,
    input  logic                           s_axis_s2mm_tvalid,
    output logic                           s_axis_s2mm_tready,
    input  logic                           s_axis_s2mm_tlast
);

    logic [ADDR_WIDTH-1:0] mm2s_src, mm2s_len, s2mm_dst, s2mm_len;
    logic mm2s_start, mm2s_done, s2mm_start, s2mm_done;

    dma_axi_lite_regs u_regs (
        .clk            (clk), 
        .rst_n          (rst_n),
        .awaddr         (s_axi_lite_awaddr), 
        .awvalid        (s_axi_lite_awvalid), 
        .awready        (s_axi_lite_awready),
        .wdata          (s_axi_lite_wdata), 
        .wvalid         (s_axi_lite_wvalid), 
        .wready         (s_axi_lite_wready),
        .bresp          (s_axi_lite_bresp), 
        .bvalid         (s_axi_lite_bvalid), 
        .bready         (s_axi_lite_bready),

        // Mapping Read Channel
        .araddr         (s_axi_lite_araddr),
        .arvalid        (s_axi_lite_arvalid),
        .arready        (s_axi_lite_arready),
        .rdata          (s_axi_lite_rdata),
        .rresp          (s_axi_lite_rresp),
        .rvalid         (s_axi_lite_rvalid),
        .rready         (s_axi_lite_rready),

        .mm2s_src_addr  (mm2s_src), 
        .mm2s_length    (mm2s_len), 
        .mm2s_start     (mm2s_start), 
        .mm2s_done      (mm2s_done),
        .s2mm_dst_addr  (s2mm_dst), 
        .s2mm_length    (s2mm_len), 
        .s2mm_start     (s2mm_start), 
        .s2mm_done      (s2mm_done)
    );

    dma_mm2s u_mm2s (
        .clk            (clk), 
        .rst_n          (rst_n),
        .start          (mm2s_start), 
        .src_addr       (mm2s_src), 
        .length         (mm2s_len), 
        .done           (mm2s_done),

        .araddr         (m_axi_mm2s_araddr), 
        .arlen          (m_axi_mm2s_arlen), 
        .arvalid        (m_axi_mm2s_arvalid), 
        .arready        (m_axi_mm2s_arready),
        .rdata          (m_axi_mm2s_rdata), 
        .rlast          (m_axi_mm2s_rlast), 
        .rvalid         (m_axi_mm2s_rvalid), 
        .rready         (m_axi_mm2s_rready),

        .m_axis_tdata   (m_axis_mm2s_tdata), 
        .m_axis_tstrb   (m_axis_mm2s_tstrb),
        .m_axis_tkeep   (m_axis_mm2s_tkeep),
        .m_axis_tvalid  (m_axis_mm2s_tvalid), 
        .m_axis_tready  (m_axis_mm2s_tready), 
        .m_axis_tlast   (m_axis_mm2s_tlast)
    );

    dma_s2mm u_s2mm (
        .clk            (clk), 
        .rst_n          (rst_n),
        .start          (s2mm_start), 
        .dst_addr       (s2mm_dst), 
        .length         (s2mm_len), 
        .done           (s2mm_done),

        .awaddr         (m_axi_s2mm_awaddr), 
        .awlen          (m_axi_s2mm_awlen), 
        .awvalid        (m_axi_s2mm_awvalid), 
        .awready        (m_axi_s2mm_awready),
        .wdata          (m_axi_s2mm_wdata), 
        .wstrb          (m_axi_s2mm_wstrb),
        .wlast          (m_axi_s2mm_wlast), 
        .wvalid         (m_axi_s2mm_wvalid), 
        .wready         (m_axi_s2mm_wready),
        .bresp          (m_axi_s2mm_bresp), 
        .bvalid         (m_axi_s2mm_bvalid), 
        .bready         (m_axi_s2mm_bready),

        .s_axis_tdata   (s_axis_s2mm_tdata), 
        .s_axis_tstrb   (s_axis_s2mm_tstrb),
        .s_axis_tkeep   (s_axis_s2mm_tkeep),
        .s_axis_tvalid  (s_axis_s2mm_tvalid), 
        .s_axis_tready  (s_axis_s2mm_tready), 
        .s_axis_tlast   (s_axis_s2mm_tlast)
    );
endmodule
