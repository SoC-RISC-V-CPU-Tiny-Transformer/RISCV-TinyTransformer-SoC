`timescale 1ns / 1ps

module MAC #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
) (
    input  logic                         clk,
    input  logic                         rst,        // Synchronous reset, active high
    input  logic                         valid_in,
    input  logic                         clear_acc,  // Delete accumulator 0
    input  logic [2:0]                   shift_amount, // Fractional bits

    input  logic signed [DATA_WIDTH-1:0] in_a,
    input  logic signed [DATA_WIDTH-1:0] in_b,
    output logic                         valid_out,
    output logic signed [DATA_WIDTH-1:0] out_8bit
);                       
    // --- STAGE 1: MULTIPLY ---
    localparam PROD_WIDTH = 2 * DATA_WIDTH;
    logic signed [PROD_WIDTH-1:0] mult_reg; // Stage 1: full multiply result
    logic v1;

    always_ff @(posedge clk) begin
        if (rst) begin
            mult_reg <= '0;
            v1 <= 1'b0;
        end
        else begin
            mult_reg <= in_a * in_b;
            v1 <= valid_in;
        end
    end
    
    // --- STAGE 2: ACCUMULATE ---
    logic signed [ACC_WIDTH-1:0] acc_reg;   // Extra bit for overflow detection
    logic v2;
    logic clear_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            acc_reg <= '0;
            v2 <= 1'b0;
            clear_reg <= 1'b0;
        end
        else begin
            clear_reg <= clear_acc;
            if(clear_reg) begin
                if(v1)
                    acc_reg <= ACC_WIDTH'(mult_reg);
                else
                    acc_reg <= '0;
            end
            else if(v1)
                acc_reg <= acc_reg + ACC_WIDTH'(mult_reg);

            v2 <= v1;
        end
    end    

    // --- STAGE 3: SHIFT & SATURATION (Combinational) ---
    logic signed [ACC_WIDTH-1:0] shifted_acc;

    always_comb begin
        shifted_acc = acc_reg >>> shift_amount;

        if(shifted_acc > $signed(ACC_WIDTH'(127)))
            out_8bit = 8'd127;
        else if(shifted_acc < $signed(ACC_WIDTH'(-128)))
            out_8bit = -8'd128;
        else
            out_8bit = shifted_acc[DATA_WIDTH-1:0];
    end    
    
assign valid_out = v2;

endmodule
