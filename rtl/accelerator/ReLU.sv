`timescale 1ns / 1ps

// ReLU activation: outputs max(0, x), sets negative values to zero
module ReLU #(parameter int DATA_W = 8) (
  input  logic                     clk,
  input  logic                     rst_n,

  input  logic signed [DATA_W-1:0] x_in,
  input  logic                     x_valid, 
  input  logic                     x_last,

  output logic signed [DATA_W-1:0] relu_out,
  output logic                     relu_valid,
  output logic                     relu_last
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset toàn bộ tín hiệu đầu ra về 0
      relu_out   <= '0;
      relu_valid <= 1'b0;
      relu_last  <= 1'b0;
    end else begin
      relu_valid <= x_valid;
      relu_last  <= x_last;

      if (x_valid) begin
      
        if (x_in[DATA_W-1]) begin
          relu_out <= '0;   
        end else begin
          relu_out <= x_in; 
        end

      end else begin
        relu_out <= '0; 
      end

    end
  end

endmodule
