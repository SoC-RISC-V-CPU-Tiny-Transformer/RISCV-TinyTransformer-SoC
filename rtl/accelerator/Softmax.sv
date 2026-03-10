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

// ALL PARAMETERS 
package softmax_pkg;
  parameter int DATA_W     = 8;    // Input width (Q3.4)
  parameter int FRAC_BITS  = 4;    // Fractional bits
  parameter int INT_BITS   = 3;    // Integer bits (sign included)
  parameter int SEQ_LEN    = 64;   // Max sequence length
  parameter int ACCUM_W    = 32;   // Accumulator width
  parameter int OUT_W      = 8;    // Output width (Q0.8 probability)
  parameter int LUT_FRAC_W = 8;    // LUT output fractional width (2^0.y)
  parameter int RECIP_W    = 16;   // Reciprocal LUT output width
  parameter int IDX_W      = $clog2(SEQ_LEN); // Index width
endpackage


// MODULE 1: Find Max & Subtractor

module find_max_sub
  import softmax_pkg::*;
(
  input  logic                     clk,
  input  logic                     rst_n,

  // Input stream
  input  logic signed [DATA_W-1:0] x_in,
  input  logic                     x_valid,
  input  logic                     x_last,   // last element in sequence

  // Output: subtracted values (x - max), streamed after full pass
  output logic signed [DATA_W-1:0] x_sub,
  output logic                     x_sub_valid,
  output logic                     x_sub_last,

  // Status
  output logic                     busy
);

  // --- Phase 1: find max ---
  typedef enum logic [1:0] {FIND_MAX, REPLAY, IDLE} state_t;
  state_t state, next_state;

  logic signed [DATA_W-1:0] max_val;
  logic signed [DATA_W-1:0] buf_mem [0:SEQ_LEN-1]; // input buffer
  logic [IDX_W-1:0]         wr_ptr, rd_ptr;
  logic [IDX_W-1:0]         seq_len_reg;

  // --- FSM ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE:     if (x_valid)                next_state = FIND_MAX;
      FIND_MAX: if (x_valid && x_last)      next_state = REPLAY;
      REPLAY:   if (rd_ptr == seq_len_reg - 1)  next_state = IDLE;
    endcase
  end

  // --- Buffer write & max find ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_val    <= '1 << (DATA_W-1); // most negative
      wr_ptr     <= '0;
      seq_len_reg<= '0;
    end else if (state == IDLE && x_valid) begin
      max_val    <= x_in;
      buf_mem[0] <= x_in;
      wr_ptr     <= 1;
    end else if (state == FIND_MAX && x_valid) begin
      buf_mem[wr_ptr] <= x_in;
      if (x_in > max_val) max_val <= x_in;
      wr_ptr <= wr_ptr + 1;
      if (x_last) seq_len_reg <= wr_ptr + 1;
    end
  end

  // --- Replay & subtract ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rd_ptr <= '0;
    else if (state == REPLAY) rd_ptr <= rd_ptr + 1;
    else if (state != REPLAY) rd_ptr <= '0;
  end

  assign x_sub       = (state == REPLAY) ? (buf_mem[rd_ptr] - max_val) : '0;
  assign x_sub_valid = (state == REPLAY);
  assign x_sub_last  = (state == REPLAY) && (rd_ptr == seq_len_reg - 1);
  assign busy = (state == REPLAY);

endmodule


// MODULE 2: Hybrid Exponent Engine
// Computes 2^x for x in Q3.4, x <= 0

module hybrid_exp_engine
  import softmax_pkg::*;
(
  input  logic                     clk,
  input  logic                     rst_n,

  input  logic signed [DATA_W-1:0] x_safe,       // Q3.4, always <= 0
  input  logic                     x_valid,
  input  logic                     x_last,

  output logic [LUT_FRAC_W-1:0]    exp2_out,      // 2^x in Q0.8 unsigned
  output logic                     exp2_valid,
  output logic                     exp2_last
);

  // --- LUT: 2^(0.y) for y = 0..15 in Q0.8 (256 = 1.0) ---
  // 2^(frac/16) * 256, rounded to nearest integer
  logic [LUT_FRAC_W-1:0] frac_lut [0:15];
  initial begin
    // 2^(n/16) * 256 for n=0..15
    // frac_lut[ 0] = 8'd256 >> 0;  // 2^0.0000 = 1.0000 -> but we use 8-bit
    // Precomputed: round(2^(n/16) * 128) -> Q1.7 actually use Q0.8 (max=255)
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

  // Stage 1: extract bits and read LUT
  logic [FRAC_BITS-1:0]     frac_bits_s1;
  logic [INT_BITS:0]        int_bits_s1;   // 4-bit signed integer part (with sign)
  logic [LUT_FRAC_W-1:0]    lut_val_s1;
  logic                     valid_s1, last_s1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_s1 <= 0; last_s1 <= 0;
    end else begin
      frac_bits_s1 <= x_safe[FRAC_BITS-1:0];           // [3:0]
      int_bits_s1  <= x_safe[DATA_W-1:FRAC_BITS];      // [7:4] signed
      lut_val_s1   <= frac_lut[x_safe[FRAC_BITS-1:0]]; // LUT read
      valid_s1     <= x_valid;
      last_s1      <= x_last;
    end
  end

  // Stage 2: Barrel Shifter (right shift by |integer part|)
  // Since x_safe <= 0, integer part is 0 or negative
  // shift_amt = abs(int_bits) = -int_bits for negative
  logic [3:0]            shift_amt;
  logic [LUT_FRAC_W-1:0] shifted;

  // int_bits_s1 is signed 4-bit: range -8 to +0
  // shift right by |int_bits|
  assign shift_amt = -int_bits_s1;
  assign shifted   = lut_val_s1 >> shift_amt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      exp2_valid <= 0; exp2_last <= 0; exp2_out <= 0;
    end else begin
      exp2_out   <= shifted;
      exp2_valid <= valid_s1;
      exp2_last  <= last_s1;
    end
  end

endmodule


// MODULE 3: Denominator Accumulator
// Accumulates all 2^x values -> sum

module denom_accumulator
  import softmax_pkg::*;
(
  input  logic                     clk,
  input  logic                     rst_n,

  input  logic [LUT_FRAC_W-1:0]    exp2_in,
  input  logic                     exp2_valid,
  input  logic                     exp2_last,

  // Also buffer inputs for stage 4
  output logic [LUT_FRAC_W-1:0]    exp2_buf [0:SEQ_LEN-1],
  output logic [IDX_W-1:0]         seq_count,

  output logic [ACCUM_W-1:0]       sum_out,
  output logic                     sum_valid
);

  logic [ACCUM_W-1:0] accum;
  logic [IDX_W-1:0]   idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      accum     <= '0;
      idx       <= '0;
      sum_valid <= 0;
      seq_count <= '0;
    end else begin
      sum_valid <= 0;
      if (exp2_valid) begin
        if (idx == 0) accum <= exp2_in;          // reset on first
        else          accum <= accum + exp2_in;
        exp2_buf[idx] <= exp2_in;
        idx <= idx + 1;
        if (exp2_last) begin
          sum_out   <= accum + exp2_in;
          sum_valid <= 1;
          seq_count <= idx + 1;
          idx       <= '0;
        end
      end
    end
  end

endmodule


// MODULE 4: Reciprocal LUT + Fixed-Point Multiplier
// Computes softmax[i] = exp2[i] / sum  ≈  exp2[i] * (1/sum)
// Uses reciprocal LUT indexed by upper bits of sum
// Output: Q0.8 probability per element

module divider_recip
  import softmax_pkg::*;
(
  input  logic                     clk,
  input  logic                     rst_n,

  input  logic [LUT_FRAC_W-1:0]    exp2_buf [0:SEQ_LEN-1],
  input  logic [IDX_W-1:0]         seq_count,
  input  logic [ACCUM_W-1:0]       sum_in,
  input  logic                     sum_valid,

  output logic [OUT_W-1:0]         softmax_out,
  output logic                     out_valid,
  output logic                     out_last
);

  // Initialize LUT table
  logic [RECIP_W-1:0] recip_lut [0:255];
  initial begin
    recip_lut[0] = 16'hFFFF;
    for (int i = 1; i < 256; i++) begin
      recip_lut[i] = 65536 / i;
    end
  end

  typedef enum logic [1:0] {WAIT_SUM, COMPUTE, DONE} state_t;
  state_t state;

  logic [RECIP_W-1:0]  recip_val;
  logic [IDX_W-1:0]    rd_idx;
  logic [4:0]          shift_out; // Register storing the dynamic shift value

  // Find MSB using standard combinational logic
  logic [4:0] msb_pos;
  always_comb begin
    msb_pos = 0;
    for (int b = ACCUM_W-1; b >= 0; b--) begin
      if (sum_in[b] && msb_pos == 0) msb_pos = b[4:0];
    end
  end

  // Take combinational index 
  logic [7:0] sum_idx_comb;
  always_comb begin
    if (msb_pos >= 7) sum_idx_comb = sum_in[msb_pos -: 8];
    else              sum_idx_comb = sum_in[7:0];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= WAIT_SUM;
      rd_idx      <= '0;
      out_valid   <= 0;
      out_last    <= 0;
      softmax_out <= '0;
    end else begin
      out_valid <= 0;
      out_last  <= 0;

      case (state)
        WAIT_SUM: begin
          if (sum_valid) begin
            // Use combinational value to lookup table immediately
            recip_val <= recip_lut[sum_idx_comb]; 
            
            // Calculate the number of bits to shift for dynamic compensation
            shift_out <= (msb_pos >= 7) ? (msb_pos + 1) : 8; 
            
            rd_idx    <= '0;
            state     <= COMPUTE;
          end
        end

        COMPUTE: begin
          logic [24:0] product;
          product     = exp2_buf[rd_idx] * recip_val;
          
          // Dynamically shift according to MSB scale to obtain correct Q0.8
          softmax_out <= product >> shift_out; 
          
          out_valid   <= 1;
          out_last    <= (rd_idx == seq_count - 1);
          rd_idx      <= rd_idx + 1;
          
          if (rd_idx == seq_count - 1) state <= WAIT_SUM;
        end
        
        default: state <= WAIT_SUM;
      endcase
    end
  end
endmodule


// TOP: Base-2 Softmax Pipeline
// Full pipeline integrating all 4 stages
module Softmax
  import softmax_pkg::*;
(
  input  logic                     clk,
  input  logic                     rst_n,

  // Input: streaming Q3.4 values
  input  logic signed [DATA_W-1:0] x_in,
  input  logic                     x_valid,
  input  logic                     x_last,    // pulse on last element
  output logic                     x_ready,   // backpressure

  // Output: Q0.8 probabilities, streamed
  output logic [OUT_W-1:0]         prob_out,
  output logic                     prob_valid,
  output logic                     prob_last
);

  // --- Stage 1 <-> Stage 2 signals ---
  logic signed [DATA_W-1:0] x_sub;
  logic                     x_sub_valid, x_sub_last;

  // --- Stage 2 <-> Stage 3 signals ---
  logic [LUT_FRAC_W-1:0]    exp2_val;
  logic                     exp2_valid, exp2_last;

  // --- Stage 3 <-> Stage 4 signals ---
  logic [LUT_FRAC_W-1:0]    exp2_buf [0:SEQ_LEN-1];
  logic [IDX_W-1:0]         seq_count;
  logic [ACCUM_W-1:0]       sum_out;
  logic                     sum_valid;

  // Busy signal from stage 1 controls x_ready
  logic stage1_busy;
  assign x_ready = ~stage1_busy;

  // --- Instantiate Stage 1 ---
  find_max_sub u_find_max_sub (
    .clk        (clk),
    .rst_n      (rst_n),
    .x_in       (x_in),
    .x_valid    (x_valid & x_ready),
    .x_last     (x_last),
    .x_sub      (x_sub),
    .x_sub_valid(x_sub_valid),
    .x_sub_last (x_sub_last),
    .busy       (stage1_busy)
  );

  // --- Instantiate Stage 2 ---
  hybrid_exp_engine u_exp_engine (
    .clk       (clk),
    .rst_n     (rst_n),
    .x_safe    (x_sub),
    .x_valid   (x_sub_valid),
    .x_last    (x_sub_last),
    .exp2_out  (exp2_val),
    .exp2_valid(exp2_valid),
    .exp2_last (exp2_last)
  );

  // --- Instantiate Stage 3 ---
  denom_accumulator u_accum (
    .clk       (clk),
    .rst_n     (rst_n),
    .exp2_in   (exp2_val),
    .exp2_valid(exp2_valid),
    .exp2_last (exp2_last),
    .exp2_buf  (exp2_buf),
    .seq_count (seq_count),
    .sum_out   (sum_out),
    .sum_valid (sum_valid)
  );

  // --- Instantiate Stage 4 ---
  divider_recip u_divider (
    .clk        (clk),
    .rst_n      (rst_n),
    .exp2_buf   (exp2_buf),
    .seq_count  (seq_count),
    .sum_in     (sum_out),
    .sum_valid  (sum_valid),
    .softmax_out(prob_out),
    .out_valid  (prob_valid),
    .out_last   (prob_last)
  );

endmodule

