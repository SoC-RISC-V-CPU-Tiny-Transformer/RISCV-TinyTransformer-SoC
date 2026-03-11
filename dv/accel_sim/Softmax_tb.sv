`timescale 1ns / 1ps

module Softmax_tb;

  logic clk = 0;
  logic rst_n = 0;

  // ARRAY_SIZE = 4
  localparam int ARRAY_SIZE = 4;
  localparam int VEC_CYCLES = 16; // 64 / 4 = 16 cycles

  logic signed [7:0] x_in [ARRAY_SIZE]; 
  logic x_valid, x_last, x_ready;

  logic [7:0] prob_out [ARRAY_SIZE];
  logic prob_valid, prob_last;

  // Instantiate DUT
  Softmax dut (
    .clk(clk), .rst_n(rst_n),
    .x_in(x_in), .x_valid(x_valid), .x_last(x_last), .x_ready(x_ready),
    .prob_out(prob_out), .prob_valid(prob_valid), .prob_last(prob_last)
  );

  // Clock 10ns
  always #5 clk = ~clk;

  // --- Buffer 16 vector  ---
  logic signed [7:0] seq_data [0:VEC_CYCLES-1][0:ARRAY_SIZE-1];

  initial begin
    // 15 vetor
    for (int v = 0; v < 15; v++) begin
      seq_data[v][0] = 8'sh00; //  0.0
      seq_data[v][1] = 8'shF8; // -0.5
      seq_data[v][2] = 8'shF0; // -1.0
      seq_data[v][3] = 8'shE0; // -2.0
    end
    
    // Vector 16 (Final) 
    seq_data[15][0] = 8'shF0; // -1.0
    seq_data[15][1] = 8'shE0; // -2.0
    seq_data[15][2] = 8'shD0; // -3.0
    seq_data[15][3] = 8'shC0; // -4.0

    // Reset 
    x_valid = 0; x_last = 0;
    for(int i=0; i<ARRAY_SIZE; i++) x_in[i] = 0;
    
    #20 rst_n = 1;
    @(posedge clk); #1;

    // 2. Send 16 Vector to DUT
    for (int v = 0; v < VEC_CYCLES; v++) begin
      // Đợi x_ready = 1 mới được bơm (Handshake)
      while (!x_ready) @(posedge clk); 

      // Assign data for 4 element
      for (int i = 0; i < ARRAY_SIZE; i++) begin
        x_in[i] = seq_data[v][i];
      end
      
      x_valid = 1;
      x_last  = (v == VEC_CYCLES - 1); // Trigger x_last at final vector 
      
      $display("[%0t] SENDED VECTOR %0d %s", $time, v + 1, x_last ? "(LAST!)" : "");
      
      @(posedge clk); #1;
    end

    // Stop send data
    x_valid = 0;
    x_last  = 0;
    $display("[%0t] FINISHED SENDING 16 VECTORS. Waiting for output...", $time);
  end

  // --- Monitor & Result ---
  int vec_out_idx = 0;
  int sum_prob = 0;

  always @(posedge clk) begin
    if (prob_valid) begin
      $display("-----------------------------------------------------");
      $display("[%0t] OUTPUT VECTOR %0d (Q0.8 Probability):", $time, vec_out_idx + 1);
      
      for (int i = 0; i < ARRAY_SIZE; i++) begin
        $display("   Element [%0d]: %0d (= %.3f)", 
                 i, prob_out[i], real'(prob_out[i])/256.0);
        sum_prob += prob_out[i]; // sum of probability
      end
      
      vec_out_idx++;
      
      if (prob_last) begin // prob_last high at final vector 
        $display("-----------------------------------------------------");
        $display("Sum of ENTIRE sequence (~255/256) = %0d", sum_prob);
        $display("=> DONE SOFTMAX PIPELINE!");
        $display("-----------------------------------------------------");
        #20 $finish;
      end
    end
  end

endmodule