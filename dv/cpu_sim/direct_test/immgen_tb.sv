// -----------------------------------------------------------------------------
// Copyright (c) 2026 NGUYEN TO QUOC VIET
// Ho Chi Minh City University of Technology (HCMUT-VNU)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit Processor
// Module       : immgen_tb
// Description  : Testbench for Immediate Generator — verifies sign-extension
//                and bit scrambling for all 6 RV32I immediate formats:
//                I, S, B, U, J, R (zero immediate)
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-02
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module immgen_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] instr;
    logic [DATA_WIDTH-1:0] imm;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    immgen dut (
        .instr (instr),
        .imm   (imm)
    );

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    task check_imm;
        input logic [DATA_WIDTH-1:0] test_instr;
        input logic [DATA_WIDTH-1:0] expected;

        logic [DATA_WIDTH-1:0] got;

        begin
            instr = test_instr;
            #1;
            got = imm;

            if (got === expected) begin
                $display("PASS | instr=%h -> imm=%h", test_instr, got);
                pass_count++;
            end else begin
                $display("FAIL | instr=%h -> got=%h, expected=%h", test_instr, got, expected);
                fail_count++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Instruction encoding helpers 
    // -------------------------------------------------------------------------

    // I-type: {imm[11:0], rs1[4:0], funct3[2:0], rd[4:0], opcode[6:0]}
    function automatic logic [31:0] build_I;
        input logic [11:0] imm12;
        input logic [4:0]  rs1, rd;
        input logic [2:0]  funct3;
        input logic [6:0]  opcode;
        return {imm12, rs1, funct3, rd, opcode};
    endfunction

    // S-type: {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode}
    function automatic logic [31:0] build_S;
        input logic [11:0] imm12;
        input logic [4:0]  rs2, rs1;
        input logic [2:0]  funct3;
        input logic [6:0]  opcode;
        return {imm12[11:5], rs2, rs1, funct3, imm12[4:0], opcode};
    endfunction

    // B-type: {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode}
    function automatic logic [31:0] build_B;
        input logic [12:0] imm13;   // imm13[0] is always 0, ignored
        input logic [4:0]  rs2, rs1;
        input logic [2:0]  funct3;
        input logic [6:0]  opcode;
        return {imm13[12], imm13[10:5], rs2, rs1, funct3, imm13[4:1], imm13[11], opcode};
    endfunction

    // U-type: {imm[31:12], rd, opcode}
    function automatic logic [31:0] build_U;
        input logic [19:0] imm20;
        input logic [4:0]  rd;
        input logic [6:0]  opcode;
        return {imm20, rd, opcode};
    endfunction

    // J-type: {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode}
    function automatic logic [31:0] build_J;
        input logic [20:0] imm21;   // imm21[0] is always 0, ignored
        input logic [4:0]  rd;
        input logic [6:0]  opcode;
        return {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, opcode};
    endfunction

    // R-type: {funct7, rs2, rs1, funct3, rd, opcode}
    function automatic logic [31:0] build_R;
        input logic [6:0] funct7;
        input logic [4:0] rs2, rs1, rd;
        input logic [2:0] funct3;
        input logic [6:0] opcode;
        return {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    // -------------------------------------------------------------------------
    // Test vectors
    // -------------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        // --- I-type: OP_I_ALU (ADDI x1, x0, imm) ---
        // positive small
        check_imm(build_I(12'd5,    5'd0, 5'd1, 3'b000, OP_I_ALU), 32'h00000005);
        check_imm(build_I(12'd1,    5'd0, 5'd1, 3'b000, OP_I_ALU), 32'h00000001);
        check_imm(build_I(12'd2047, 5'd0, 5'd1, 3'b000, OP_I_ALU), 32'h000007FF);  // max positive

        // negative (sign extend from bit 11)
        check_imm(build_I(12'hFFF,  5'd0, 5'd1, 3'b000, OP_I_ALU), 32'hFFFFFFFF);  // -1
        check_imm(build_I(12'h800,  5'd0, 5'd1, 3'b000, OP_I_ALU), 32'hFFFFF800);  // -2048 (min)
        check_imm(build_I(12'hFFE,  5'd0, 5'd1, 3'b000, OP_I_ALU), 32'hFFFFFFFE);  // -2

        // zero
        check_imm(build_I(12'd0,    5'd0, 5'd1, 3'b000, OP_I_ALU), 32'h00000000);

        // --- I-type: OP_I_LOAD (LW x1, imm(x2)) ---
        check_imm(build_I(12'd8,    5'd2, 5'd1, 3'b010, OP_I_LOAD), 32'h00000008);
        check_imm(build_I(12'hFFF,  5'd2, 5'd1, 3'b010, OP_I_LOAD), 32'hFFFFFFFF);  // -1

        // --- I-type: OP_I_JALR (JALR x1, imm(x2)) ---
        check_imm(build_I(12'd4,    5'd2, 5'd1, 3'b000, OP_I_JALR), 32'h00000004);
        check_imm(build_I(12'hFFC,  5'd2, 5'd1, 3'b000, OP_I_JALR), 32'hFFFFFFFC);  // -4

        // --- S-type: OP_S (SW x1, imm(x2)) ---
        // positive
        check_imm(build_S(12'd8,    5'd1, 5'd2, 3'b010, OP_S), 32'h00000008);
        check_imm(build_S(12'd4,    5'd1, 5'd2, 3'b010, OP_S), 32'h00000004);
        check_imm(build_S(12'd2047, 5'd1, 5'd2, 3'b010, OP_S), 32'h000007FF);  // max positive

        // negative (sign extend)
        check_imm(build_S(12'hFFF,  5'd1, 5'd2, 3'b010, OP_S), 32'hFFFFFFFF);  // -1
        check_imm(build_S(12'hFFC,  5'd1, 5'd2, 3'b010, OP_S), 32'hFFFFFFFC);  // -4
        check_imm(build_S(12'h800,  5'd1, 5'd2, 3'b010, OP_S), 32'hFFFFF800);  // -2048

        // zero
        check_imm(build_S(12'd0,    5'd1, 5'd2, 3'b010, OP_S), 32'h00000000);

        // --- B-type: OP_B (BEQ x1, x2, imm) ---
        // positive offsets (word-aligned, bit[0]=0 always)
        check_imm(build_B(13'h0008, 5'd2, 5'd1, 3'b000, OP_B), 32'h00000008);   // +8
        check_imm(build_B(13'h0004, 5'd2, 5'd1, 3'b000, OP_B), 32'h00000004);   // +4
        check_imm(build_B(13'h0FFE, 5'd2, 5'd1, 3'b000, OP_B), 32'h00000FFE);   // max positive (+4094)

        // negative offsets
        check_imm(build_B(13'h1FF8, 5'd2, 5'd1, 3'b000, OP_B), 32'hFFFFFFF8);   // -8
        check_imm(build_B(13'h1FFC, 5'd2, 5'd1, 3'b000, OP_B), 32'hFFFFFFFC);   // -4
        check_imm(build_B(13'h1000, 5'd2, 5'd1, 3'b000, OP_B), 32'hFFFFF000);   // -4096 (min)

        // zero
        check_imm(build_B(13'h0000, 5'd2, 5'd1, 3'b000, OP_B), 32'h00000000);

        // --- U-type: OP_U_LUI (LUI x1, imm) ---
        // upper 20 bits pass through, lower 12 bits zeroed
        check_imm(build_U(20'h12345, 5'd1, OP_U_LUI), 32'h12345000);
        check_imm(build_U(20'hFFFFF, 5'd1, OP_U_LUI), 32'hFFFFF000);
        check_imm(build_U(20'h00001, 5'd1, OP_U_LUI), 32'h00001000);
        check_imm(build_U(20'h00000, 5'd1, OP_U_LUI), 32'h00000000);
        check_imm(build_U(20'h80000, 5'd1, OP_U_LUI), 32'h80000000);

        // --- U-type: OP_U_AUIPC (AUIPC x1, imm) ---
        check_imm(build_U(20'hABCDE, 5'd1, OP_U_AUIPC), 32'hABCDE000);
        check_imm(build_U(20'h00000, 5'd1, OP_U_AUIPC), 32'h00000000);

        // --- J-type: OP_J (JAL x1, imm) ---
        // positive offsets
        check_imm(build_J(21'h000008, 5'd1, OP_J), 32'h00000008);   // +8
        check_imm(build_J(21'h000004, 5'd1, OP_J), 32'h00000004);   // +4
        check_imm(build_J(21'h0FFFFE, 5'd1, OP_J), 32'h000FFFFE);   // near max positive

        // negative offsets
        check_imm(build_J(21'h1FFFF8, 5'd1, OP_J), 32'hFFFFFFF8);   // -8
        check_imm(build_J(21'h1FFFFC, 5'd1, OP_J), 32'hFFFFFFFC);   // -4
        check_imm(build_J(21'h100000, 5'd1, OP_J), 32'hFFF00000);   // min (-1048576)

        // zero
        check_imm(build_J(21'h000000, 5'd1, OP_J), 32'h00000000);

        // --- R-type: OP_R (ADD x1, x2, x3) → imm always 0 ---
        check_imm(build_R(7'b0000000, 5'd3, 5'd2, 5'd1, 3'b000, OP_R), 32'h00000000);
        check_imm(build_R(7'b0100000, 5'd3, 5'd2, 5'd1, 3'b000, OP_R), 32'h00000000);  // SUB — still 0
        check_imm(build_R(7'b1111111, 5'd31, 5'd31, 5'd31, 3'b111, OP_R), 32'h00000000);

        // --- default opcode → imm = 0 ---
        check_imm(32'hDEAD_BEEF & ~32'h7F | 32'h7F, 32'h00000000);  // opcode=0x7F (invalid)
        check_imm(32'h00000000, 32'h00000000);                        // all zeros

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("IMMGEN TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
