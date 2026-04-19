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
// Module       : bru_tb
// Description  : Testbench for Branch Resolution Unit — verifies:
//                  branch_cond : all 6 RV32I branch conditions (BEQ/BNE/BLT/BGE/BLTU/BGEU)
//                  ex_actual_taken   : branch && cond || jump
//                  ex_actual_target  : JAL pc+imm / JALR (rs1+imm)&~1 / branch pc+imm
//                  ex_mispredict     : prediction mismatch (taken bit or target)
//                  ex_correct_pc     : actual_target or pc+4
//                  ex_update_en      : branch || jump
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-02
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module bru_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic        branch, jump, alu_src;
    logic [2:0]  funct3;
    logic [31:0] src_a, src_b, imm, pc;
    logic        pred_taken;
    logic [31:0] pred_target;

    logic        ex_update_en, ex_actual_taken;
    logic [31:0] ex_actual_target;
    logic        ex_mispredict;
    logic [31:0] ex_correct_pc;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    bru dut (
        .branch           (branch),
        .jump             (jump),
        .alu_src          (alu_src),
        .funct3           (funct3),
        .src_a            (src_a),
        .src_b            (src_b),
        .imm              (imm),
        .pc               (pc),
        .pred_taken       (pred_taken),
        .pred_target      (pred_target),
        .ex_update_en     (ex_update_en),
        .ex_actual_taken  (ex_actual_taken),
        .ex_actual_target (ex_actual_target),
        .ex_mispredict    (ex_mispredict),
        .ex_correct_pc    (ex_correct_pc)
    );

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    task check_bru;
        input logic        t_branch, t_jump, t_alu_src;
        input logic [2:0]  t_funct3;
        input logic [31:0] t_src_a, t_src_b, t_imm, t_pc;
        input logic        t_pred_taken;
        input logic [31:0] t_pred_target;
        // expected
        input logic        exp_update_en, exp_taken;
        input logic [31:0] exp_target;
        input logic        exp_mispredict;
        input logic [31:0] exp_correct_pc;
        input string       desc;

        begin
            branch      = t_branch;
            jump        = t_jump;
            alu_src     = t_alu_src;
            funct3      = t_funct3;
            src_a       = t_src_a;
            src_b       = t_src_b;
            imm         = t_imm;
            pc          = t_pc;
            pred_taken  = t_pred_taken;
            pred_target = t_pred_target;
            #1;

            if (ex_update_en     === exp_update_en  &&
                ex_actual_taken  === exp_taken       &&
                ex_actual_target === exp_target      &&
                ex_mispredict    === exp_mispredict  &&
                ex_correct_pc    === exp_correct_pc) begin
                $display("PASS | %s", desc);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (ex_update_en     !== exp_update_en)  $display("       update_en    : got=%0b exp=%0b", ex_update_en,     exp_update_en);
                if (ex_actual_taken  !== exp_taken)       $display("       actual_taken : got=%0b exp=%0b", ex_actual_taken,  exp_taken);
                if (ex_actual_target !== exp_target)      $display("       actual_target: got=%h exp=%h",   ex_actual_target, exp_target);
                if (ex_mispredict    !== exp_mispredict)  $display("       mispredict   : got=%0b exp=%0b", ex_mispredict,    exp_mispredict);
                if (ex_correct_pc    !== exp_correct_pc)  $display("       correct_pc   : got=%h exp=%h",   ex_correct_pc,    exp_correct_pc);
                fail_count++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test vectors
    // Shorthand — all check_bru calls:
    // (branch, jump, alu_src, funct3, src_a, src_b, imm, pc,
    //  pred_taken, pred_target,
    //  exp_update_en, exp_taken, exp_target, exp_mispredict, exp_correct_pc, desc)
    // -------------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        // =====================================================================
        // --- Branch conditions ---
        // =====================================================================

        // BEQ (funct3=000): taken when src_a == src_b
        // taken, predict not-taken → mispredict
        check_bru(1,0,0, 3'b000, 5, 5, 32'h10, 32'h100,  0, 32'h0,
                  1, 1, 32'h110, 1, 32'h110, "BEQ taken, pred NT → mispredict");
        // not-taken, predict not-taken → correct
        check_bru(1,0,0, 3'b000, 5, 6, 32'h10, 32'h100,  0, 32'h0,
                  1, 0, 32'h110, 0, 32'h104, "BEQ not-taken, pred NT → correct");
        // taken, predict taken with correct target → no mispredict
        check_bru(1,0,0, 3'b000, 7, 7, 32'h20, 32'h200,  1, 32'h220,
                  1, 1, 32'h220, 0, 32'h220, "BEQ taken, pred T correct target → no mispredict");
        // taken, predict taken but wrong target → mispredict
        check_bru(1,0,0, 3'b000, 7, 7, 32'h20, 32'h200,  1, 32'h300,
                  1, 1, 32'h220, 1, 32'h220, "BEQ taken, pred T wrong target → mispredict");

        // BNE (funct3=001): taken when src_a != src_b
        check_bru(1,0,0, 3'b001, 3, 5, 32'h8, 32'h80,  0, 32'h0,
                  1, 1, 32'h88, 1, 32'h88, "BNE taken (3!=5), pred NT");
        check_bru(1,0,0, 3'b001, 5, 5, 32'h8, 32'h80,  0, 32'h0,
                  1, 0, 32'h88, 0, 32'h84, "BNE not-taken (5==5), pred NT");

        // BLT (funct3=100): signed less-than
        // -1 < 1 → taken
        check_bru(1,0,0, 3'b100, 32'hFFFF_FFFF, 1, 32'hC, 32'h40,  0, 32'h0,
                  1, 1, 32'h4C, 1, 32'h4C, "BLT taken (-1 < 1), pred NT");
        // 1 < -1 → not-taken
        check_bru(1,0,0, 3'b100, 1, 32'hFFFF_FFFF, 32'hC, 32'h40,  0, 32'h0,
                  1, 0, 32'h4C, 0, 32'h44, "BLT not-taken (1 > -1 signed), pred NT");
        // equal → not-taken
        check_bru(1,0,0, 3'b100, 5, 5, 32'h4, 32'h10,  0, 32'h0,
                  1, 0, 32'h14, 0, 32'h14, "BLT not-taken (equal), pred NT");

        // BGE (funct3=101): signed greater-or-equal
        // 1 >= -1 → taken
        check_bru(1,0,0, 3'b101, 1, 32'hFFFF_FFFF, 32'h10, 32'h50,  0, 32'h0,
                  1, 1, 32'h60, 1, 32'h60, "BGE taken (1 >= -1), pred NT");
        // -1 >= 1 → not-taken
        check_bru(1,0,0, 3'b101, 32'hFFFF_FFFF, 1, 32'h10, 32'h50,  0, 32'h0,
                  1, 0, 32'h60, 0, 32'h54, "BGE not-taken (-1 < 1), pred NT");
        // equal → taken
        check_bru(1,0,0, 3'b101, 5, 5, 32'h4, 32'h10,  0, 32'h0,
                  1, 1, 32'h14, 1, 32'h14, "BGE taken (equal), pred NT");

        // BLTU (funct3=110): unsigned less-than
        // 1 < 0xFFFFFFFF unsigned → taken
        check_bru(1,0,0, 3'b110, 1, 32'hFFFF_FFFF, 32'h8, 32'h20,  0, 32'h0,
                  1, 1, 32'h28, 1, 32'h28, "BLTU taken (1 < 0xFFFFFFFF unsigned), pred NT");
        // 0xFFFFFFFF < 1 unsigned → not-taken
        check_bru(1,0,0, 3'b110, 32'hFFFF_FFFF, 1, 32'h8, 32'h20,  0, 32'h0,
                  1, 0, 32'h28, 0, 32'h24, "BLTU not-taken (0xFFFFFFFF > 1 unsigned), pred NT");

        // BGEU (funct3=111): unsigned greater-or-equal
        // 0xFFFFFFFF >= 1 → taken
        check_bru(1,0,0, 3'b111, 32'hFFFF_FFFF, 1, 32'h8, 32'h20,  0, 32'h0,
                  1, 1, 32'h28, 1, 32'h28, "BGEU taken (0xFFFFFFFF >= 1), pred NT");
        // 1 >= 0xFFFFFFFF → not-taken
        check_bru(1,0,0, 3'b111, 1, 32'hFFFF_FFFF, 32'h8, 32'h20,  0, 32'h0,
                  1, 0, 32'h28, 0, 32'h24, "BGEU not-taken (1 < 0xFFFFFFFF), pred NT");

        // =====================================================================
        // --- JAL (jump=1, alu_src=0): target = pc + imm, always taken ---
        // =====================================================================
        // predict not-taken → mispredict
        check_bru(0,1,0, 3'b000, 32'h0, 32'h0, 32'hC, 32'h100,  0, 32'h0,
                  1, 1, 32'h10C, 1, 32'h10C, "JAL pred NT → mispredict");
        // predict taken with correct target → no mispredict
        check_bru(0,1,0, 3'b000, 32'h0, 32'h0, 32'hC, 32'h100,  1, 32'h10C,
                  1, 1, 32'h10C, 0, 32'h10C, "JAL pred T correct → no mispredict");
        // predict taken but wrong target → mispredict
        check_bru(0,1,0, 3'b000, 32'h0, 32'h0, 32'hC, 32'h100,  1, 32'h200,
                  1, 1, 32'h10C, 1, 32'h10C, "JAL pred T wrong target → mispredict");
        // large negative offset (JAL backwards)
        check_bru(0,1,0, 3'b000, 32'h0, 32'h0, 32'hFFFF_FFF0, 32'h200,  0, 32'h0,
                  1, 1, 32'h1F0, 1, 32'h1F0, "JAL backward offset");

        // =====================================================================
        // --- JALR (jump=1, alu_src=1): target = (rs1+imm)&~1, always taken ---
        // =====================================================================
        // basic: rs1=0x100, imm=0x10 → target=0x110
        check_bru(0,1,1, 3'b000, 32'h100, 32'h0, 32'h10, 32'h50,  0, 32'h0,
                  1, 1, 32'h110, 1, 32'h110, "JALR basic target");
        // LSB clear: rs1=0x101 (odd), imm=0 → target=(0x101)&~1=0x100
        check_bru(0,1,1, 3'b000, 32'h101, 32'h0, 32'h0, 32'h50,  0, 32'h0,
                  1, 1, 32'h100, 1, 32'h100, "JALR clears LSB");
        // LSB comes from sum: rs1=0x100, imm=0x3 → sum=0x103 → target=0x102
        check_bru(0,1,1, 3'b000, 32'h100, 32'h0, 32'h3, 32'h50,  0, 32'h0,
                  1, 1, 32'h102, 1, 32'h102, "JALR LSB cleared from sum");
        // predict correct
        check_bru(0,1,1, 3'b000, 32'h100, 32'h0, 32'h10, 32'h50,  1, 32'h110,
                  1, 1, 32'h110, 0, 32'h110, "JALR pred T correct → no mispredict");

        // =====================================================================
        // --- Non-branch/jump (branch=0, jump=0): no update, no redirect ---
        // =====================================================================
        check_bru(0,0,0, 3'b000, 32'h5, 32'h5, 32'h10, 32'h100,  0, 32'h0,
                  0, 0, 32'h110, 0, 32'h104, "R/I-type: no update, no mispredict");

        // =====================================================================
        // --- Misprediction edge cases ---
        // =====================================================================
        // not-taken branch but predictor said taken → mispredict
        check_bru(1,0,0, 3'b000, 1, 2, 32'h10, 32'h80,  1, 32'h90,
                  1, 0, 32'h90, 1, 32'h84, "BEQ not-taken, pred T → mispredict, correct_pc=pc+4");
        // not-taken, predict not-taken → no mispredict, correct_pc = pc+4
        check_bru(1,0,0, 3'b001, 5, 5, 32'h10, 32'h80,  0, 32'h90,
                  1, 0, 32'h90, 0, 32'h84, "BNE not-taken (5==5), pred NT → no mispredict");

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("BRU TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
