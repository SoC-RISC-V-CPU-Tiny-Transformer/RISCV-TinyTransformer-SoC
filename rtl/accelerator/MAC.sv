`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 03/08/2026 09:43:40 AM
// Module Name: MAC
// Project Name: TinyTransformer
//////////////////////////////////////////////////////////////////////////////////


module MAC #(parameter DATA_WIDTH = 8, parameter FRAC_BITS  = 4) (
    input  logic                         clk,        // Clock
    input  logic                         rst,        // Synchronous reset, active high
    input  logic                         valid_in,
    input  logic                         clear_acc,  // Delete accumulator 0

    input  logic signed [DATA_WIDTH-1:0] in_a,      // Input a
    input  logic signed [DATA_WIDTH-1:0] in_b,      // Input b
    output logic                         valid_out,
    output logic signed [DATA_WIDTH-1:0] acc_out    // Output after saturate
);   
    // Local parameter for full product width
    localparam PROD_WIDTH = 2*DATA_WIDTH;
    logic signed [PROD_WIDTH-1:0] mult_stage;   // Stage 1: full multiply result
    logic signed [PROD_WIDTH-1:0] shift_stage;  // Stage 2: after fractional shift
    logic signed [DATA_WIDTH-1:0] acc_reg;      // Stage 3: accumulator
    // Valid pipeline chain
    logic v1,v2,v3;                             
    

////////////////////////////////////////////////
//// Stage 1 : Multiply
////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if (rst) begin
        mult_stage <= 0;
        v1 <= 0;
    end
    else begin
        mult_stage <= in_a * in_b;
        v1 <= valid_in;
    end
end
    
////////////////////////////////////////////////
//// Stage 2 : Q-format shift
////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if (rst) begin
        shift_stage <= 0;
        v2 <= 0;
    end
    else begin
        shift_stage <= mult_stage >>> FRAC_BITS; // Preserve sign bit
        v2 <= v1;
    end
end    
    
////////////////////////////////////////////////
//// Stage 3 : Accumulate
////////////////////////////////////////////////

logic signed [DATA_WIDTH:0] acc_temp;   // Extra bit for overflow detection

always_ff @(posedge clk) begin
    if (rst) begin
        acc_reg <= 0;
        v3 <= 0;
    end
    else begin

        if(clear_acc)
            acc_reg <= 0;

        else if(v2) begin

            acc_temp = acc_reg + shift_stage[DATA_WIDTH-1:0]; 

            // Saturation
            if(acc_temp >  $signed({1'b0,{(DATA_WIDTH-1){1'b1}}}))
                acc_reg <=  $signed({1'b0,{(DATA_WIDTH-1){1'b1}}});  // Max positive

            else if(acc_temp < $signed({1'b1,{(DATA_WIDTH-1){1'b0}}}))  
                acc_reg <= $signed({1'b1,{(DATA_WIDTH-1){1'b0}}});  // Min negative

            else
                acc_reg <= acc_temp[DATA_WIDTH-1:0];

        end

        v3 <= v2;

    end
end    

assign acc_out   = acc_reg;
assign valid_out = v3;

endmodule
