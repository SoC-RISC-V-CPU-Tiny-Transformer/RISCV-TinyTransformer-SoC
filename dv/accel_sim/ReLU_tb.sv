`timescale 1ns / 1ps

module ReLU_tb;

  parameter int DATA_W  = 8;
  parameter int SEQ_LEN = 4;

  logic                                       clk;
  logic                                       rst_n;

  logic signed [SEQ_LEN-1:0][DATA_W-1:0]      x_in;
  logic                                       x_valid;

  logic signed [SEQ_LEN-1:0][DATA_W-1:0]      relu_out;
  logic                                       relu_valid;

  // Instantiate DUT
  ReLU #(
    .DATA_W(DATA_W),
    .SEQ_LEN(SEQ_LEN)
  ) dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .x_in      (x_in),
    .x_valid   (x_valid),
    .relu_out  (relu_out),
    .relu_valid(relu_valid)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  initial begin
    rst_n   = 0;
    x_in    = '0;
    x_valid = 0;

    // Wait 20ns Reset
    #20;
    rst_n = 1;
    #10;

    // --- ARRAY 1 ---
    x_in[0] = 8'sd32;  // 2.0
    x_in[1] = -8'sd24; // -1.5
    x_in[2] = 8'sd0;   // 0.0
    x_in[3] = 8'sd88;  // 5.5
    send_array(x_in);

    // Next cycle, valid -> 0 to stop send 
    @(posedge clk);
    #1;
    x_valid = 0;

    wait(relu_valid == 1'b1);
    
    @(posedge clk); 
    $display("-------------------------------------------------");

    // --- ARRAY 2 ---
    x_in[0] = -8'sd48; // -3.0
    x_in[1] = 8'sd16;  // 1.0
    x_in[2] = -8'sd8;  // -0.5
    x_in[3] = 8'sd64;  // 4.0
    send_array(x_in);

    @(posedge clk);
    #1;
    x_valid = 0;

    // Wait result
    wait(relu_valid == 1'b1);
    
    repeat(3) @(posedge clk);
    
    $display("=================================================");
    $finish;
  end

  task send_array(input logic signed [SEQ_LEN-1:0][DATA_W-1:0] data_array);
    begin
      @(posedge clk);
      #1; 
      x_in    = data_array;
      x_valid = 1;
      $display("Time %0t | INPUT  -> ARRAY: %p | valid: %b", $time, x_in, x_valid);
    end
  endtask

  always @(posedge clk) begin
    #2; 
    if (relu_valid) begin
      $display("Time %0t | OUTPUT <- ARAY: %p | valid: %b", $time, relu_out, relu_valid);
    end
  end

endmodule
