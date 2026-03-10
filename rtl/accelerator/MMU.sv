`timescale 1ns / 1ps

module MatrixMultUnit #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter ARRAY_SIZE = 4
) (
    input logic clk,
    input logic rst_n,

    input logic valid_in,
    input logic clear_acc,
    input logic [2:0] shift_amount,

    input logic signed [DATA_WIDTH-1:0] in_a [ARRAY_SIZE-1:0],
    input logic signed [DATA_WIDTH-1:0] in_b [ARRAY_SIZE-1:0],

    output logic signed [DATA_WIDTH-1:0] out_matrix [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0],
    output logic valid_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0]
);
    logic signed [DATA_WIDTH-1:0] skewed_a [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] skewed_b [ARRAY_SIZE-1:0];

    SkewBuffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) skew_buffer_a (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(in_a),
        .data_out(skewed_a)
    );

    SkewBuffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) skew_buffer_b (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(in_b),
        .data_out(skewed_b)
    );

    SystolicArray #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) systolic_array_core (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .clear_acc(clear_acc),
        .shift_amount(shift_amount),

        .in_a(skewed_a),
        .in_b(skewed_b),

        .out_matrix(out_matrix),
        .valid_out(valid_out)
    );

endmodule