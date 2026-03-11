module mux41_8bit (
  input  logic [7:0] a, b, c, d,
  input  logic [1:0] sel,
  output logic [7:0] y
);
  genvar i;
  generate
    for (i = 0; i < 8; i++) begin : G
      mux41 u_mux_bit (
        .a   (a[i]),
        .b   (b[i]),
        .c   (c[i]),
        .d   (d[i]),
        .sel (sel),
        .y   (y[i])
      );
    end
  endgenerate
endmodule
module mux21_16bit (
  input  logic [15:0] a, b,
  input  logic        sel,
  output logic [15:0] y
);
  genvar i;
  generate
    for (i = 0; i < 16; i++) begin : G
      mux21 u_mux (
        .a   (a[i]),
        .b   (b[i]),
        .sel (sel),
        .y   (y[i])
      );
    end
  endgenerate
endmodule


module mux41 (
  input  logic      a, b, c, d,
  input  logic [1:0] sel,    
  output logic      y
);
  logic ab, cd;

  mux21 u0 (.a(a), .b(b), .sel(sel[0]), .y(ab));
  mux21 u1 (.a(c), .b(d), .sel(sel[0]), .y(cd));

  mux21 u2 (.a(ab), .b(cd), .sel(sel[1]), .y(y));
endmodule


module mux81_32bit(
  input  logic [2:0]  sel,
  input  logic [31:0] a [0:7],
  output logic [31:0] y
);
  logic [31:0] l0 [0:3];
  logic [31:0] l1 [0:1];

  genvar i;
  generate
    for (i = 0; i < 4; i++) begin : G0
      mux21_32bit u (.sel(sel[0]), .a(a[2*i]), .b(a[2*i+1]), .y(l0[i]));
    end
    for (i = 0; i < 2; i++) begin : G1
      mux21_32bit u (.sel(sel[1]), .a(l0[2*i]), .b(l0[2*i+1]), .y(l1[i]));
    end
  endgenerate

  mux21_32bit u2 (.sel(sel[2]), .a(l1[0]), .b(l1[1]), .y(y));
endmodule

module mux21_32bit(
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic        sel,
  output logic [31:0] y
);
  genvar i;
  generate
    for (i = 0; i < 32; i++) begin : G_MUX
      mux21 u_mux21 (.a(a[i]), .b(b[i]), .sel(sel), .y(y[i]));
    end
  endgenerate
endmodule

module mux21_4bit(
  input  logic [3:0] a,
  input  logic [3:0] b,
  input  logic       sel,
  output logic [3:0] y
);
  genvar i;
  generate
    for (i = 0; i < 4; i++) begin : G_MUX
      mux21 u_mux21 (.a(a[i]), .b(b[i]), .sel(sel), .y(y[i]));
    end
  endgenerate
endmodule

module mux21(
  input  logic a,
  input  logic b,
  input  logic sel,
  output logic y
);
  assign y = sel ? b : a;
endmodule

module comp_u(
  input  logic [31:0] A, B,
  output logic        LT_u, EQ_u
);
  logic [31:0] ltl, eql;
  assign ltl[0] = ~A[0] & B[0];
  assign eql[0] = ~(A[0] ^ B[0]);

  generate
    genvar i;
    for (i = 1; i < 32; i++) begin : com
      double_compar_unsign block_compu(
        .lth(~A[i] & B[i]), .ltl(ltl[i-1]), .eqh(~(A[i] ^ B[i])), .eql(eql[i-1]),
        .lt(ltl[i]), .eq(eql[i])
      );
    end
  endgenerate

  assign LT_u = ltl[31];
  assign EQ_u = eql[31];
endmodule

module double_compar_unsign(
  input  logic lth, ltl, eqh, eql,
  output logic lt,  eq
);
  assign lt = lth | (eqh & ltl);
  assign eq = eqh & eql;
endmodule

module mux4to1(
  input  logic [31:0] a, b, c,
  input  logic [1:0]  sel,
  output logic [31:0] y
);
  always_comb begin
    case (sel)
      2'b00  : y = a;
      2'b01  : y = b;
      2'b10  : y = c;
      default: y = 32'b0;
    endcase
  end
endmodule

module a_reg(
  input  logic [31:0] d,
  input  logic        clk, en, rs,
  output logic [31:0] q
);
  generate
    genvar i;
    for (i = 0; i < 32; i++) begin : FF
      FF u_ff (.d(d[i]), .clk(clk), .en(en), .rs(rs), .q(q[i]));
    end
  endgenerate
endmodule

module FF(
  input  logic d, clk, en, rs,
  output logic q
);
  always_ff @(posedge clk or posedge rs) begin
    if (rs) q <= 1'b0;
    else if (en) q <= d;
  end
endmodule

module decoder532(
  input  logic [4:0]  i,
  input  logic        en,
  output logic [31:0] y
);
  assign y[0]  = en & ~i[4] & ~i[3] & ~i[2] & ~i[1] & ~i[0];
  assign y[1]  = en & ~i[4] & ~i[3] & ~i[2] & ~i[1] &  i[0];
  assign y[2]  = en & ~i[4] & ~i[3] & ~i[2] &  i[1] & ~i[0];
  assign y[3]  = en & ~i[4] & ~i[3] & ~i[2] &  i[1] &  i[0];
  assign y[4]  = en & ~i[4] & ~i[3] &  i[2] & ~i[1] & ~i[0];
  assign y[5]  = en & ~i[4] & ~i[3] &  i[2] & ~i[1] &  i[0];
  assign y[6]  = en & ~i[4] & ~i[3] &  i[2] &  i[1] & ~i[0];
  assign y[7]  = en & ~i[4] & ~i[3] &  i[2] &  i[1] &  i[0];
  assign y[8]  = en & ~i[4] &  i[3] & ~i[2] & ~i[1] & ~i[0];
  assign y[9]  = en & ~i[4] &  i[3] & ~i[2] & ~i[1] &  i[0];
  assign y[10] = en & ~i[4] &  i[3] & ~i[2] &  i[1] & ~i[0];
  assign y[11] = en & ~i[4] &  i[3] & ~i[2] &  i[1] &  i[0];
  assign y[12] = en & ~i[4] &  i[3] &  i[2] & ~i[1] & ~i[0];
  assign y[13] = en & ~i[4] &  i[3] &  i[2] & ~i[1] &  i[0];
  assign y[14] = en & ~i[4] &  i[3] &  i[2] &  i[1] & ~i[0];
  assign y[15] = en & ~i[4] &  i[3] &  i[2] &  i[1] &  i[0];
  assign y[16] = en &  i[4] & ~i[3] & ~i[2] & ~i[1] & ~i[0];
  assign y[17] = en &  i[4] & ~i[3] & ~i[2] & ~i[1] &  i[0];
  assign y[18] = en &  i[4] & ~i[3] & ~i[2] &  i[1] & ~i[0];
  assign y[19] = en &  i[4] & ~i[3] & ~i[2] &  i[1] &  i[0];
  assign y[20] = en &  i[4] & ~i[3] &  i[2] & ~i[1] & ~i[0];
  assign y[21] = en &  i[4] & ~i[3] &  i[2] & ~i[1] &  i[0];
  assign y[22] = en &  i[4] & ~i[3] &  i[2] &  i[1] & ~i[0];
  assign y[23] = en &  i[4] & ~i[3] &  i[2] &  i[1] &  i[0];
  assign y[24] = en &  i[4] &  i[3] & ~i[2] & ~i[1] & ~i[0];
  assign y[25] = en &  i[4] &  i[3] & ~i[2] & ~i[1] &  i[0];
  assign y[26] = en &  i[4] &  i[3] & ~i[2] &  i[1] & ~i[0];
  assign y[27] = en &  i[4] &  i[3] & ~i[2] &  i[1] &  i[0];
  assign y[28] = en &  i[4] &  i[3] &  i[2] & ~i[1] & ~i[0];
  assign y[29] = en &  i[4] &  i[3] &  i[2] & ~i[1] &  i[0];
  assign y[30] = en &  i[4] &  i[3] &  i[2] &  i[1] & ~i[0];
  assign y[31] = en &  i[4] &  i[3] &  i[2] &  i[1] &  i[0];
endmodule

module mux321_32bit(
  input  logic [31:0] a [31:0],
  input  logic [4:0]  sel,
  output logic [31:0] y
);
  genvar i;
  generate
    for (i = 0; i < 32; i++) begin : G
      mux321 u_bit_i (
        .a ({
          a[31][i], a[30][i], a[29][i], a[28][i],
          a[27][i], a[26][i], a[25][i], a[24][i],
          a[23][i], a[22][i], a[21][i], a[20][i],
          a[19][i], a[18][i], a[17][i], a[16][i],
          a[15][i], a[14][i], a[13][i], a[12][i],
          a[11][i], a[10][i], a[9][i],  a[8][i],
          a[7][i],  a[6][i],  a[5][i],  a[4][i],
          a[3][i],  a[2][i],  a[1][i],  a[0][i]
        }),
        .sel (sel),
        .y   (y[i])
      );
    end
  endgenerate
endmodule

module mux321(
  input  logic [31:0] a,
  input  logic [4:0]  sel,
  output logic        y
);
  logic [15:0] temp1;
  logic [7:0]  temp2;
  logic [3:0]  temp3;
  logic [1:0]  temp4;

  genvar i0;
  generate
    for (i0 = 0; i0 < 16; i0 = i0 + 1) begin : G1
      mux21 lev1 (.sel(sel[0]), .a(a[2*i0]), .b(a[2*i0+1]), .y(temp1[i0]));
    end
  endgenerate

  genvar i1;
  generate
    for (i1 = 0; i1 < 8; i1 = i1 + 1) begin : G2
      mux21 lev2 (.sel(sel[1]), .a(temp1[2*i1]), .b(temp1[2*i1+1]), .y(temp2[i1]));
    end
  endgenerate

  genvar i2;
  generate
    for (i2 = 0; i2 < 4; i2 = i2 + 1) begin : G3
      mux21 lev3 (.sel(sel[2]), .a(temp2[2*i2]), .b(temp2[2*i2+1]), .y(temp3[i2]));
    end
  endgenerate

  genvar i3;
  generate
    for (i3 = 0; i3 < 2; i3 = i3 + 1) begin : G4
      mux21 lev4 (.sel(sel[3]), .a(temp3[2*i3]), .b(temp3[2*i3+1]), .y(temp4[i3]));
    end
  endgenerate

  mux21 lev5 (.sel(sel[4]), .a(temp4[0]), .b(temp4[1]), .y(y));
endmodule

// -----------------------------------------------------------------------------
// 1-bit selector: y = (a & b) | (c & d)
// -----------------------------------------------------------------------------
module select_1bit (
  input  a, b, c, d,
  output logic y
);
  assign y = (a & b) | (c & d);
endmodule


// -----------------------------------------------------------------------------
// 4-bit selector: y = (a & b) | (c & d)
// -----------------------------------------------------------------------------
module select_4bit (
  input  [3:0] a, b, c, d,
  output logic [3:0] y
);
  assign y = (a & b) | (c & d);
endmodule


// -----------------------------------------------------------------------------
// 8-bit selector with enable: y = en & ((a & b) | (c & d))
// -----------------------------------------------------------------------------
module select_8bit (
  input  [7:0] a, b, c, d, en,
  output logic [7:0] y
);
  assign y = en & ((a & b) | (c & d));
endmodule


// -----------------------------------------------------------------------------
// 12-bit selector with enable: y = en & ((a & b) | (c & d))
// -----------------------------------------------------------------------------
module select_12bit (
  input  [11:0] a, b, c, d, en,
  output logic [11:0] y
);
  assign y = en & ((a & b) | (c & d));
endmodule
// =======================================================
// Shift wrapper (left or right with arithmetic option)
// - direction = 0 → left shift (SLL)
// - direction = 1 → right shift (SRL/SRA)
// - s (when direction=1): 0 → SRL, 1 → SRA
// =======================================================
module shift (
  input  logic [31:0] A, B,                 // A = data, B[4:0] = shift amount
  input  logic        direction,            // 0: left, 1: right
  input  logic        s,                    // SRL/SRA select when right
  output logic [31:0] result
);
  logic [31:0] temp0, temp1;

  // Left shifter (barrel)
  shift_left  block1(.rs(A), .off(B[4:0]), .rd(temp0));

  // Right shifter (barrel), arithmetic controlled by 's'
  shift_right block2(.rs(A), .off(B[4:0]), .s, .rd(temp1));

  // Select left or right
  mux21_32bit block3(.sel(direction), .a(temp0), .b(temp1), .y(result));
endmodule


// =======================================================
// Right barrel shifter (SRL/SRA via staged shifts)
// - s=0: logical right, s=1: arithmetic right
// =======================================================
module shift_right (
  input  logic [31:0] rs,            // source
  input  logic [4:0]  off,           // shift amount
  input  logic        s,             // 0: SRL, 1: SRA
  output logic [31:0] rd             // result
);
  logic        k;                    // fill bit for SRA
  assign k = rs[31] & s;

  logic [31:0] rs1, rs2, rs3, rs4;

  right_1  a1(.a(rs),  .rs1, .k, .en(off[0]));
  right_2  a2(.a(rs1), .rs2, .k, .en(off[1]));
  right_4  a3(.a(rs2), .rs3, .k, .en(off[2]));
  right_8  a4(.a(rs3), .rs4, .k, .en(off[3]));
  right_16 a5(.a(rs4), .rd,  .k, .en(off[4]));
endmodule


// 16-bit stage of right shift (fills MSBs with 'k' when enabled)
module right_16(
  input  logic [31:0] a,
  input  logic        en, k,
  output logic [31:0] rd
);
  generate
    genvar i;
    for (i = 31; i > 15; i--) begin : zero
      mux21 b(.a(a[i]), .b(k),        .sel(en), .y(rd[i]));
    end
  endgenerate

  generate
    genvar i1;
    for (i1 = 15; i1 >= 0; i1--) begin : b
      mux21 b(.a(a[i1]), .b(a[i1+16]), .sel(en), .y(rd[i1]));
    end
  endgenerate
endmodule


// 8-bit stage of right shift
module right_8(
  input  logic [31:0] a,
  input  logic        en, k,
  output logic [31:0] rs4
);
  generate
    genvar i;
    for (i = 31; i > 23; i--) begin : zero
      mux21 b(.a(a[i]), .b(k),        .sel(en), .y(rs4[i]));
    end
  endgenerate

  generate
    genvar i1;
    for (i1 = 23; i1 >= 0; i1--) begin : b
      mux21 b(.a(a[i1]), .b(a[i1+8]),  .sel(en), .y(rs4[i1]));
    end
  endgenerate
endmodule


// 4-bit stage of right shift
module right_4(
  input  logic [31:0] a,
  input  logic        en, k,
  output logic [31:0] rs3
);
  generate
    genvar i;
    for (i = 31; i > 27; i--) begin : zero
      mux21 b(.a(a[i]), .b(k),        .sel(en), .y(rs3[i]));
    end
  endgenerate

  generate
    genvar i1;
    for (i1 = 27; i1 >= 0; i1--) begin : b
      mux21 b(.a(a[i1]), .b(a[i1+4]),  .sel(en), .y(rs3[i1]));
    end
  endgenerate
endmodule


// 2-bit stage of right shift
module right_2(
  input  logic [31:0] a,
  input  logic        en, k,
  output logic [31:0] rs2
);
  mux21 b0(.a(a[31]), .b(k), .sel(en), .y(rs2[31]));
  mux21 b1(.a(a[30]), .b(k), .sel(en), .y(rs2[30]));

  generate
    genvar i;
    for (i = 29; i >= 0; i--) begin : g
      mux21 b(.a(a[i]), .b(a[i+2]), .sel(en), .y(rs2[i]));
    end
  endgenerate
endmodule


// 1-bit stage of right shift
module right_1(
  input  logic [31:0] a,
  input  logic        en, k,
  output logic [31:0] rs1
);
  mux21 b(.a(a[31]), .b(k), .sel(en), .y(rs1[31]));

  generate
    genvar i;
    for (i = 30; i >= 0; i--) begin : g
      mux21 b(.a(a[i]), .b(a[i+1]), .sel(en), .y(rs1[i]));
    end
  endgenerate
endmodule


// =======================================================
// Left barrel shifter (SLL via staged shifts)
// =======================================================
module shift_left (
  input  logic [31:0] rs,              // source
  input  logic [4:0]  off,             // shift amount
  output logic [31:0] rd               // result
);
  logic [31:0] rs1, rs2, rs3, rs4;

  left_1  a1(.a(rs),  .en(off[0]), .rs1);
  left_2  a2(.a(rs1), .en(off[1]), .rs2);
  left_4  a3(.a(rs2), .en(off[2]), .rs3);
  left_8  a4(.a(rs3), .en(off[3]), .rs4);
  left_16 a5(.a(rs4), .en(off[4]), .rd);
endmodule


// 16-bit stage of left shift (fills LSBs with zeros when enabled)
module left_16(
  input  logic [31:0] a,
  input  logic        en,
  output logic [31:0] rd
);
  generate
    genvar i;
    for (i = 0; i < 16; i++) begin : zero
      mux21 b(.a(a[i]), .b(1'b0),     .sel(en), .y(rd[i]));
    end
  endgenerate

  generate
    genvar i1;
    for (i1 = 16; i1 < 32; i1++) begin : b
      mux21 b(.a(a[i1]), .b(a[i1-16]), .sel(en), .y(rd[i1]));
    end
  endgenerate
endmodule


// 8-bit stage of left shift
module left_8(
  input  logic [31:0] a,
  input  logic        en,
  output logic [31:0] rs4
);
  generate
    genvar i;
    for (i = 0; i < 8; i++) begin : zero
      mux21 b(.a(a[i]), .b(1'b0),    .sel(en), .y(rs4[i]));
    end
  endgenerate

  generate
    genvar i1;
    for (i1 = 8; i1 < 32; i1++) begin : b
      mux21 b(.a(a[i1]), .b(a[i1-8]), .sel(en), .y(rs4[i1]));
    end
  endgenerate
endmodule


// 4-bit stage of left shift
module left_4(
  input  logic [31:0] a,
  input  logic        en,
  output logic [31:0] rs3
);
  generate
    genvar i;
    for (i = 0; i < 4; i++) begin : zero
      mux21 b(.a(a[i]), .b(1'b0),    .sel(en), .y(rs3[i]));
    end
  endgenerate

  generate
    genvar i1;
    for (i1 = 4; i1 < 32; i1++) begin : b
      mux21 b(.a(a[i1]), .b(a[i1-4]), .sel(en), .y(rs3[i1]));
    end
  endgenerate
endmodule


// 2-bit stage of left shift
module left_2(
  input  logic [31:0] a,
  input  logic        en,
  output logic [31:0] rs2
);
  mux21 b0(.a(a[0]), .b(1'b0), .sel(en), .y(rs2[0]));
  mux21 b1(.a(a[1]), .b(1'b0), .sel(en), .y(rs2[1]));

  generate
    genvar i;
    for (i = 2; i < 32; i++) begin : g
      mux21 b(.a(a[i]), .b(a[i-2]), .sel(en), .y(rs2[i]));
    end
  endgenerate
endmodule


// 1-bit stage of left shift
module left_1(
  input  logic [31:0] a,
  input  logic        en,
  output logic [31:0] rs1
);
  mux21 b(.a(a[0]), .b(1'b0), .sel(en), .y(rs1[0]));

  generate
    genvar i;
    for (i = 1; i < 32; i++) begin : g
      mux21 b(.a(a[i]), .b(a[i-1]), .sel(en), .y(rs1[i]));
    end
  endgenerate
endmodule


// =======================================================
// Comparator (unsigned and signed)
// - s=0: unsigned compare (LT_u/EQ_u from comp_u)
// - s=1: signed compare (derive LT_s using sign logic)
// =======================================================
module comparator (
  input  logic [31:0] A, B,    // operands
  input  logic        s,       // 0: unsigned, 1: signed
  output logic        LT, EQ   // less-than and equal flags
);
  logic EQ_u, LT_u, LT_s, LT_mag;  // unsigned LT/EQ, signed LT, magnitude LT for negated path

  // Unsigned comparator
  comp_u unsignedd(.A, .B, .LT_u, .EQ_u);

  // Sign bits (used for signed compare path)
  assign sa = A[31];
  assign sb = B[31];

  // Magnitude compare on bitwise-negated inputs for signed logic helper
  comp_u neg(.A(~A[31:0]), .B(~B[31:0]), .LT_u(LT_mag), .EQ_u());

  // Signed LT logic (classic 2's complement compare decomposition)
  assign LT_s = (sa & ~sb) | (~sa & ~sb & LT_u) | (sa & sb & ~(LT_mag | EQ));

  // Select unsigned vs signed LT
  mux21 comp_out(.y(LT), .sel(s), .a(LT_u), .b(LT_s));

  // Equality is shared
  assign EQ = EQ_u;
endmodule


// =======================================================
// Bitwise OR
// =======================================================
module logic_or (
  input  logic [31:0] A, B,
  output logic [31:0] result
);
  assign result = A | B;
endmodule


// =======================================================
// Bitwise AND
// =======================================================
module logic_and (
  input  logic [31:0] A, B,
  output logic [31:0] result
);
  assign result = A & B;
endmodule


// =======================================================
// Bitwise XOR (constructed from AND/NOT terms)
// =======================================================
module logic_xor (
  input  logic [31:0] A, B,
  output logic [31:0] result
);
  assign result = A & ~B | ~A & B;
endmodule


// =======================================================
// Add/Sub (ripple-carry with full adders)
// - t = 0 → result = A + B
// - t = 1 → result = A - B  (B XOR 1 + carry-in 1)
// =======================================================
module add_sub (
  input  logic [31:0] A, B,
  input  logic        t,                 // 0: add, 1: sub
  output logic [31:0] result,
  output logic        cout, ovf
);
  logic [32:0] c;                        // carry chain
  logic [31:0] bx;                       // B XOR mask

  // bx = B ^ t ; Cin = t
  assign c[0] = t;
  assign bx   = B ^ {32{t}};

  genvar i;
  generate
    for (i = 0; i < 32; i = i + 1) begin : G
      FA u_fa (
        .x  (A[i]),
        .y  (bx[i]),
        .z  (c[i]),
        .s  (result[i]),
        .cr (c[i+1])
      );
    end
  endgenerate

  assign cout = c[32];            // carry out (unsigned)
  assign ovf  = c[31] ^ c[32];    // overflow (signed)
endmodule
module mux41_32bit (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [31:0] c,
    input  logic [31:0] d,
    input  logic [1:0]  sel,   // sel[1:0]
    output logic [31:0] y
);

    logic [31:0] y0, y1;

    // Tầng 1: chọn giữa (a,b) và (c,d) theo sel[0]
    mux21_32bit u0 (
        .a   (a),
        .b   (b),
        .sel (sel[0]),
        .y   (y0)
    );

    mux21_32bit u1 (
        .a   (c),
        .b   (d),
        .sel (sel[0]),
        .y   (y1)
    );

    // Tầng 2: chọn giữa y0 và y1 theo sel[1]
    mux21_32bit u2 (
        .a   (y0),
        .b   (y1),
        .sel (sel[1]),
        .y   (y)
    );

endmodule 
module memory
(
  input  logic        i_clk,
  input  logic        i_reset,          // optional clear for sim
  input  logic [15:0] i_addr,           // BYTE address [0..65535]
  input  logic [31:0] i_wdata,          // from LSU (SB/SH/SW packed, unshifted)
  input  logic [3:0]  i_bmask,          // 0001=SB, 0011=SH, 1111=SW
  input  logic        i_wren,
  output logic [31:0] o_rdata
);

  localparam int WORDS = 65536/4;       // 16384 words
  logic [31:0] mem [0:WORDS-1];

  // Word index & byte offset
  wire [13:0] wi   = i_addr[15:2];
  wire [1:0]  off  = i_addr[1:0];
  wire [13:0] wi_n = (wi == WORDS-1) ? wi : (wi + 14'd1);

  // READ: ghép 2 word rồi dịch
  wire [63:0] r64 = {mem[wi_n], mem[wi]} >> (off*8);

  // WRITE: shift payload & mask theo off
  wire [63:0] w64_shift = {32'b0, i_wdata} << (off*8);
  wire [31:0] w_lo      = w64_shift[31:0];
  wire [31:0] w_hi      = w64_shift[63:32];

  wire [7:0]  m8_shift  = {4'b0000, i_bmask} << off;
  wire [3:0]  be_lo     = m8_shift[3:0];
  wire [3:0]  be_hi     = m8_shift[7:4];

  wire [31:0] m_lo = { {8{be_lo[3]}}, {8{be_lo[2]}}, {8{be_lo[1]}}, {8{be_lo[0]}} };
  wire [31:0] m_hi = { {8{be_hi[3]}}, {8{be_hi[2]}}, {8{be_hi[1]}}, {8{be_hi[0]}} };

 
  wire two_word = |be_hi;

  integer k;
  always_ff @(posedge i_clk) begin
    if (i_reset) begin
      for (k = 0; k < WORDS; k++) mem[k] <= '0;
      o_rdata <= '0;
    end else begin
      if (i_wren) begin
        mem[wi] <= (mem[wi] & ~m_lo) | (w_lo & m_lo);
        if (two_word && (m_hi != 32'b0))
          mem[wi_n] <= (mem[wi_n] & ~m_hi) | (w_hi & m_hi);
      end
      o_rdata <= r64[31:0];  // sync read
    end
  end

endmodule
/*
module memory
(
  input  logic        i_clk,
  input  logic        i_reset,          // optional clear for sim
  input  logic [15:0] i_addr,           // byte address [0..65535]
  input  logic [31:0] i_wdata,          // from LSU (SB/SH/SW packed)
  input  logic [3:0]  i_bmask,          // 0001=SB, 0011=SH, 1111=SW
  input  logic        i_wren,
  output logic [31:0] o_rdata
);

  // 64 KiB = 65536 bytes -> 16384 words (32-bit)
  localparam int WORDS = 65536/4;        // 16384 words

  // Word index and byte offset within the word
  wire [13:0] wi   = i_addr[15:2];
  wire [1:0]  off  = i_addr[1:0];
  wire [13:0] wi_n = (wi == WORDS-1) ? wi : (wi + 14'd1);

  // ===== WRITE: shift payload & mask by off, rồi tách thành 2 word =====
  wire [63:0] w64_shift = {32'b0, i_wdata} << (off*8);
  wire [31:0] w_lo      = w64_shift[31:0];
  wire [31:0] w_hi      = w64_shift[63:32];

  wire [7:0]  m8_shift  = {4'b0000, i_bmask} << off;
  wire [3:0]  be_lo     = m8_shift[3:0];
  wire [3:0]  be_hi     = m8_shift[7:4];

  // Có cần ghi sang word kế tiếp hay không
  wire two_word =|be_hi;

  // ===== BRAM instances =====
  wire [31:0] q_lo, q_hi;

  // word hiện tại
  dmem low_b (
    .data      (w_lo),
    .wraddress (wi[11:0]),
    .rdaddress (wi[11:0]),
    .byteena_a (be_lo),
    .clock     (i_clk),
    .wren      (i_wren),
    .rden      (1'b1),
    .q         (q_lo)
  );

  // word kế tiếp
  dmem hi_b (
    .data      (w_hi),
    .wraddress (wi_n[11:0]),
    .rdaddress (wi_n[11:0]),
    .byteena_a (be_hi),
    .clock     (i_clk),
    .wren      (i_wren & two_word),
    .rden      (two_word),
    .q         (q_hi)
  );

  // ===== READ: ghép 2 word lại rồi dịch phải theo off =====
  wire [63:0] r64 = {q_hi, q_lo} >> (off*8);
   wire [31:0] r32 = r64[31:0];
  assign o_rdata = r32;
   always_ff @(posedge i_clk) begin
    if (i_reset) begin
      o_rdata <= 32'b0;
    end else begin
      o_rdata <= r32;
    end
	end 
endmodule*/


module FA(
  input  logic x, y, z,   // z = carry in
  output logic s, cr      // s = sum, cr = carry out
);
  assign s  = x ^ y ^ z;
  assign cr = (x & y) | (x & z) | (y & z);
endmodule 
//====================================================
// PIPELINE REGISTER
//  - rs  : async reset (active high)
//  - clr : synchronous clear (flush → ghi NOP/giá trị mặc định)
//  - en  : enable (stall = 0 → en=0 → giữ nguyên)
//  - FLUSH_VALUE: giá trị ghi khi reset / flush (vd: NOP)
//====================================================
module a_reg_p #(
    parameter WIDTH = 32,
    parameter CLR_VALUE = 32'h0   // ADDI x0,x0,0 (NOP)
)(
    input  logic              clk,
    input  logic              rs,   // async reset, active-high
    input  logic              clr,   // synchronous clear (flush)
    input  logic              en,    // enable (stall control)
    input  logic [WIDTH-1:0]  d,
    output logic [WIDTH-1:0]  q
);

always_ff @(posedge clk or posedge rs) begin
    if (rs)
        q <= '0;                // Reset toàn bộ
    else if (clr)
        q <= CLR_VALUE;         // Ghi NOP vào pipeline (flush)
    else if (en)
        q <= d;                 // Bình thường: ghi dữ liệu mới
    else
        q <= q;                 // Stall: giữ nguyên
end

endmodule
module mux21_3bit (
  input  logic [2:0] a,
  input  logic [2:0] b,
  input  logic       sel,
  output logic [2:0] y
);

  genvar i;
  generate
    for (i = 0; i < 3; i++) begin : GEN_MUX21
      mux21 u_mux (
        .a   (a[i]),
        .b   (b[i]),
        .sel (sel),
        .y   (y[i])
      );
    end
  endgenerate

endmodule
module op_decode (
  input  logic [6:0] op,
  output logic       r,
  output logic       i,
  output logic       i_load,
  output logic       s,
  output logic       b,
  output logic       j,
  output logic       jalr,
  output logic       lui,
  output logic       auipc,
  output logic       sys
);

  // R-type: 0110011
  assign r =
    ~op[6] &  op[5] &  op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // I-type ALU: 0010011
  assign i =
    ~op[6] & ~op[5] &  op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // LOAD: 0000011
  assign i_load =
    ~op[6] & ~op[5] & ~op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // STORE: 0100011
  assign s =
    ~op[6] &  op[5] & ~op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // BRANCH: 1100011
  assign b =
     op[6] &  op[5] & ~op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // JAL: 1101111
  assign j =
     op[6] &  op[5] & ~op[4] &
     op[3] &  op[2] &  op[1] & op[0];

  // JALR: 1100111
  assign jalr =
     op[6] &  op[5] & ~op[4] &
    ~op[3] &  op[2] &  op[1] & op[0];

  // LUI: 0110111
  assign lui =
    ~op[6] &  op[5] &  op[4] &
    ~op[3] &  op[2] &  op[1] & op[0];

  // AUIPC: 0010111
  assign auipc =
    ~op[6] & ~op[5] &  op[4] &
    ~op[3] &  op[2] &  op[1] & op[0];

  // SYSTEM: 1110011
  assign sys =
     op[6] &  op[5] &  op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

endmodule

module mux21_nbit #(
  parameter int N = 32
)(
  input  logic [N-1:0] a,
  input  logic [N-1:0] b,
  input  logic         sel,
  output logic [N-1:0] y
);

  genvar i;
  generate
    for (i = 0; i < N; i++) begin : G
      mux21 u_mux21 (
        .a   (a[i]),
        .b   (b[i]),
        .sel (sel),
        .y   (y[i])
      );
    end
  endgenerate

endmodule