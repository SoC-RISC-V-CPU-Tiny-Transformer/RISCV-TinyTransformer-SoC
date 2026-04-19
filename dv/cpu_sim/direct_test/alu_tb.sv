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
// Module       : alu_tb
// Description  : Testbench for ALU — verifies all 11 RV32I operations:
//                ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, PASS_B
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-02
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module alu_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic [3:0]            alu_op;
    logic [DATA_WIDTH-1:0] src_a;
    logic [DATA_WIDTH-1:0] src_b;
    logic [DATA_WIDTH-1:0] result;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    alu dut (
        .alu_op (alu_op),
        .src_a  (src_a),
        .src_b  (src_b),
        .result (result)
    );

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    // Task: apply stimulus, wait for combinational settle, check result
    
    task check_result;
        input logic [3:0] op;
        input logic [DATA_WIDTH-1:0] a, b, expected;

        logic [DATA_WIDTH-1:0] got;

        begin
            alu_op  = op;
            src_a   = a;
            src_b   = b;
            #1;
            got     = result;

            if (got === expected) begin
                $display("PASS | OP=%b A=%d B=%d RESULT=%d", op, a, b, got);
                pass_count++;
            end else begin
                $display("FAIL | OP=%b A=%d B=%d RESULT=%d, EXPECTED=%d", op, a, b, got, expected);
                fail_count++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test vectors
    // -------------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        // --- ALU_ADD ---
        // normal addition
        check_result(ALU_ADD, 5, 3, 8);
        check_result(ALU_ADD, 12, 24, 36);
        check_result(ALU_ADD, 123, 456, 579);
        check_result(ALU_ADD, 1234, 5678, 6912);
        check_result(ALU_ADD, 12345, 67890, 80235);

        // addition with overflow (wrap-around)
        check_result(ALU_ADD, 32'hFFFF_FFFF, 1, 0);

        // add zero: a + 0 = a
        check_result(ALU_ADD, 36, 0, 36);
        check_result(ALU_ADD, 0, 0, 0);
        check_result(ALU_ADD, 32'hFFFF_FFFF, 0, 32'hFFFF_FFFF);

        // --- ALU_SUB ---
        // normal subtraction
        check_result(ALU_SUB, 10, 4, 6);
        check_result(ALU_SUB, 100, 55, 45);
        check_result(ALU_SUB, 32'hFFFF_FFFF, 32'hFFFF_FFFE, 1);

        // result = 0: a - a = 0
        check_result(ALU_SUB, 42, 42, 0);
        check_result(ALU_SUB, 0, 0, 0);

        // negative result (two's complement)
        check_result(ALU_SUB, 3, 5, 32'hFFFF_FFFE);
        check_result(ALU_SUB, 0, 1, 32'hFFFF_FFFF);

        // --- ALU_SLL (shift left logical) ---
        // normal shifts
        check_result(ALU_SLL, 1, 4, 16);
        check_result(ALU_SLL, 36, 5, 1152);
        check_result(ALU_SLL, 1, 0, 1);
        check_result(ALU_SLL, 32'h0000_0001, 31, 32'h8000_0000);

        // only lower 5 bits of src_b matter: shift by 32 (= 32 & 0x1F = 0) -> no shift
        check_result(ALU_SLL, 32'hABCD_1234, 32, 32'hABCD_1234);

        // shift out all bits
        check_result(ALU_SLL, 32'hFFFF_FFFF, 31, 32'h8000_0000);

        // --- ALU_SLT (signed less-than) ---
        // -1 < 1 signed -> 1
        check_result(ALU_SLT, 32'hFFFF_FFFF, 1, 1);
        // 1 < -1 signed -> 0
        check_result(ALU_SLT, 1, 32'hFFFF_FFFF, 0);
        // equal -> 0
        check_result(ALU_SLT, 5, 5, 0);
        // both negative: -2 < -1 -> 1
        check_result(ALU_SLT, 32'hFFFF_FFFE, 32'hFFFF_FFFF, 1);

        // --- ALU_SLTU (unsigned less-than) ---
        // 0xFFFFFFFF > 1 unsigned -> 0
        check_result(ALU_SLTU, 32'hFFFF_FFFF, 1, 0);
        // 1 < 0xFFFFFFFF unsigned -> 1
        check_result(ALU_SLTU, 1, 32'hFFFF_FFFF, 1);
        // same values -> 0
        check_result(ALU_SLTU, 32'hDEAD_BEEF, 32'hDEAD_BEEF, 0);
        // 0 < anything -> 1
        check_result(ALU_SLTU, 0, 1, 1);

        // --- ALU_XOR ---
        // a ^ a = 0
        check_result(ALU_XOR, 32'hDEAD_BEEF, 32'hDEAD_BEEF, 0);
        // a ^ 0 = a
        check_result(ALU_XOR, 32'hDEAD_BEEF, 0, 32'hDEAD_BEEF);
        // a ^ ~a = 0xFFFFFFFF
        check_result(ALU_XOR, 32'hDEAD_BEEF, 32'h2152_4110, 32'hFFFF_FFFF);
        // a ^ all-ones = ~a
        check_result(ALU_XOR, 32'hAAAA_AAAA, 32'hFFFF_FFFF, 32'h5555_5555);

        // --- ALU_SRL (shift right logical) ---
        // MSB = 1: zero fill (NOT sign extend)
        check_result(ALU_SRL, 32'h8000_0000, 1, 32'h4000_0000);
        check_result(ALU_SRL, 32'hFFFF_FFFF, 4, 32'h0FFF_FFFF);
        // shift by 0 -> unchanged
        check_result(ALU_SRL, 32'hDEAD_BEEF, 0, 32'hDEAD_BEEF);
        // only lower 5 bits of src_b matter: shift by 32 -> no shift
        check_result(ALU_SRL, 32'hABCD_1234, 32, 32'hABCD_1234);

        // --- ALU_SRA (shift right arithmetic) ---
        // negative number: sign fill with 1
        check_result(ALU_SRA, 32'h8000_0000, 1, 32'hC000_0000);
        check_result(ALU_SRA, 32'hFFFF_FFFF, 4, 32'hFFFF_FFFF);
        // positive number: sign fill with 0 — same as SRL
        check_result(ALU_SRA, 32'h4000_0000, 1, 32'h2000_0000);
        // shift by 0 -> unchanged
        check_result(ALU_SRA, 32'hDEAD_BEEF, 0, 32'hDEAD_BEEF);

        // --- ALU_OR ---
        // a | 0 = a
        check_result(ALU_OR, 32'hDEAD_BEEF, 0, 32'hDEAD_BEEF);
        // a | ~a = 0xFFFFFFFF
        check_result(ALU_OR, 32'hAAAA_AAAA, 32'h5555_5555, 32'hFFFF_FFFF);
        // a | all-ones = all-ones
        check_result(ALU_OR, 32'hDEAD_BEEF, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
        // a | a = a
        check_result(ALU_OR, 32'hDEAD_BEEF, 32'hDEAD_BEEF, 32'hDEAD_BEEF);

        // --- ALU_AND ---
        // a & 0 = 0
        check_result(ALU_AND, 32'hDEAD_BEEF, 0, 0);
        // a & ~a = 0
        check_result(ALU_AND, 32'hAAAA_AAAA, 32'h5555_5555, 0);
        // a & 0xFFFFFFFF = a
        check_result(ALU_AND, 32'hDEAD_BEEF, 32'hFFFF_FFFF, 32'hDEAD_BEEF);
        // a & a = a
        check_result(ALU_AND, 32'hDEAD_BEEF, 32'hDEAD_BEEF, 32'hDEAD_BEEF);

        // --- ALU_PASS_B (LUI passthrough) ---
        // result = src_b regardless of src_a
        check_result(ALU_PASS_B, 32'hDEAD_BEEF, 32'h1234_5000, 32'h1234_5000);
        check_result(ALU_PASS_B, 0,             32'hABCD_E000, 32'hABCD_E000);
        // src_b = 0 → result = 0
        check_result(ALU_PASS_B, 32'hDEAD_BEEF, 0, 0);

        // --- default / invalid op (alu_op 11–15, undefined) → result = 0 ---
        for (int op = 11; op <= 15; op++) begin
            alu_op = op[3:0]; src_a = 32'hDEAD_BEEF; src_b = 32'h1234_5678; #1;
            if (result === 32'h0) begin
                $display("PASS | OP=%0d (invalid) → result=0", op);
                pass_count++;
            end else begin
                $display("FAIL | OP=%0d (invalid) → got=%h, expected=0", op, result);
                fail_count++;
            end
        end

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("ALU TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
