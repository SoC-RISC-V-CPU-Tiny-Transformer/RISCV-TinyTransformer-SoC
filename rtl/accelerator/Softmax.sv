// Base-2 Softmax Module for Tiny Transformer 
// Architecture: 4-Stage Pipeline
//   Stage 1: Find Max & Subtract
//   Stage 2: Hybrid Exponent Engine (LUT + Barrel Shifter)
//   Stage 3: Denominator Accumulator
//   Stage 4: Reciprocal LUT + Fixed-Point Multiplier
//
// Data Format : Q3.4 (8-bit signed) for input
// Output      : Q0.8 (8-bit unsigned, normalized probability)

`timescale 1ns / 1ps

// ALL localparamS 
package softmax_pkg;
  localparam int DATA_W     = 8;    
  localparam int FRAC_BITS  = 4;    
  localparam int INT_BITS   = 3;    
  localparam int ARRAY_SIZE = 8;    // Width 1 Vector
  localparam int ACCUM_W    = 32;   
  localparam int OUT_W      = 8;    
  localparam int LUT_FRAC_W = 8;    
  localparam int RECIP_W    = 16;   
endpackage

import softmax_pkg::*;

// MODULE 1: Find Max & Subtractor
module find_max_sub_vec (
  input  logic                      clk, rst_n,
  input  logic signed [DATA_W-1:0]  x_in [ARRAY_SIZE],
  input  logic                      x_valid,
  
  output logic signed [DATA_W-1:0]  x_sub [ARRAY_SIZE],
  output logic                      x_sub_valid
);

  logic signed [DATA_W-1:0] vec_max;
  
  // Combinational Tree: Find Max of Vector 
  always_comb begin
    vec_max = x_in[0];
    for (int i = 1; i < ARRAY_SIZE; i++) begin
      if (x_in[i] > vec_max) vec_max = x_in[i];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_sub_valid <= 0;
      for (int i = 0; i < ARRAY_SIZE; i++) x_sub[i] <= '0;
    end else begin
      x_sub_valid <= x_valid;
      if (x_valid) begin
        for (int i = 0; i < ARRAY_SIZE; i++) begin
          x_sub[i] <= x_in[i] - vec_max; // Sutractor in 1 cycle
        end
      end
    end
  end
endmodule

// MODULE 2: Hybrid Exponent Engine
// Computes 2^x for x in Q3.4, x <= 0
module hybrid_exp_engine_vec (
  input  logic                      clk, rst_n,
  input  logic signed [DATA_W-1:0]  x_safe [ARRAY_SIZE],
  input  logic                      x_valid,
  
  output logic [LUT_FRAC_W-1:0]     exp2_out [ARRAY_SIZE],
  output logic                      exp2_valid
);

  logic [LUT_FRAC_W-1:0] frac_lut [0:15];
  logic [3:0] frac;
  logic [INT_BITS:0] int_part;
  initial begin
    // Values: 2^(0/16)=1.000, 2^(1/16)=1.0442, ...
    frac_lut[ 0] = 8'd128; // 2^0.0000 * 128 = 128 (use 128 as 1.0 in Q1.7)
    frac_lut[ 1] = 8'd134; // 2^0.0625 = 1.0443
    frac_lut[ 2] = 8'd139; // 2^0.1250 = 1.0905
    frac_lut[ 3] = 8'd144; // 2^0.1875 = 1.1385
    frac_lut[ 4] = 8'd150; // 2^0.2500 = 1.1892
    frac_lut[ 5] = 8'd156; // 2^0.3125 = 1.2411
    frac_lut[ 6] = 8'd162; // 2^0.3750 = 1.2968
    frac_lut[ 7] = 8'd169; // 2^0.4375 = 1.3543
    frac_lut[ 8] = 8'd181; // 2^0.5000 = 1.4142 (sqrt2)
    frac_lut[ 9] = 8'd188; // 2^0.5625 = 1.4771
    frac_lut[10] = 8'd195; // 2^0.6250 = 1.5422
    frac_lut[11] = 8'd203; // 2^0.6875 = 1.6101
    frac_lut[12] = 8'd211; // 2^0.7500 = 1.6818
    frac_lut[13] = 8'd220; // 2^0.8125 = 1.7567
    frac_lut[14] = 8'd229; // 2^0.8750 = 1.8340
    frac_lut[15] = 8'd238; // 2^0.9375 = 1.9163
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      exp2_valid <= 0;
      for (int i = 0; i < ARRAY_SIZE; i++) exp2_out[i] <= '0;
    end else begin
      exp2_valid <= x_valid;
      if (x_valid) begin
      
        // Combinational lookup & shift
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            frac = x_safe[i][FRAC_BITS-1:0];
            int_part = x_safe[i][DATA_W-1:FRAC_BITS];
            exp2_out[i] <= frac_lut[frac] >> (-int_part);
        end
        
      end
    end
  end
endmodule

// MODULE 3: Denominator Accumulator
// Accumulates all 2^x values -> sum
module denom_accumulator_vec (
  input  logic                      clk, rst_n,
  input  logic [LUT_FRAC_W-1:0]     exp2_in [ARRAY_SIZE],
  input  logic                      exp2_valid,

  // Chỉ cần delay dữ liệu 1 nhịp để chờ Sum tính xong, không cần Buffer mảng 2 chiều!
  output logic [LUT_FRAC_W-1:0]     exp2_buf [ARRAY_SIZE], 
  output logic [ACCUM_W-1:0]        sum_out,
  output logic                      sum_valid
);

  logic [ACCUM_W-1:0] vec_sum;

  // Cây cộng dồn ngay lập tức trong 1 chu kỳ
  always_comb begin
    vec_sum = 0;
    for (int i = 0; i < ARRAY_SIZE; i++) vec_sum += exp2_in[i];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_valid <= 0; sum_out <= '0;
      for (int i = 0; i < ARRAY_SIZE; i++) exp2_buf[i] <= '0;
    end else begin
      sum_valid <= exp2_valid;
      if (exp2_valid) begin
        sum_out <= vec_sum;
        for (int i = 0; i < ARRAY_SIZE; i++) exp2_buf[i] <= exp2_in[i];
      end
    end
  end
endmodule

// MODULE 4: Reciprocal LUT + Fixed-Point Multiplier
module divider_recip_vec (
  input  logic                      clk, rst_n,
  input  logic [LUT_FRAC_W-1:0]     exp2_buf [ARRAY_SIZE],
  input  logic [ACCUM_W-1:0]        sum_in,
  input  logic                      sum_valid,

  output logic [OUT_W-1:0]          softmax_out [ARRAY_SIZE],
  output logic                      out_valid
);

  logic [RECIP_W-1:0] recip_lut [0:255];
  initial begin
    recip_lut[0] = 16'hFFFF;
    for (int i = 1; i < 256; i++) recip_lut[i] = 65536 / i;
  end

  logic [4:0] msb_pos;
  always_comb begin
    msb_pos = 0;
    for (int b = ACCUM_W-1; b >= 0; b--) begin
      if (sum_in[b] && msb_pos == 0) msb_pos = b[4:0];
    end
  end

  logic [7:0] sum_idx_comb;
  logic [RECIP_W-1:0] recip_val;
  logic [4:0] shift_out;
  logic [24:0] product;
  assign sum_idx_comb = (msb_pos >= 7) ? sum_in[msb_pos -: 8] : sum_in[7:0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_valid <= 0;
      for (int i = 0; i < ARRAY_SIZE; i++) softmax_out[i] <= '0;
    end else begin
      out_valid <= sum_valid;
      
      if (sum_valid) begin
        recip_val = recip_lut[sum_idx_comb]; 
        shift_out = (msb_pos >= 7) ? (msb_pos + 1) : 8; 

        for (int i = 0; i < ARRAY_SIZE; i++) begin
          product = exp2_buf[i] * recip_val;
          softmax_out[i] <= product >> shift_out; 
        end
      end
    end
  end
endmodule

// TOP MODULE
module Softmax (
  input  logic                      clk,
  input  logic                      rst_n,

  input  logic signed [DATA_W-1:0]  x_in [ARRAY_SIZE],
  input  logic                      x_valid,
  output logic                      x_ready,  

  output logic [OUT_W-1:0]          prob_out [ARRAY_SIZE],
  output logic                      prob_valid
);

  assign x_ready = 1'b1; // Always ready to receive data

  // Wires
  logic signed [DATA_W-1:0] x_sub [ARRAY_SIZE];
  logic                     x_sub_valid;

  logic [LUT_FRAC_W-1:0]    exp2_val [ARRAY_SIZE];
  logic                     exp2_valid;

  logic [LUT_FRAC_W-1:0]    exp2_buf [ARRAY_SIZE];
  logic [ACCUM_W-1:0]       sum_out;
  logic                     sum_valid;

  // Instantiations
  find_max_sub_vec u_stage1 (
    .clk(clk), .rst_n(rst_n), .x_in(x_in), .x_valid(x_valid),
    .x_sub(x_sub), .x_sub_valid(x_sub_valid)
  );

  hybrid_exp_engine_vec u_stage2 (
    .clk(clk), .rst_n(rst_n), .x_safe(x_sub), .x_valid(x_sub_valid),
    .exp2_out(exp2_val), .exp2_valid(exp2_valid)
  );

  denom_accumulator_vec u_stage3 (
    .clk(clk), .rst_n(rst_n), .exp2_in(exp2_val), .exp2_valid(exp2_valid),
    .exp2_buf(exp2_buf), .sum_out(sum_out), .sum_valid(sum_valid)
  );

  divider_recip_vec u_stage4 (
    .clk(clk), .rst_n(rst_n), .exp2_buf(exp2_buf), .sum_in(sum_out), .sum_valid(sum_valid),
    .softmax_out(prob_out), .out_valid(prob_valid)
  );

endmodule
