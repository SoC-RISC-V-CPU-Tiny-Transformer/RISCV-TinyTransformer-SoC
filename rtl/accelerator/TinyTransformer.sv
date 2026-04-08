`timescale 1ns / 1ps

module Transformer #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter ARRAY_SIZE = 8,
    parameter MAT_SIZE = 64,
    parameter ADDR_WIDTH = 9,
    parameter NUM_HEADS = 2
) (
    input logic clk,
    input logic rst_n,

    input logic [4:0] cfg_shifts [0:9],
    input logic [3:0] head_q_frac [NUM_HEADS-1:0],
    input logic system_start,
    output logic system_done
);

    logic stage_done;

    logic start_matmul;
    logic transpose_mode;
    
    logic [$clog2(ACC_WIDTH)-1:0] shift_amount;
    logic multi_head;

    logic [$clog2(NUM_HEADS)-1:0] head_idx;
    logic start_softmax;
    logic [3:0] sfm_q_frac;
    logic start_transpose;
    logic is_calc_z;
    
    logic [2:0] sel_in_a, sel_in_b;
    logic we_sram_x, we_sram_0, we_sram_1, we_sram_2, we_sram_3, we_sram_4;

    Controller #(
        .ACC_WIDTH(ACC_WIDTH),
        .NUM_HEADS(NUM_HEADS)
    ) controller (
        .clk(clk),
        .rst_n(rst_n),
        
        .system_start(system_start),
        .system_done(system_done),
        .cfg_shifts(cfg_shifts),
        .head_q_frac(head_q_frac),

        .stage_done(stage_done),
        
        .start_matmul(start_matmul),
        .transpose_mode(transpose_mode),
        .shift_amount(shift_amount),

        .multi_head(multi_head),
        .head_idx(head_idx),
        .start_softmax(start_softmax),
        .sfm_q_frac(sfm_q_frac),
        .start_transpose(start_transpose),
        .is_calc_z(is_calc_z),
        
        .sel_in_a(sel_in_a),
        .sel_in_b(sel_in_b),
        
        .we_sram_x(we_sram_x),
        .we_sram_0(we_sram_0),
        .we_sram_1(we_sram_1),
        .we_sram_2(we_sram_2),
        .we_sram_3(we_sram_3),
        .we_sram_4(we_sram_4)
    );

    Datapath #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .MAT_SIZE(MAT_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_HEADS(NUM_HEADS)
    ) datapath_unit (
        .clk(clk),
        .rst_n(rst_n),
        
        .start_matmul(start_matmul),
        .transpose_mode(transpose_mode),
        .shift_amount(shift_amount),

        .multi_head(multi_head),
        .head_idx(head_idx),
        .start_softmax(start_softmax),
        .sfm_q_frac(sfm_q_frac),
        .start_transpose(start_transpose),
        .is_calc_z(is_calc_z),
        
        .sel_in_a(sel_in_a),
        .sel_in_b(sel_in_b),
        
        .we_sram_x(we_sram_x),
        .we_sram_0(we_sram_0),
        .we_sram_1(we_sram_1),
        .we_sram_2(we_sram_2),
        .we_sram_3(we_sram_3),
        .we_sram_4(we_sram_4),
        
        .stage_done(stage_done)
    );

endmodule