`timescale 1ns / 1ps

module Ascon_Datapath import ascon_pkg::*; (
    input  logic                    clk,
    input  logic                    rst_n,

    // Data signals 
    input  logic [DATA_WIDTH-1:0]   cipher_in,  
    input  logic [DATA_WIDTH/8-1:0] t_keep,    
    input  logic [127:0]            key,          
    input  logic [127:0]            nonce,        
    input  logic [63:0]             iv,           
    
    // Control FSM 
    input  logic                    decrypt_mode, 
    input  logic                    state_update, 
    input  logic                    sel_iv,       
    input  logic                    absorb_x0,    
    input  logic                    absorb_x1,    
    input  logic                    absorb_pad_only,
    input  logic                    domain_sep,   // Domain segmentation into x4
    input  logic                    perm_done,    
    input  logic                    xor_key_x12,  
    input  logic                    xor_key_x23,  
    input  logic                    xor_key_x34,  
    output logic                    is_full_block, 

    // Output signals 
    output logic [DATA_WIDTH-1:0]   cipher_out,     
    output logic [127:0]            tag_out,      
    
    // Permutation 
    output logic [0:4][63:0]        perm_x_in,
    input  logic [0:4][63:0]        perm_x_out
);

    logic [0:4][63:0] state_reg;
    logic [63:0] next_x0, next_x1, next_x2, next_x3, next_x4;

    logic [127:0] converted_data;
    logic [127:0] actual_data;
    
    assign is_full_block = &t_keep;

    // OUTPUT LOGIC 
    // ASCON-128: Only outputs the upper half. ASCON-128a: Outputs all 128 bits.
    always_comb begin 
        converted_data = CONVERSION(cipher_in);
        actual_data    = (absorb_pad_only) ? (128'h00000000000000000000000000000001) : PAD(converted_data, t_keep);
        if (DATA_WIDTH == 128) begin
            cipher_out[63:0]   = actual_data[63:0]   ^ state_reg[0];
            cipher_out[127:64] = actual_data[127:64] ^ state_reg[1];
        end else begin
            cipher_out[63:0]   = actual_data[63:0]   ^ state_reg[0];
        end
    end

    assign tag_out[63:0]   = next_x3 ^ key[127:64];
    assign tag_out[127:64] = next_x4 ^ key[63:0];

    // INPUT MUX LOGIC 
    always_comb begin
        // default
        next_x0 = state_reg[0];
        next_x1 = state_reg[1];
        next_x2 = state_reg[2];
        next_x3 = state_reg[3];
        next_x4 = state_reg[4];

        // Priority 1: Load result from Permutation
        if (perm_done) begin
            next_x0 = perm_x_out[0];
            next_x1 = perm_x_out[1];
            next_x2 = perm_x_out[2];
            next_x3 = perm_x_out[3];
            next_x4 = perm_x_out[4];            
        end

        // Priority 2: Initialize IV, Key, Nonce
        else if (sel_iv) begin
            next_x0 = iv;
            next_x1 = key[127:64];
            next_x2 = key[63:0];
            next_x3 = nonce[127:64];
            next_x4 = nonce[63:0];
        end 

        // Priority 3: Load data (Absorb) 
        else begin
            if (absorb_x0) begin
                if (decrypt_mode) next_x0 = actual_data[63:0];
                else              next_x0 = state_reg[0] ^ actual_data[63:0];
            end

            if (absorb_x1) begin
                if (decrypt_mode) next_x1 = actual_data[127:64];
                else              next_x1 = state_reg[1] ^ actual_data[127:64];
            end
    
        end

        // Domain Separation
        if (domain_sep) begin
            next_x4 = next_x4 ^ 64'h8000000000000000;
        end

        // FINAL stage (XOR Key before Permutation)
        if (xor_key_x12) begin
            next_x1 = next_x1 ^ key[127:64];
            next_x2 = next_x2 ^ key[63:0];
        end
        if (xor_key_x23) begin
            next_x2 = next_x2 ^ key[127:64];
            next_x3 = next_x3 ^ key[63:0];
        end

        // INIT stage (XOR Key after Permutation)
        if (xor_key_x34) begin
            next_x3 = next_x3 ^ key[127:64];
            next_x4 = next_x4 ^ key[63:0];
        end
    end 

    // Module Permutation
    assign perm_x_in[0] = next_x0; 
    assign perm_x_in[1] = next_x1;
    assign perm_x_in[2] = next_x2;
    assign perm_x_in[3] = next_x3;
    assign perm_x_in[4] = next_x4;

    // UPDATE STATE_REG 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg[0] <= '0;
            state_reg[1] <= '0;
            state_reg[2] <= '0;
            state_reg[3] <= '0;
            state_reg[4] <= '0;
        end
        else if (state_update) begin
            state_reg[0] <= next_x0;
            state_reg[1] <= next_x1;
            state_reg[2] <= next_x2;
            state_reg[3] <= next_x3;
            state_reg[4] <= next_x4;
        end
    end

endmodule
