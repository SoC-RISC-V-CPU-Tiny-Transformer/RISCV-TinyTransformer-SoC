// =============================================================================
// TESTBENCH (self-checking)
// Input1: [-0.5, -1.0, -2.0, 0.0] in Q3.4
// Expected softmax roughly: [0.29, 0.19, 0.09, 0.43]
// Input2: [0.0, -0.5, -1.0, -2.0] in Q3.4
// Expected softmax roughly: [0.407, 0.288, 0.2035, 0.102] 
// =============================================================================

`timescale 1ns / 1ps

/*
module find_max_sub_tb;

  import softmax_pkg::*;

  // Clock and reset
  logic clk = 0;
  logic rst_n = 0;

  // DUT signals
  logic signed [DATA_W-1:0] x_in;
  logic x_valid;
  logic x_last;
  logic signed [DATA_W-1:0] x_sub;
  logic x_sub_valid;
  logic x_sub_last;
  logic busy;

  // Clock generation: 100 MHz (period 10ns)
  always #5 clk = ~clk;

  // Instantiate DUT
  find_max_sub dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .x_in         (x_in),
    .x_valid      (x_valid),
    .x_last       (x_last),
    .x_sub        (x_sub),
    .x_sub_valid  (x_sub_valid),
    .x_sub_last   (x_sub_last),
    .busy         (busy)
  );

  // Task to send one element
  task send_element(
    input signed [DATA_W-1:0] data,
    input bit is_last = 0
  );
    @(posedge clk);
    x_in    = data;
    x_valid = 1'b1;
    x_last  = is_last;
    @(posedge clk);
    x_valid = 1'b0;
    x_last  = 1'b0;
  endtask

  // Task to send a full sequence
  task send_sequence(
    input signed [DATA_W-1:0] seq[$],
    input int delay_between = 1  // cycles between elements
  );
    $display("Time %0t: Sending sequence with %0d elements: %p", $time, seq.size(), seq);
    
    for (int i = 0; i < seq.size(); i++) begin
      send_element(seq[i], (i == seq.size()-1));
      repeat(delay_between) @(posedge clk);
    end
    
    // Wait for busy to go low (REPLAY finished)
    wait (!busy);
    $display("Time %0t: Sequence finished, busy = 0", $time);
  endtask

  initial begin
    // Initialize signals
    x_in    = '0;
    x_valid = 1'b0;
    x_last  = 1'b0;

    // Reset sequence
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);

    // Test 1: Sequence ngắn 4 phần tử
    send_sequence('{
      8'sh20,   //  2.0   (Q3.4: 0010.0000 = 32 decimal → 32/16 = 2.0)
      8'sh58,   //  5.5   (0101.1000 = 88 → 88/16 = 5.5)
      8'sh30,   //  3.0   (0011.0000 = 48 → 48/16 = 3.0)
      8'shD0    // -3.0   (1101.0000 = -48 → -48/16 = -3.0)
    });

    // Wait a bit
    repeat(10) @(posedge clk);

    // Test 2: Sequence dài hơn, có giá trị âm và dương
    send_sequence('{
      8'sh10,   //  1.0
      8'sh40,   //  4.0
      8'sh78,   //  7.5   → max
      8'shE0,   // -2.0
      8'sh28,   //  2.5
      8'shF8    // -0.5
    });

    // Wait for finish
    repeat(20) @(posedge clk);

    // Test 3: Reset giữa chừng (simulate error recovery)
    $display("Time %0t: Testing reset during FIND_MAX", $time);
    send_element(8'sh50);  // 5.0
    send_element(8'sh60);  // 6.0
    rst_n = 0;             // Reset active
    repeat(3) @(posedge clk);
    rst_n = 1;
    $display("Time %0t: Reset released", $time);
    repeat(10) @(posedge clk);

    // Test 4: Sequence chỉ 1 phần tử
    send_sequence('{8'sh3C});  // 3.75

    // End simulation
    repeat(20) @(posedge clk);
    $display("Simulation finished at %0t", $time);
    $finish;
  end

  // Monitor output during REPLAY
  always @(posedge clk) begin
    if (x_sub_valid) begin
      $display("Time %0t: x_sub_valid=1, x_sub=%0d (%.2f in Q3.4), x_sub_last=%b",
               $time, x_sub, $itor(x_sub)/16.0, x_sub_last);
    end
  end

  // Dump waveform
  initial begin
    $dumpfile("find_max_sub_tb.vcd");
    $dumpvars(0, find_max_sub_tb);
  end

endmodule
*/


module Softmax_tb;

  logic clk;
  logic rst_n;

  logic signed [7:0] x_in;
  logic x_valid;
  logic x_last;
  logic x_ready;

  logic [7:0] prob_out;
  logic prob_valid;
  logic prob_last;

  // Instantiate DUT
  Softmax dut (
    .clk(clk),
    .rst_n(rst_n),
    .x_in(x_in),
    .x_valid(x_valid),
    .x_last(x_last),
    .x_ready(x_ready),
    .prob_out(prob_out),
    .prob_valid(prob_valid),
    .prob_last(prob_last)
  );

  // Clock 10ns
  always #5 clk = ~clk;

  // Test vector
  logic signed [7:0] test_vec [0:3];

  // Expected output (Q0.8)
  logic [7:0] expected [0:3];

  integer i;
  integer out_idx;

  initial begin
    clk = 0;
    rst_n = 0;
    x_valid = 0;
    x_last = 0;
    x_in = 0;

    // Input
    test_vec[0] = 8'sh00; // 0.0
    test_vec[1] = 8'shF8; // -0.5
    test_vec[2] = 8'shF0; // -1.0
    test_vec[3] = 8'shE0; // -2.0

//      test_vec[0] = 8'sh10; // 1.0
//      test_vec[1] = 8'sh08; // 0.5
//      test_vec[2] = 8'shF8; // -0.5
//      test_vec[3] = 8'shE8; // -1.5
    // Expected Q0.8
    expected[0] = 8'd104;
    expected[1] = 8'd74;
    expected[2] = 8'd52;
    expected[3] = 8'd26;

    #20;
    rst_n = 1;

    // Send inputs
    for(i=0;i<4;i=i+1) begin
      @(posedge clk);
      #1;
      x_in    = test_vec[i];
      x_valid = 1;
      x_last  = (i==3);
      $display("%t | INPUT SENT : x_in = %0d (0x%h) last=%0d",$time, x_in, x_in, x_last);
    end

    @(posedge clk);
    #1;
    x_valid = 0;
    x_last  = 0;

  end
  
  // Monitor input accepted
  always @(posedge clk) begin
    if(x_valid && x_ready) begin
      $display("%t | INPUT ACCEPTED: x_in = %0d (0x%h) last=%0d",
                $time, x_in, x_in, x_last);
    end
  end

  // Check output
  always @(posedge clk) begin
    if(prob_valid) begin
      $display("Output %0d : %0d (expected ~%0d)",
                out_idx, prob_out, expected[out_idx]);

      out_idx = out_idx + 1;

      if(prob_last) begin
        $display("Softmax sequence done");
        #20;
        $finish;
      end
    end
  end

  initial begin
    out_idx = 0;
  end


endmodule

`default_nettype wire