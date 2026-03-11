`timescale 1ns / 1ps

module ReLU #(parameter int DATA_W  = 8, parameter int ARRAY_SIZE = 4) (
  input  logic                                       clk,
  input  logic                                       rst_n,

  input  logic signed [ARRAY_SIZE-1:0][DATA_W-1:0]      x_in,
  input  logic                                       x_valid, 

  output logic signed [ARRAY_SIZE-1:0][DATA_W-1:0]      relu_out,
  output logic                                       relu_valid
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      relu_out   <= '0;
      relu_valid <= 1'b0;
    end else begin
      relu_valid <= x_valid;

      if (x_valid) begin
        for (int i = 0; i < ARRAY_SIZE; i++) begin
          if (x_in[i][DATA_W-1]) relu_out[i] <= '0;       // Negative -> 0
          else                   relu_out[i] <= x_in[i];  // 
        end
      end else begin
        relu_out <= '0;
      end
    end
  end

endmodule
