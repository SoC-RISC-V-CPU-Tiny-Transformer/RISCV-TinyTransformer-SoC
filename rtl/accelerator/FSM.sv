`timescale 1ns/1ps

module FSM #(
    parameter ACC_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    // Giao tiếp với Top Module
    input logic system_start,
    output logic system_done,

    input logic stage_done, // Nhận tín hiệu từ Datapath mỗi khi done 1 stage

    // Điều khiển Datapath
    output logic start_matmul,
    output logic transpose_mode,
    output logic [$clog2(ACC_WIDTH)-1:0] shift_amount,
    output logic multi_head,

    output logic [2:0] sel_in_a, sel_in_b,
    output logic we_sram_x, we_sram_0, we_sram_1, we_sram_2, we_sram_3
);
    
    typedef enum logic [3:0] {
        IDLE,
        LAYERNORM, WAIT_LN,
        CALC_Q, WAIT_Q,
        CALC_K, WAIT_K,
        CALC_V, WAIT_V,
        DONE
    } state_t;

    state_t state, next_state;
    // ==================================================
    // CHANGE STATE
    // ==================================================
    always_ff @(posedge clk) begin
        if(!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // ==================================================
    // NEXT STATE LOGIC
    // ==================================================
    always_comb begin
        next_state = state;

        case(state)
            IDLE: if(system_start) next_state = LAYERNORM;
            
            LAYERNORM: next_state = CALC_Q;
            WAIT_LN: next_state = CALC_Q;

            CALC_Q: next_state = WAIT_Q;
            WAIT_Q: if(stage_done) next_state = CALC_K;

            CALC_K: next_state = WAIT_K;
            WAIT_K: if(stage_done) next_state = CALC_V;

            CALC_V: next_state = WAIT_V;
            WAIT_V: if(stage_done) next_state = DONE;

            DONE: next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

    // ==================================================
    // OUTPUT LOGIC
    // ==================================================
    always_comb begin
        start_matmul = 0;
        transpose_mode = 0;
        shift_amount = 8;
        multi_head = 0;
        system_done = 0;

        sel_in_a = 3'd0; sel_in_b = 3'd0;
        we_sram_x = 0; we_sram_0 = 0; we_sram_1 = 0; we_sram_2 = 0; we_sram_3 = 0;

        case(state)
            CALC_Q: begin
                start_matmul = 1;
                transpose_mode = 1;
                sel_in_a = 3'd0;
                sel_in_b = 3'd1;
                we_sram_3 = 1;
            end
            WAIT_Q: begin
                transpose_mode = 1;
                sel_in_a = 3'd0;
                sel_in_b = 3'd1;
                we_sram_3 = 1;
            end

            CALC_K: begin
                start_matmul = 1;
                transpose_mode = 1;
                sel_in_a = 3'd0;
                sel_in_b = 3'd2;
                we_sram_0 = 1;
            end
            WAIT_K: begin
                transpose_mode = 1;
                sel_in_a = 3'd0;
                sel_in_b = 3'd2;
                we_sram_0 = 1;
            end

            CALC_V: begin
                start_matmul = 1;
                transpose_mode = 0;
                sel_in_a = 3'd0;
                sel_in_b = 3'd3;
                we_sram_1 = 1;
            end
            WAIT_V: begin
                transpose_mode = 0;
                sel_in_a = 3'd0;
                sel_in_b = 3'd3;
                we_sram_1 = 1;
            end

            DONE: system_done = 1;
        endcase
    end
    
endmodule