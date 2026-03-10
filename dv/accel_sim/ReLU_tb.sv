`timescale 1ns / 1ps

module ReLU_tb;

  parameter int DATA_W = 8;

  logic                     clk;
  logic                     rst_n;

  logic signed [DATA_W-1:0] x_in;
  logic                     x_valid;
  logic                     x_last;

  logic signed [DATA_W-1:0] relu_out;
  logic                     relu_valid;
  logic                     relu_last;

  ReLU #(.DATA_W(DATA_W)) dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .x_in      (x_in),
    .x_valid   (x_valid),
    .x_last    (x_last),
    .relu_out  (relu_out),
    .relu_valid(relu_valid),
    .relu_last (relu_last)
  );

  // Clock (100MHz -> Cycle 10ns) ---
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n   = 0;
    x_in    = '0;
    x_valid = 0;
    x_last  = 0;

    // Wait 20ns 
    #20;
    rst_n = 1;
    #10;


    // Data (Q3.4)
    // Input: [ 2.0, -1.5,  0.0,  5.5, -3.0]
    // Q3.4:  [  32,  -24,    0,   88,  -48]
    
    send_data(8'sd32,  0); // +2.0
    send_data(-8'sd24, 0); // -1.5 
    send_data(8'sd0,   0); //  0.0 
    send_data(8'sd88,  0); // +5.5 
    send_data(-8'sd48, 1); // -3.0 -> x_last = 1

    @(posedge clk);
    #1;
    x_valid = 0;
    x_last  = 0;

    repeat(5) @(posedge clk);
    
    $finish;
  end


  task send_data(input logic signed [DATA_W-1:0] data, input logic is_last);
    begin
      @(posedge clk);
      #1; 
      x_in    = data;
      x_valid = 1;
      x_last  = is_last;
      
      $display("Time %0t | INPUT  -> x_in: %4d | valid: %b | last: %b", 
               $time, x_in, x_valid, x_last);
    end
  endtask

  always @(posedge clk) begin
    #2; 
    if (relu_valid) begin
      $display("Time %0t | OUTPUT <- out : %4d | valid: %b | last: %b", 
               $time, relu_out, relu_valid, relu_last);
    end
  end

endmodule
