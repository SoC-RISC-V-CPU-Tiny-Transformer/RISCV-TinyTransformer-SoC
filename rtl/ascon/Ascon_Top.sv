`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 05/06/2026 06:20:58 PM
// Module Name: Ascon_Top
// Project Name: Ascon-AEAD128
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module Ascon_Top import ascon_pkg::*; (
    input  logic        CLK,
    input  logic        RESETN,

    // SLAVE AXI4-STREAM INTERFACE (input from DMA)
    input  logic        S_AXIS_TVALID,
    output logic        S_AXIS_TREADY,
    input  logic [63:0] S_AXIS_TDATA,
    input  logic        S_AXIS_TLAST,
    input  logic [7:0]  S_AXIS_TSTRB,
    input  logic [7:0]  S_AXIS_TKEEP,

    // MASTER AXI4-STREAM INTERFACE (output to DMA)
    output logic        M_AXIS_TVALID,
    input  logic        M_AXIS_TREADY,
    output logic [63:0] M_AXIS_TDATA,
    output logic        M_AXIS_TLAST,
    output logic [7:0]  M_AXIS_TSTRB,
    output logic [7:0]  M_AXIS_TKEEP,

    // SLAVE AXI4-LITE REGISTER BANK 
    input  logic         start,
    input  logic [127:0] key,
    input  logic [127:0] nonce,
    input  logic [1:0]   mode,
    input  logic         skip_asso,
    input  logic [127:0] in_tag,
    output logic [127:0] out_tag,
    output logic         success,
    output logic [255:0] hash,
    output logic         done
);

    assign M_AXIS_TSTRB = S_AXIS_TSTRB; // Bypass TSTRB
    assign M_AXIS_TKEEP = S_AXIS_TKEEP; // Bypass TKEEP

    Ascon_Core u_core (
        .clk        (CLK),
        .reset_n    (RESETN),

        // Map S_AXIS -> Slave Stream of Core
        .mess_valid (S_AXIS_TVALID),
        .mess_pull  (S_AXIS_TREADY),
        .message    (S_AXIS_TDATA),
        .mess_last  (S_AXIS_TLAST),

        // Map Core -> M_AXIS Master Stream
        .cipher_push  (M_AXIS_TVALID),
        .cipher_ready (M_AXIS_TREADY),
        .cipher       (M_AXIS_TDATA),
        .cipher_last  (M_AXIS_TLAST),

        // Map Control Registers
        .start       (start),
        .key         (key),
        .nonce       (nonce),
        .mode        (mode),
        .skip_asso   (skip_asso),
        .in_tag      (in_tag),
        .out_tag     (out_tag),
        .success_tag (success),
        .done        (done)
    );

endmodule
