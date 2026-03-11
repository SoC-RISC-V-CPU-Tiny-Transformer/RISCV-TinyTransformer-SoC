`timescale 1ns / 1ps
import softmax_pkg::*;

module Softmax_tb;

  logic clk = 0;
  logic rst_n = 0;

  logic signed [7:0] x_in [8];
  logic x_valid, x_ready;

  logic [7:0] prob_out [8];
  logic prob_valid;

  // Instantiate DUT (Device Under Test)
  Softmax dut (
    .clk(clk),
    .rst_n(rst_n),
    .x_in(x_in),
    .x_valid(x_valid),
    .x_ready(x_ready),
    .prob_out(prob_out),
    .prob_valid(prob_valid)
  );

  // Clock -> Cycle 10ns
  always #5 clk = ~clk;

  initial begin
  
    x_valid = 0;
    for (int i = 0; i < 8; i++) x_in[i] = 0;
    
    #20 rst_n = 1;
    @(posedge clk); #1;

    $display("==========================================================");
    $display("[%0t] SEND 4 VECTOR (1 VEC/CYCLE)", $time);
    $display("==========================================================");

    // CYCLE 1: SEND VECTOR 1
    x_in[0] = 8'sh00; //  0.0
    x_in[1] = 8'shF8; // -0.5
    x_in[2] = 8'shF0; // -1.0
    x_in[3] = 8'shE0; // -2.0
    x_in[4] = 8'shE8; // -1.5
    x_in[5] = 8'shF8; // -0.5
    x_in[6] = 8'shF0; // -1.0
    x_in[7] = 8'sh00; //  0.0
    x_valid = 1;
    $display("[%0t] -> Send Vector 1", $time);
    @(posedge clk); #1;

    // CYCLE 2: SEND VECTOR 2
    x_in[0] = 8'shF0; // -1.0
    x_in[1] = 8'shE0; // -2.0
    x_in[2] = 8'shD0; // -3.0
    x_in[3] = 8'shC0; // -4.0
    x_in[4] = 8'shF8; // -0.5
    x_in[5] = 8'shF0; // -1.0
    x_in[6] = 8'shE8; // -1.5
    x_in[7] = 8'shF8; // -0.5
    x_valid = 1;
    $display("[%0t] -> Send Vector 2", $time);
    @(posedge clk); #1;

    // CYCLE 2: SEND VECTOR 2
    x_in[0] = 8'sh00; // 0.0
    x_in[1] = 8'sh00; // 0.0
    x_in[2] = 8'sh00; // 0.0
    x_in[3] = 8'sh00; // 0.0
    x_in[4] = 8'sh00; // 0.0
    x_in[5] = 8'sh00; // 0.0
    x_in[6] = 8'sh00; // 0.0
    x_in[7] = 8'sh00; // 0.0
    x_valid = 1;
    $display("[%0t] -> Send Vector 3 (0.0)", $time);
    @(posedge clk); #1;

    // CYCLE 4: SEND VECTOR 4
    x_in[0] = 8'shF8; // -0.5
    x_in[1] = 8'shF8; // -0.5
    x_in[2] = 8'shF8; // -0.5
    x_in[3] = 8'shF8; // -0.5
    x_in[4] = 8'shF8; // -0.5
    x_in[5] = 8'shF8; // -0.5
    x_in[6] = 8'shF8; // -0.5
    x_in[7] = 8'shF8; // -0.5
    x_valid = 1;
    $display("[%0t] -> Send Vector 4 (-0.5)", $time);
    @(posedge clk); #1;

    // Stop send
    x_valid = 0;

    // Wait 10 cycles
    repeat(10) @(posedge clk);
    
    $display("==========================================================");
    $display("[%0t] DONE SIMULATION!", $time);
    $display("==========================================================");
    $finish;
  end


  int vec_out_idx = 1;
  int sum_prob = 0;

  always @(posedge clk) begin
    if (prob_valid) begin
      sum_prob = 0;
      $display("----------------------------------------------------------");
      $display("[%0t] OUTPUT VECTOR %0d:", $time, vec_out_idx);
      
      for (int i = 0; i < 8; i++) begin
        sum_prob += prob_out[i];
        $display("   Element [%0d] = %3d (%.3f)", i, prob_out[i], real'(prob_out[i])/256.0);
      end
      
      $display("   --> PROBABILITY SUM OF VECTOR %0d = %0d/256", vec_out_idx, sum_prob);
      vec_out_idx++;
    end
  end

endmodule