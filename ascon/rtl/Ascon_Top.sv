`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 05/06/2026 06:20:58 PM
// Module Name: Ascon_Top
// Project Name: Ascon-AEAD128
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module Ascon_Top import ascon_pkg::*;
(
    input  logic        CLK,
    input  logic        RESETN,

    // S_AXI_LITE INTERFACE
    input  logic [7:0]  s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic [7:0]  s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // SLAVE AXI4-STREAM (Receive from DMA)
    input  logic        S_AXIS_TVALID,
    output logic        S_AXIS_TREADY,
    input  logic [63:0] S_AXIS_TDATA,
    input  logic        S_AXIS_TLAST,
    input  logic [7:0]  S_AXIS_TSTRB,
    input  logic [7:0]  S_AXIS_TKEEP,

    // MASTER AXI4-STREAM (Push data to DMA)
    output logic        M_AXIS_TVALID,
    input  logic        M_AXIS_TREADY,
    output logic [63:0] M_AXIS_TDATA,
    output logic        M_AXIS_TLAST,
    output logic [7:0]  M_AXIS_TSTRB,
    output logic [7:0]  M_AXIS_TKEEP
);

    // Register banks and ASCON Core
    logic         w_start;
    logic [1:0]   w_mode;
    logic         w_skip_asso;
    logic [127:0] w_key;
    logic [127:0] w_nonce;
    logic [127:0] w_in_tag;
    logic [127:0] w_out_tag;
    logic         w_done;
    logic         w_success;

    logic [63:0]  w_core_message;
    logic [63:0]  w_core_cipher;

    // Stream Data Endianness Swap
    assign w_core_message = S_AXIS_TDATA;
    assign M_AXIS_TDATA   = w_core_cipher;
    
    // Bypass TKEEP, TSTRB
    assign M_AXIS_TSTRB = S_AXIS_TSTRB; 
    assign M_AXIS_TKEEP = S_AXIS_TKEEP;

    // INSTANTIATE CONTROL REGISTERS
    AxiLite_Slave u_axilite (
        .CLK            (CLK),
        .RESETN         (RESETN),
        
        // AXI-Lite Ports
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        
        .core_start     (w_start),
        .core_mode      (w_mode),
        .core_skip_asso (w_skip_asso),
        .core_key       (w_key),
        .core_nonce     (w_nonce),
        .core_in_tag    (w_in_tag),
        .core_out_tag   (w_out_tag),
        .core_success   (w_success),
        .core_done      (w_done)
    );

    // INSTANTIATE ASCON CORE
    Ascon_Core u_core (
        .clk          (CLK),
        .reset_n      (RESETN),

        // Stream Interface
        .mess_valid   (S_AXIS_TVALID),
        .mess_pull    (S_AXIS_TREADY),
        .message      (w_core_message), 
        .mess_last    (S_AXIS_TLAST),
        
        .cipher_push  (M_AXIS_TVALID),
        .cipher_ready (M_AXIS_TREADY),
        .cipher       (w_core_cipher),  
        .cipher_last  (M_AXIS_TLAST),

        // Control & Registers
        .start        (w_start),
        .key          (w_key),
        .nonce        (w_nonce),
        .mode         (w_mode),
        .skip_asso    (w_skip_asso),
        .in_tag       (w_in_tag),
        .out_tag      (w_out_tag),
        .success_tag  (w_success),
        .done         (w_done)
    );

endmodule
