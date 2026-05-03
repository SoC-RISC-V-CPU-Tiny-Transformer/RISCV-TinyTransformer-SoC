`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 04/28/2026 09:34:00 AM
// Module Name: Ascon_Core
// Project Name: ASCON_128
// Description: Top-level Wrapper connecting FSM, Datapath and Permutation
//////////////////////////////////////////////////////////////////////////////////

module Ascon_Core import ascon_pkg::*; (
    input  logic                    clk,
    input  logic                    rst_n,

    // CPU CONTROL (AXI4-Lite)
    input  logic                    start,          // 1 = Start encryption/decryption
    input  logic                    variant_128a,   // 0 = ASCON-128, 1 = ASCON-128a
    input  logic                    has_ad,         // 1 = Has AD
    input  logic                    has_msg,        // 1 = Has MSG
    input  logic                    decrypt_mode,   // 0 = Encryption, 1 = Decryption
    input  logic [127:0]            key,            
    input  logic [127:0]            nonce,          
    output logic                    done,          

    // DATA IN (From DMA / AXI4-Stream S_AXIS)
    input  logic [DATA_WIDTH-1:0]   cipher_in,       
    input  logic                    data_valid,     // DMA indicates valid data
    input  logic                    data_last,      // Last data packet (TLAST)
    input  logic [DATA_WIDTH/8-1:0] t_keep,         // Byte enable for padding
    output logic                    data_ready,    

    // DATA OUT (To DMA / AXI4-Stream M_AXIS)
    output logic [DATA_WIDTH-1:0]   cipher_out,      
    output logic [127:0]            tag_out,        
    output logic                    msg_valid,      // Output data is valid
    output logic                    tag_valid       // Output tag is valid
);

    // INTERNAL IV GENERATION 
    logic [63:0] internal_iv;
    assign internal_iv = (variant_128a) ? ASCON_128A_IV : ASCON_128_IV;

    // INTERNAL WIRES
    // FSM <-> Datapath
    logic state_update, sel_iv;
    logic absorb_x0, absorb_x1;
    logic absorb_pad_only;
    logic is_full_block;
    logic domain_sep;
    logic xor_key_x12, xor_key_x23, xor_key_x34;

    // FSM <-> Permutation
    logic       perm_start;
    logic       perm_done;
    logic [3:0] perm_rounds;

    // Datapath <-> Permutation
    logic [0:4][63:0] perm_x_in;
    logic [0:4][63:0] perm_x_out;

    // INSTANTIATIONS

    // FSM Controller
    Ascon_FSM u_fsm (
        .clk             (clk),
        .rst_n           (rst_n),
        
        // CPU & DMA Signals
        .start           (start),
        .variant_128a    (variant_128a),
        .done            (done),
        .data_valid      (data_valid),
        .data_last       (data_last),
        .data_ready      (data_ready),
        .has_ad          (has_ad),
        .has_msg         (has_msg),

        // Permutation Control
        .perm_start      (perm_start),
        .perm_rounds     (perm_rounds),
        .perm_done       (perm_done),
        .is_full_block   (is_full_block),
        // Datapath Control
        .state_update    (state_update),
        .sel_iv          (sel_iv),
        .absorb_x0       (absorb_x0),
        .absorb_x1       (absorb_x1),
        .absorb_pad_only (absorb_pad_only),
        .xor_key_x12     (xor_key_x12),
        .xor_key_x23     (xor_key_x23),
        .xor_key_x34     (xor_key_x34),
        .domain_sep      (domain_sep),
        .msg_valid       (msg_valid),
        .tag_valid       (tag_valid)
    );

    // Datapath 
    Ascon_Datapath u_datapath (
        .clk             (clk),
        .rst_n           (rst_n),
        
        // Data In/Out
        .cipher_in       (cipher_in),
        .t_keep          (t_keep),
        .key             (key),
        .nonce           (nonce),
        .iv              (internal_iv),
        .cipher_out      (cipher_out),
        .tag_out         (tag_out),
        
        // Control from FSM
        .decrypt_mode    (decrypt_mode),
        .state_update    (state_update),
        .sel_iv          (sel_iv),
        .absorb_x0       (absorb_x0),
        .absorb_x1       (absorb_x1),
        .absorb_pad_only (absorb_pad_only),         
        .is_full_block   (is_full_block),
        .domain_sep      (domain_sep),
        .xor_key_x12     (xor_key_x12),
        .xor_key_x23     (xor_key_x23),
        .xor_key_x34     (xor_key_x34),
        
        // Permutation connections
        .perm_done       (perm_done),
        .perm_x_in       (perm_x_in),
        .perm_x_out      (perm_x_out)
    );

    // Permutation Engine (Math Core)
    Permutation u_perm (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (perm_start),
        .num_rounds      (perm_rounds),
        .x_in            (perm_x_in),
        .x_out           (perm_x_out),
        .done            (perm_done)
    );

endmodule
