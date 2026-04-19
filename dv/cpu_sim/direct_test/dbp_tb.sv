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
// Module       : dbp_tb
// Description  : Testbench for Dynamic Branch Predictor — verifies:
//                  cold miss     : no BTB entry → pred_taken=0
//                  BHT training  : 2-bit saturating counter (STRONGLY_NT→...→STRONGLY_T)
//                  prediction threshold: bht >= 2 → pred_taken=1 (BTB hit required)
//                  BTB write-on-taken: not-taken update does NOT write BTB
//                  BHT saturation: clamps at STRONGLY_NT (0) and STRONGLY_T (3)
//                  tag match/miss: same index, different tag → BTB miss → no predict
//                  update_en guard: ex_update_en=0 → no change
//
// PC field decomposition (BP_ENTRIES=1024, BP_IDX_BITS=10, BTB_TAG_BITS=20):
//   PC[1:0]   ignored (word-aligned)
//   PC[11:2]  index (10 bits)
//   PC[31:12] tag   (20 bits)
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-02
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module dbp_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                  clk, rst_n;
    logic [ADDR_WIDTH-1:0] if_pc;
    logic                  pred_taken;
    logic [ADDR_WIDTH-1:0] pred_target;
    logic                  ex_update_en;
    logic [ADDR_WIDTH-1:0] ex_pc;
    logic                  ex_actual_taken;
    logic [ADDR_WIDTH-1:0] ex_actual_target;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    dbp dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .if_pc            (if_pc),
        .pred_taken       (pred_taken),
        .pred_target      (pred_target),
        .ex_update_en     (ex_update_en),
        .ex_pc            (ex_pc),
        .ex_actual_taken  (ex_actual_taken),
        .ex_actual_target (ex_actual_target)
    );

    // -------------------------------------------------------------------------
    // Clock: 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Test PCs
    //   PC_A: idx=0x040, tag=0x00000 → used for main BHT/BTB training tests
    //   PC_B: idx=0x080, tag=0x00000 → independent entry, BHT saturation tests
    //   PC_C: idx=0x040, tag=0x00001 → same index as PC_A but different tag
    // -------------------------------------------------------------------------
    localparam logic [31:0] PC_A      = 32'h0000_0100;  // idx=0x40 tag=0x00000
    localparam logic [31:0] PC_B      = 32'h0000_0200;  // idx=0x80 tag=0x00000
    localparam logic [31:0] PC_C      = 32'h0001_0100;  // idx=0x40 tag=0x00001
    localparam logic [31:0] TGT_A     = 32'h0000_0300;
    localparam logic [31:0] TGT_B     = 32'h0000_0400;

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    // Issue one update on the next posedge
    task do_update;
        input logic [ADDR_WIDTH-1:0] t_ex_pc;
        input logic                  t_taken;
        input logic [ADDR_WIDTH-1:0] t_target;
        begin
            @(negedge clk);
            ex_update_en     = 1'b1;
            ex_pc            = t_ex_pc;
            ex_actual_taken  = t_taken;
            ex_actual_target = t_target;
            @(posedge clk); #1;
            ex_update_en = 1'b0;
        end
    endtask

    // Read prediction for given PC (combinational)
    task check_pred;
        input logic [ADDR_WIDTH-1:0] t_if_pc;
        input logic                  exp_taken;
        input logic [ADDR_WIDTH-1:0] exp_target;
        input string                 desc;
        begin
            if_pc = t_if_pc;
            #1;
            if (pred_taken === exp_taken && pred_target === exp_target) begin
                $display("PASS | %s  pred_taken=%0b pred_target=%h", desc, pred_taken, pred_target);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (pred_taken  !== exp_taken)   $display("       pred_taken  : got=%0b exp=%0b", pred_taken,  exp_taken);
                if (pred_target !== exp_target)  $display("       pred_target : got=%h exp=%h",   pred_target, exp_target);
                fail_count++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------
    initial begin
        pass_count    = 0;
        fail_count    = 0;
        if_pc         = 32'h0;
        ex_update_en  = 1'b0;
        ex_pc         = 32'h0;
        ex_actual_taken  = 1'b0;
        ex_actual_target = 32'h0;

        // =====================================================================
        // --- Reset: btb_valid = 0 → cold miss on every PC ---
        // =====================================================================
        rst_n = 1'b0;
        @(posedge clk); #1;
        rst_n = 1'b1;

        // Initialize BHT entries to STRONGLY_NT so the test starts from a
        // known state — BHT has no async reset, so simulation starts with X.
        force dut.bht[PC_A[11:2]] = STRONGLY_NT;
        force dut.bht[PC_B[11:2]] = STRONGLY_NT;
        #1;
        release dut.bht[PC_A[11:2]];
        release dut.bht[PC_B[11:2]];

        // =====================================================================
        // --- Cold BTB miss: btb_valid=0 → pred_taken=0 ---
        // =====================================================================
        check_pred(PC_A, 0, 32'h0, "cold miss PC_A: no BTB entry");
        check_pred(PC_B, 0, 32'h0, "cold miss PC_B: no BTB entry");

        // =====================================================================
        // --- BHT training + BTB write (PC_A) ---
        // State: bht=0 (STRONGLY_NT), BTB invalid
        //
        // Update sequence:
        //   taken#1 → bht=1 (WEAKLY_NT)  BTB written → pred_taken=0 (bht<2)
        //   taken#2 → bht=2 (WEAKLY_T)               → pred_taken=1 ✓
        //   taken#3 → bht=3 (STRONGLY_T)              → pred_taken=1
        //   taken#4 → bht=3 (saturate)                → pred_taken=1
        // =====================================================================

        // taken#1: bht: 0→1, BTB written
        do_update(PC_A, 1, TGT_A);
        check_pred(PC_A, 0, TGT_A, "after 1 taken (bht=1=WEAKLY_NT): pred_taken=0");

        // taken#2: bht: 1→2 (WEAKLY_T) → threshold crossed
        do_update(PC_A, 1, TGT_A);
        check_pred(PC_A, 1, TGT_A, "after 2 taken (bht=2=WEAKLY_T): pred_taken=1");

        // taken#3: bht: 2→3 (STRONGLY_T)
        do_update(PC_A, 1, TGT_A);
        check_pred(PC_A, 1, TGT_A, "after 3 taken (bht=3=STRONGLY_T): pred_taken=1");

        // taken#4: bht saturates at 3
        do_update(PC_A, 1, TGT_A);
        check_pred(PC_A, 1, TGT_A, "saturation at STRONGLY_T: still pred_taken=1");

        // =====================================================================
        // --- BHT decrement (PC_A): from STRONGLY_T down ---
        //   not-taken#1 → bht=2 (WEAKLY_T)   → pred_taken=1
        //   not-taken#2 → bht=1 (WEAKLY_NT)  → pred_taken=0
        //   not-taken#3 → bht=0 (STRONGLY_NT)→ pred_taken=0
        //   not-taken#4 → bht=0 (saturate)   → pred_taken=0
        // =====================================================================

        // not-taken#1: bht: 3→2
        do_update(PC_A, 0, TGT_A);
        check_pred(PC_A, 1, TGT_A, "not-taken#1 (bht=2=WEAKLY_T): still pred_taken=1");

        // not-taken#2: bht: 2→1
        do_update(PC_A, 0, TGT_A);
        check_pred(PC_A, 0, TGT_A, "not-taken#2 (bht=1=WEAKLY_NT): pred_taken=0");

        // not-taken#3: bht: 1→0
        do_update(PC_A, 0, TGT_A);
        check_pred(PC_A, 0, TGT_A, "not-taken#3 (bht=0=STRONGLY_NT): pred_taken=0");

        // not-taken#4: saturates at 0
        do_update(PC_A, 0, TGT_A);
        check_pred(PC_A, 0, TGT_A, "saturation at STRONGLY_NT: pred_taken=0");

        // =====================================================================
        // --- BTB write-on-taken only: not-taken does NOT update BTB target ---
        // Train a fresh entry (PC_B), first taken to record TGT_B,
        // then verify target unchanged after not-taken updates
        // =====================================================================

        // PC_B: taken → BTB written with TGT_B, bht=1
        do_update(PC_B, 1, TGT_B);
        check_pred(PC_B, 0, TGT_B, "PC_B after taken: BTB target=TGT_B, bht=1 → pred_taken=0");

        // PC_B: second taken → bht=2 → pred_taken=1, target still TGT_B
        do_update(PC_B, 1, TGT_B);
        check_pred(PC_B, 1, TGT_B, "PC_B bht=2: pred_taken=1 target=TGT_B");

        // PC_B: not-taken — BHT decrements 2→1, BTB target must NOT change
        // pred_taken=0 (bht=1 < threshold), pred_target=TGT_B (BTB target not overwritten)
        do_update(PC_B, 0, 32'hDEAD_BEEF);  // pass bogus target — should be ignored
        check_pred(PC_B, 0, TGT_B, "PC_B not-taken: BHT=1 pred_taken=0, BTB target unchanged (still TGT_B)");

        // =====================================================================
        // --- Tag mismatch: PC_C has same index as PC_A but different tag ---
        // PC_A trained BTB at idx=0x40 with tag for PC_A.
        // Reading PC_C (same idx, different tag) → BTB tag mismatch → pred_taken=0
        // =====================================================================

        // First retrain PC_A back to taken so BTB at idx=0x40 is valid for PC_A tag
        do_update(PC_A, 1, TGT_A);
        do_update(PC_A, 1, TGT_A);  // bht=2 for PC_A

        check_pred(PC_A, 1, TGT_A, "PC_A: pred_taken=1 (confirms BTB entry for tag check)");
        // PC_C shares idx but has tag=0x00001; BTB stores tag for PC_A → miss
        check_pred(PC_C, 0, 32'h0, "PC_C tag mismatch: BTB miss → pred_taken=0");

        // =====================================================================
        // --- ex_update_en=0: no state change ---
        // =====================================================================
        // PC_A currently predicted taken. Apply update with en=0 → no change.
        @(negedge clk);
        ex_update_en     = 1'b0;
        ex_pc            = PC_A;
        ex_actual_taken  = 1'b0;   // would decrement bht if en=1
        ex_actual_target = 32'hDEAD_BEEF;
        @(posedge clk); #1;

        check_pred(PC_A, 1, TGT_A, "update_en=0: PC_A pred unchanged (no write)");

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("DBP TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
