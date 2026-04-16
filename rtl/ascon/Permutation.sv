`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 04/13/2026 08:58:53 AM
// Module Name: Permutation
// Project Name: Ascon_128
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module Permutation import ascon_pkg::*; (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             start,
    input  logic [3:0]       num_rounds,   
    input  logic [0:4][63:0] x_in,
    output logic [0:4][63:0] x_out,
    output logic             done
);
    typedef enum logic [1:0] {
        IDLE,
        RUN,
        DONE
    } state_t;

    state_t state, next;

    logic [0:4][63:0]        data_in, round_out;
    logic [7:0]              round_const;
    
    logic [3:0] round_cnt;

    Round round_engine(
        .x_in(data_in), 
        .x_out(round_out), 
        .round_const(round_const)
    );

    assign round_const = RC[12 - num_rounds + round_cnt];

    // FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next;
    end

    // next state logic
    always_comb begin
        next = state;
        case (state)
            IDLE: if (start)        
                    next = RUN;
            RUN : if (round_cnt == num_rounds-1) 
                    next = DONE;
            DONE:   next = IDLE;
        endcase
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_in     <= '0;
            round_cnt   <=  0;
            done        <=  0;
        end
        else begin 
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        data_in     <= x_in;
                        round_cnt   <= 0;
                    end
                end

                RUN: begin
                    data_in <= round_out;
                    if (round_cnt < num_rounds-1) begin
                        round_cnt   <= round_cnt + 1;
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end
    
    assign x_out = data_in;
    
endmodule
