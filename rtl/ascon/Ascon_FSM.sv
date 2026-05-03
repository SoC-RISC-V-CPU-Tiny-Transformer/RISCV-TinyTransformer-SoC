`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 04/27/2026 07:55:10 PM
// Module Name: Ascon_FSM
// Project Name: ASCON_128
// Description: 
//////////////////////////////////////////////////////////////////////////////////


module Ascon_FSM import ascon_pkg::*; (
    input  logic        clk,
    input  logic        rst_n,

    // AXI-Lite (CPU)
    input  logic        start,
    input  logic        variant_128a, // 0 = 128, 1 = 128a
    input  logic        has_ad,       // 1 = Has AD
    input  logic        has_msg,      // 1 = Has MSG
    output logic        done,

    // AXI-Stream (DMA)
    input  logic        data_valid,   
    input  logic        data_last,    
    output logic        data_ready,  

    // Permutation
    output logic        perm_start,
    output logic [3:0]  perm_rounds,
    input  logic        perm_done,
    input  logic        is_full_block,
    // CONTROL DATAPATH
    output logic        state_update,
    output logic        sel_iv,
    output logic        absorb_x0,
    output logic        absorb_x1,
    output logic        absorb_pad_only,
    output logic        xor_key_x12,
    output logic        xor_key_x23,
    output logic        xor_key_x34,
    output logic        domain_sep,   
    output logic        msg_valid,
    output logic        tag_valid    
);

    typedef enum logic [2:0] {
        IDLE,
        INIT,
        AD, AD_PAD,   
        MSG, MSG_PAD, 
        FINAL,
        DONE
    } state_t;

    state_t state, next_state;

    // Flag: 0 = waiting, 1 = running
    logic is_working, next_is_working;
    logic is_last_reg;

    logic is_full_block_reg;

    // BLOCK 1: Flip-flop update state 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            is_working <= 0;
            is_last_reg <= 0;
            is_full_block_reg <= 0;
        end else begin
            state      <= next_state;
            is_working <= next_is_working;

            if (!is_working && data_valid) begin
                is_last_reg <= data_last;
                is_full_block_reg <= is_full_block;
            end
        end
    end

    // BLOCK 2: Next state logic
    always_comb begin
        next_state      = state;      // default
        next_is_working = is_working; // default
        
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            
            INIT: begin
                if (!is_working) begin
                    next_is_working = 1; // Start 
                end else if (perm_done) begin
                    next_is_working = 0; // Done running
                    if (has_ad)       next_state = AD;
                    else if (has_msg) next_state = MSG;
                    else              next_state = FINAL;
                end
            end
            
            AD: begin
                if (!is_working && data_valid) begin
                    next_is_working = 1; // Start running when valid data comes
                end else if (is_working && perm_done) begin
                    next_is_working = 0; // Done running
                    if (is_last_reg) begin
                        if (is_full_block_reg) next_state = AD_PAD;
                        else if (has_msg)      next_state = MSG;
                        else                   next_state = FINAL;
                    end
                end
            end

            AD_PAD: begin
                if (!is_working) begin
                    next_is_working = 1; 
                end else if (perm_done) begin
                    next_is_working = 0;
                    if (has_msg) next_state = MSG;
                    else         next_state = FINAL;
                end
            end

            MSG: begin
                if (!is_working && data_valid) begin
                    // not full block
                    if (data_last && !is_full_block) begin
                        next_state = FINAL;  
                    end else begin
                        next_is_working = 1; 
                    end
                end else if (is_working && perm_done) begin
                    next_is_working = 0;
                    // if FULL -> MSG_PAD
                    if (is_last_reg && is_full_block_reg) begin
                        next_state = MSG_PAD;
                    end
                end
            end

            MSG_PAD: begin
                // not run P8, Pad in 1 cycle Clock
                next_state = FINAL;
            end

            FINAL: begin
                if (!is_working) begin
                    next_is_working = 1;
                end else if (perm_done) begin
                    next_is_working = 0;
                    next_state = DONE;
                end
            end

            DONE: begin
                if (!start) next_state = IDLE; // Wait CPU start to reset
            end
        endcase
    end

    // BLOCK 3: Output Logic
    always_comb begin
        // default values
        done            = 0;
        perm_start      = 0;
        perm_rounds     = (variant_128a) ? 4'd8 : 4'd6; // 128a = 8 rounds, 128 = 6 rounds
        sel_iv          = 0;
        absorb_x0       = 0;
        absorb_x1       = 0;
        absorb_pad_only = 0;
        xor_key_x12     = 0;
        xor_key_x23     = 0;
        xor_key_x34     = 0;
        domain_sep      = 0;
        state_update    = 0;
        data_ready      = 0;

        msg_valid       = 0;
        tag_valid       = 0;

        case (state)
            IDLE: begin
                // do nothing, wait for start signal
            end

            INIT: begin
                perm_rounds = 4'd12;
                if (!is_working) begin
                    sel_iv       = 1;
                    state_update = 1; // Load IV, Key, Nonce into Datapath
                    perm_start   = 1; // Start permutation
                end
                if (is_working && perm_done) begin
                    xor_key_x34  = 1; // Done 12 rounds, XOR Key into the end
                    if (!has_ad) domain_sep = 1;
                    state_update = 1; 
                end
            end
            
            AD: begin
                data_ready = !is_working; 

                if (!is_working && data_valid) begin
                    absorb_x0    = 1;
                    absorb_x1    = variant_128a; 
                    state_update = 1;
                    perm_start   = 1;
                end

                if (is_working && perm_done) begin
                    state_update = 1; 

                    if (is_last_reg && !is_full_block_reg) begin
                        domain_sep = 1;
                    end
                end
            end

            AD_PAD: begin
                if (!is_working) begin
                    absorb_x0       = 1;
                    absorb_x1       = variant_128a;
                    absorb_pad_only = 1; 
                    state_update    = 1;
                    perm_start      = 1; 
                end
                if (is_working && perm_done) begin
                    state_update = 1; 
                    domain_sep   = 1; 
                end
            end

            MSG: begin
                data_ready = !is_working;

                if (!is_working && data_valid) begin
                    absorb_x0    = 1;
                    absorb_x1    = variant_128a;
                    state_update = 1;
                    msg_valid    = 1; 
                    if (!data_last || is_full_block) begin
                        perm_start = 1; 
                    end
                end

                if (is_working && perm_done) begin
                    state_update = 1;
                end
            end

            MSG_PAD: begin
                absorb_x0       = 1;
                absorb_x1       = variant_128a;
                absorb_pad_only = 1; 
                state_update    = 1;
            end

            FINAL: begin
                perm_rounds = 4'd12;
                if (!is_working) begin
                    if (variant_128a) xor_key_x23 = 1;
                    else              xor_key_x12 = 1;
                    state_update = 1;
                    perm_start   = 1;
                end
                
                if (is_working && perm_done) begin
                    xor_key_x34  = 1;
                    state_update = 1; 
                    tag_valid    = 1; 
                end
            end

            DONE: begin
                done = 1;
            end
        endcase
    end

endmodule
