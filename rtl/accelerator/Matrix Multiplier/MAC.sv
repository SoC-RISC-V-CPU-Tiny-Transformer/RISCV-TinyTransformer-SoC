`timescale 1ns / 1ps

module MAC #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    input logic signed [DATA_WIDTH-1:0] in_a, in_b,
    input logic valid_in,
    input logic acc_clear,
    input logic [$clog2(ACC_WIDTH)-1:0] shift_amount,

    output logic signed [DATA_WIDTH-1:0] mac_out,
    output logic valid_out
);
    // --- STAGE 1: MULTIPLY ---
    localparam PROD_WIDTH = DATA_WIDTH * 2;
    logic signed [PROD_WIDTH-1:0] prod_reg;
    logic clear_reg;
    logic v1;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            clear_reg <= 1'b0;
            v1 <= 1'b0;
        end
        else begin
            prod_reg <= in_a * in_b;
            clear_reg <= acc_clear;
            v1 <= valid_in;
        end
    end

    // --- STAGE 2: ACCUMULATE ---
    logic signed [ACC_WIDTH-1:0] acc_reg;
    logic signed [ACC_WIDTH-1:0] buffer;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            acc_reg <= '0;
            valid_out <= 1'b0;
        end
        else begin
            if(clear_reg) begin
                valid_out <= 1'b1;
                buffer <= acc_reg;
                if(v1)
                    acc_reg <= ACC_WIDTH'(prod_reg);
                else 
                    acc_reg <= '0;
            end
            else begin
                if(v1)
                    acc_reg <= acc_reg + ACC_WIDTH'(prod_reg);
                valid_out <= 1'b0;
            end
        end
    end

    // --- STAGE 3: SHIFT & SATURATION ---
    logic signed [ACC_WIDTH-1:0] shifted_acc;

    always_comb begin
        shifted_acc = buffer >>> shift_amount;

        if(shifted_acc > $signed(ACC_WIDTH'(127)))
            mac_out = 8'd127;
        else if(shifted_acc < $signed(ACC_WIDTH'(-128)))
            mac_out = -8'd128;
        else
            mac_out = shifted_acc[DATA_WIDTH-1:0];
    end
endmodule