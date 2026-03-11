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
  parameter int DATA_W     = 8;    // Input width (Q3.4)
  parameter int FRAC_BITS  = 4;    // Fractional bits
  parameter int INT_BITS   = 3;    // Integer bits (sign included)
  parameter int SEQ_LEN    = 64;   // Max sequence length
  parameter int ARRAY_SIZE = 4;    // Số phần tử xử lý song song trong 1 chu kỳ (Vector size)
  parameter int VEC_CYCLES = SEQ_LEN / ARRAY_SIZE; // Số chu kỳ cần để load 1 sequence
  parameter int ACCUM_W    = 32;   // Accumulator width
  parameter int OUT_W      = 8;    // Output width (Q0.8 probability)
  parameter int LUT_FRAC_W = 8;    // LUT output fractional width (2^0.y)
  parameter int RECIP_W    = 16;   // Reciprocal LUT output width
  parameter int IDX_W      = $clog2(VEC_CYCLES + 1); // Index width 
endpackage

`timescale 1ns / 1ps
import softmax_pkg::*;

// MODULE 1: Vector Find Max & Subtractor
module find_max_sub_vec (
  input  logic                      clk, rst_n,
  input  logic signed [DATA_W-1:0]  x_in [ARRAY_SIZE], // Nhận 1 Vector
  input  logic                      x_valid, x_last,

  output logic signed [DATA_W-1:0]  x_sub [ARRAY_SIZE], // Xuất 1 Vector
  output logic                      x_sub_valid, x_sub_last,
  output logic                      busy
);

  typedef enum logic [1:0] {FIND_MAX, REPLAY, IDLE} state_t;
  state_t state, next_state;

  logic signed [DATA_W-1:0] max_val, vec_max;
  logic signed [DATA_W-1:0] buf_mem [0:VEC_CYCLES-1][ARRAY_SIZE]; 
  logic [IDX_W-1:0]         wr_ptr, rd_ptr, seq_len_reg;

  // Combinational Tree: Find Max of Vector 
  always_comb begin
    vec_max = x_in[0];
    for (int i = 1; i < ARRAY_SIZE; i++) begin
      if (x_in[i] > vec_max) vec_max = x_in[i];
    end
  end

  // FSM Logic 
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE:     if (x_valid)                 next_state = FIND_MAX;
      FIND_MAX: if (x_valid && x_last)       next_state = REPLAY;
      REPLAY:   if (rd_ptr == seq_len_reg-1) next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_val <= '1 << (DATA_W-1); 
      wr_ptr <= '0; seq_len_reg <= '0;
    end else if (state == IDLE && x_valid) begin
      max_val <= vec_max;
      for(int i=0; i<ARRAY_SIZE; i++) buf_mem[0][i] <= x_in[i];
      wr_ptr <= 1;
    end else if (state == FIND_MAX && x_valid) begin
      for(int i=0; i<ARRAY_SIZE; i++) buf_mem[wr_ptr][i] <= x_in[i];
      if (vec_max > max_val) max_val <= vec_max;
      wr_ptr <= wr_ptr + 1;
      if (x_last) seq_len_reg <= wr_ptr + 1;
    end
  end

  // Replay Phase: Read Vector and Subtrator
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rd_ptr <= '0;
    else if (state == REPLAY) rd_ptr <= rd_ptr + 1;
    else if (state != REPLAY) rd_ptr <= '0;
  end

  always_comb begin
    for (int i = 0; i < ARRAY_SIZE; i++) begin
      x_sub[i] = (state == REPLAY) ? (buf_mem[rd_ptr][i] - max_val) : '0;
    end
  end

  assign x_sub_valid = (state == REPLAY);
  assign x_sub_last  = (state == REPLAY) && (rd_ptr == seq_len_reg - 1);
  assign busy        = (state == REPLAY);
endmodule

// MODULE 2: Vector Hybrid Exponent Engine
module hybrid_exp_engine_vec (
  input  logic                      clk, rst_n,
  input  logic signed [DATA_W-1:0]  x_safe [ARRAY_SIZE],
  input  logic                      x_valid, x_last,
  
  output logic [LUT_FRAC_W-1:0]     exp2_out [ARRAY_SIZE],
  output logic                      exp2_valid, exp2_last
);

  logic [LUT_FRAC_W-1:0] frac_lut [0:15];
  initial begin
    // LUT Table 
    frac_lut[0]=128; frac_lut[1]=134; frac_lut[2]=139; frac_lut[3]=144;
    frac_lut[4]=150; frac_lut[5]=156; frac_lut[6]=162; frac_lut[7]=169;
    frac_lut[8]=181; frac_lut[9]=188; frac_lut[10]=195; frac_lut[11]=203;
    frac_lut[12]=211; frac_lut[13]=220; frac_lut[14]=229; frac_lut[15]=238;
  end

  logic [LUT_FRAC_W-1:0] lut_val_s1 [ARRAY_SIZE];
  logic [INT_BITS:0]     int_bits_s1 [ARRAY_SIZE];
  logic                  valid_s1, last_s1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_s1 <= 0; last_s1 <= 0;
    end else begin
      for (int i = 0; i < ARRAY_SIZE; i++) begin
        int_bits_s1[i] <= x_safe[i][DATA_W-1:FRAC_BITS];
        lut_val_s1[i]  <= frac_lut[x_safe[i][FRAC_BITS-1:0]];
      end
      valid_s1 <= x_valid;
      last_s1  <= x_last;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      exp2_valid <= 0; exp2_last <= 0;
    end else begin
      for (int i = 0; i < ARRAY_SIZE; i++) begin
        exp2_out[i] <= lut_val_s1[i] >> (-int_bits_s1[i]); // Shift Right 
      end
      exp2_valid <= valid_s1;
      exp2_last  <= last_s1;
    end
  end
endmodule

// MODULE 3: Vector Denominator Accumulator
module denom_accumulator_vec (
  input  logic                      clk, rst_n,
  input  logic [LUT_FRAC_W-1:0]     exp2_in [ARRAY_SIZE],
  input  logic                      exp2_valid, exp2_last,

  output logic [LUT_FRAC_W-1:0]     exp2_buf [0:VEC_CYCLES-1][ARRAY_SIZE],
  output logic [IDX_W-1:0]          seq_count,
  output logic [ACCUM_W-1:0]        sum_out,
  output logic                      sum_valid
);

  logic [ACCUM_W-1:0] accum;
  logic [IDX_W-1:0]   idx;
  logic [ACCUM_W-1:0] vec_sum;

  // Sum of vector in 1 cycle
  always_comb begin
    vec_sum = 0;
    for (int i = 0; i < ARRAY_SIZE; i++) vec_sum += exp2_in[i];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      accum <= '0; idx <= '0; sum_valid <= 0; seq_count <= '0;
    end else begin
      sum_valid <= 0;
      if (exp2_valid) begin
        if (idx == 0) accum <= vec_sum;
        else          accum <= accum + vec_sum;
        
        for (int i = 0; i < ARRAY_SIZE; i++) exp2_buf[idx][i] <= exp2_in[i];
        idx <= idx + 1;
        
        if (exp2_last) begin
          sum_out   <= accum + vec_sum;
          sum_valid <= 1;
          seq_count <= idx + 1;
          idx       <= '0;
        end
      end
    end
  end
endmodule

// STAGE 4: Vector Divider (Reciprocal LUT + Parallel Multipliers)
module divider_recip_vec (
  input  logic                      clk, rst_n,
  input  logic [LUT_FRAC_W-1:0]     exp2_buf [0:VEC_CYCLES-1][ARRAY_SIZE],
  input  logic [IDX_W-1:0]          seq_count,
  input  logic [ACCUM_W-1:0]        sum_in,
  input  logic                      sum_valid,

  output logic [OUT_W-1:0]          softmax_out [ARRAY_SIZE],
  output logic                      out_valid, out_last
);

  // Instantiate LUT table
  logic [RECIP_W-1:0] recip_lut [0:255];
  initial begin
    recip_lut[0] = 16'hFFFF;
    for (int i = 1; i < 256; i++) recip_lut[i] = 65536 / i;
  end

  typedef enum logic [1:0] {WAIT_SUM, COMPUTE} state_t;
  state_t state;

  logic [RECIP_W-1:0] recip_val;
  logic [IDX_W-1:0]   rd_idx;
  logic [4:0]         shift_out;

  // Logic find MSB
  logic [4:0] msb_pos;
  always_comb begin
    msb_pos = 0;
    for (int b = ACCUM_W-1; b >= 0; b--) begin
      if (sum_in[b] && msb_pos == 0) msb_pos = b[4:0];
    end
  end

  logic [7:0] sum_idx_comb;
  assign sum_idx_comb = (msb_pos >= 7) ? sum_in[msb_pos -: 8] : sum_in[7:0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= WAIT_SUM; rd_idx <= '0; out_valid <= 0; out_last <= 0;
    end else begin
      out_valid <= 0; out_last <= 0;
      case (state)
        WAIT_SUM: begin
          if (sum_valid) begin
            recip_val <= recip_lut[sum_idx_comb]; 
            shift_out <= (msb_pos >= 7) ? (msb_pos + 1) : 8; 
            rd_idx    <= '0;
            state     <= COMPUTE;
          end
        end
        COMPUTE: begin
          // Mutiply and shift bit parallel element in ARRAY_SIZE 
          for (int i = 0; i < ARRAY_SIZE; i++) begin
            logic [24:0] product;
            product = exp2_buf[rd_idx][i] * recip_val;
            softmax_out[i] <= product >> shift_out; 
          end
          
          out_valid <= 1;
          out_last  <= (rd_idx == seq_count - 1);
          rd_idx    <= rd_idx + 1;
          
          if (rd_idx == seq_count - 1) state <= WAIT_SUM;
        end
      endcase
    end
  end
endmodule



// TOP: Vectorized Base-2 Softmax Pipeline
// Full pipeline integrating all 4 vector stages
module Softmax
  import softmax_pkg::*;
(
  input  logic                      clk,
  input  logic                      rst_n,

  // Input: streaming Q3.4 values (Now receiving a full Vector of ARRAY_SIZE)
  input  logic signed [DATA_W-1:0]  x_in [ARRAY_SIZE],
  input  logic                      x_valid,
  input  logic                      x_last,    // pulse on last vector
  output logic                      x_ready,   // backpressure

  // Output: Q0.8 probabilities, streamed (Now outputting a full Vector of ARRAY_SIZE)
  output logic [OUT_W-1:0]          prob_out [ARRAY_SIZE],
  output logic                      prob_valid,
  output logic                      prob_last
);

  // --- Stage 1 <-> Stage 2 signals ---
  logic signed [DATA_W-1:0] x_sub [ARRAY_SIZE];
  logic                     x_sub_valid, x_sub_last;

  // --- Stage 2 <-> Stage 3 signals ---
  logic [LUT_FRAC_W-1:0]    exp2_val [ARRAY_SIZE];
  logic                     exp2_valid, exp2_last;

  // --- Stage 3 <-> Stage 4 signals ---
  // Buffer now holds rows of vectors, up to VEC_CYCLES
  logic [LUT_FRAC_W-1:0]    exp2_buf [0:VEC_CYCLES-1][ARRAY_SIZE];
  logic [IDX_W-1:0]         seq_count;
  logic [ACCUM_W-1:0]       sum_out;
  logic                     sum_valid;

  // Busy signal from stage 1 controls x_ready
  logic stage1_busy;
  assign x_ready = ~stage1_busy;

  // --- Instantiate Stage 1 (Vector Version) ---
  find_max_sub_vec u_find_max_sub (
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

  // --- Instantiate Stage 2 (Vector Version) ---
  hybrid_exp_engine_vec u_exp_engine (
    .clk        (clk),
    .rst_n      (rst_n),
    .x_safe     (x_sub),
    .x_valid    (x_sub_valid),
    .x_last     (x_sub_last),
    .exp2_out   (exp2_val),
    .exp2_valid (exp2_valid),
    .exp2_last  (exp2_last)
  );

  // --- Instantiate Stage 3 (Vector Version) ---
  denom_accumulator_vec u_accum (
    .clk        (clk),
    .rst_n      (rst_n),
    .exp2_in    (exp2_val),
    .exp2_valid (exp2_valid),
    .exp2_last  (exp2_last),
    .exp2_buf   (exp2_buf),
    .seq_count  (seq_count),
    .sum_out    (sum_out),
    .sum_valid  (sum_valid)
  );

  // --- Instantiate Stage 4 (Vector Version) ---
  divider_recip_vec u_divider (
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

