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
    input logic system_start,
    output logic system_done
);

    logic stage_done;

    logic start_matmul;
    logic transpose_mode;
    
    logic [$clog2(ACC_WIDTH)-1:0] shift_amount;
    logic multi_head;
    
    logic [2:0] sel_in_a, sel_in_b;
    logic we_sram_x, we_sram_0, we_sram_1, we_sram_2, we_sram_3;

    Controller #(
        .ACC_WIDTH(ACC_WIDTH)
    ) controller (
        .clk(clk),
        .rst_n(rst_n),
        
        .system_start(system_start),
        .system_done(system_done),
        .cfg_shifts(cfg_shifts),

        .stage_done(stage_done),
        
        .start_matmul(start_matmul),
        .transpose_mode(transpose_mode),
        .shift_amount(shift_amount),
        .multi_head(multi_head),
        
        .sel_in_a(sel_in_a),
        .sel_in_b(sel_in_b),
        
        .we_sram_x(we_sram_x),
        .we_sram_0(we_sram_0),
        .we_sram_1(we_sram_1),
        .we_sram_2(we_sram_2),
        .we_sram_3(we_sram_3)
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
        
        .sel_in_a(sel_in_a),
        .sel_in_b(sel_in_b),
        
        .we_sram_x(we_sram_x),
        .we_sram_0(we_sram_0),
        .we_sram_1(we_sram_1),
        .we_sram_2(we_sram_2),
        .we_sram_3(we_sram_3),
        
        .stage_done(stage_done)
    );

endmodule