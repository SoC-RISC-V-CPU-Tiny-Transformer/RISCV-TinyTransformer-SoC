`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 04/27/2026 07:55:10 PM
// Module Name: Ascon_FSM
// Project Name: Ascon-AEAD128
// Description: 
//////////////////////////////////////////////////////////////////////////////////

module Ascon_FSM import ascon_pkg::*; (
    input  logic clk,
    input  logic reset_n,

    input  logic start,
    input  logic [1:0] mode,      // 00: Encrypt, 01: Decrypt
    input  logic skip_asso,
    input  logic mess_valid,
    input  logic mess_last,
    input  logic cycle_done,  

    input  logic perm_done,
    output logic perm_start,
    output logic [3:0] perm_rounds,

    output logic mess_pull,
    output logic cipher_push,
    output logic done,
    output logic [2:0] state_out
);
    state_t state, next;
    assign state_out = state;

    logic saved_mess_last;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            saved_mess_last <= 1'b0;
        end 
        else if (mess_valid && mess_pull) begin
            saved_mess_last <= mess_last;
        end
        else if (state == IDLE) begin
            saved_mess_last <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) state <= IDLE;
        else          state <= next;
    end


    always_comb begin
        next = state;
        perm_start = 0;
        perm_rounds = ASCON_B; 
        mess_pull = 0;
        cipher_push = 0;
        done = 0;

        case (state)
            IDLE: if (start) next = INIT;

            INIT: begin
                perm_start = 1;
                perm_rounds = ASCON_A; 
                if (perm_done) begin
                    perm_start = 0;
                    next = skip_asso ? MESSAGE : ASSO_DATA;
                end
            end

            ASSO_DATA: begin
                mess_pull = 1;
                if (mess_valid) begin
                    if (cycle_done) begin
                        perm_start = 1;
                    end
                end
                if (perm_done) begin
                    perm_start = 0;
                    if (saved_mess_last) next = MESSAGE;
                end
            end

            MESSAGE: begin
                mess_pull = 1;
                if (mess_valid) begin
                    cipher_push = 1; 
                    if (cycle_done) begin
                        if (mess_last) begin
                            next = TAG;
                        end
                        else 
                            perm_start = 1;
                    end
                end
            end

            TAG: begin
                perm_start = 1;
                perm_rounds = ASCON_A;
                if (perm_done) begin
                    done = 1;
                    next = IDLE;
                end
            end
        endcase
    end
endmodule
