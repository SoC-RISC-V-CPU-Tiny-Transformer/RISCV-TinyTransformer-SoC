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
// Module       : fcu_tb
// Description  : Testbench for Fetch Control Unit.
//
//                PC update rule (from fcu.sv):
//                  priority 1 : ex_mispredict  → pc_reg <= ex_correct_pc
//                  priority 2 : !stall && cache_valid && cache_ready
//                                              → pc_reg <= next_pc
//                  next_pc    : pred_taken ? pred_target : pc_reg + 4
//
//                All check_pc calls happen AFTER @(posedge clk) #1, so they
//                see the pc_reg value that was latched on that edge.
//
//                PC trace (manual):
//                  reset    : 0x00
//                  advance×4: 0x04 0x08 0x0C 0x10
//                  miss×2   : 0x10 0x10   (frozen, never reaches 0x14)
//                  miss ends: 0x14
//                  CWF×2    : 0x14 0x14
//                  CWF ends : 0x18
//                  stall×2  : 0x18 0x18
//                  stall end: 0x1C
//                  pred×3   : 0x200 0x200 0x200  (pred_target, stays while pred_taken=1)
//                  pred off : 0x204
//                  advance  : 0x208
//                  mispredict: 0x500  (checked on mispredict posedge itself)
//                  resume   : 0x504
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-03
// Version      : 1.1
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module fcu_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                     clk, rst_n;
    logic [DATA_WIDTH-1:0]    instr_i;
    logic                     cache_valid, cache_ready;
    logic                     pred_taken;
    logic [ADDR_WIDTH-1:0]    pred_target;
    logic                     ex_mispredict;
    logic [ADDR_WIDTH-1:0]    ex_correct_pc;
    logic                     stall;

    logic                     if_req;
    logic [ADDR_WIDTH-1:0]    if_pc;
    logic [DATA_WIDTH-1:0]    instr_o;
    logic [ADDR_WIDTH-1:0]    if_id_pc;
    logic                     if_id_pred_taken;
    logic [ADDR_WIDTH-1:0]    if_id_pred_target;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    fcu dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .instr_i          (instr_i),
        .cache_valid      (cache_valid),
        .cache_ready      (cache_ready),
        .pred_taken       (pred_taken),
        .pred_target      (pred_target),
        .ex_mispredict    (ex_mispredict),
        .ex_correct_pc    (ex_correct_pc),
        .stall            (stall),
        .if_req           (if_req),
        .if_pc            (if_pc),
        .instr_o          (instr_o),
        .if_id_pc         (if_id_pc),
        .if_id_pred_taken  (if_id_pred_taken),
        .if_id_pred_target (if_id_pred_target)
    );

    // -------------------------------------------------------------------------
    // Clock: 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    task set_idle;
        begin
            cache_valid   = 1'b1;
            cache_ready   = 1'b1;
            pred_taken    = 1'b0;
            pred_target   = '0;
            ex_mispredict = 1'b0;
            ex_correct_pc = '0;
            stall         = 1'b0;
            instr_i       = 32'h0000_0013;  // NOP
        end
    endtask

    // Check PC and if_req #1 after a posedge that has already occurred
    task check_pc;
        input logic [ADDR_WIDTH-1:0] exp_pc;
        input logic                  exp_req;
        input string                 desc;
        begin
            // #1 already consumed by caller before this task is invoked
            if (if_pc === exp_pc && if_req === exp_req) begin
                $display("PASS | %-45s  pc=%h if_req=%0b", desc, if_pc, if_req);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (if_pc  !== exp_pc)  $display("       if_pc  : got=%h exp=%h", if_pc,  exp_pc);
                if (if_req !== exp_req) $display("       if_req : got=%0b exp=%0b", if_req, exp_req);
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
        set_idle();

        // =====================================================================
        // --- Reset ---
        // =====================================================================
        rst_n = 1'b0;
        @(posedge clk); #1;
        if (if_pc === PC_RESET_VEC) begin
            $display("PASS | reset: PC=%h", if_pc);
            pass_count++;
        end else begin
            $display("FAIL | reset: got=%h exp=%h", if_pc, PC_RESET_VEC);
            fail_count++;
        end
        rst_n = 1'b1;

        // =====================================================================
        // --- Normal advance: PC += 4 each cycle ---
        // PC trace: 0 → 4 → 8 → C → 10
        // =====================================================================
        @(posedge clk); #1; check_pc(32'h04, 1'b1, "advance 0x00 → 0x04");
        @(posedge clk); #1; check_pc(32'h08, 1'b1, "advance 0x04 → 0x08");
        @(posedge clk); #1; check_pc(32'h0C, 1'b1, "advance 0x08 → 0x0C");
        @(posedge clk); #1; check_pc(32'h10, 1'b1, "advance 0x0C → 0x10");
        // PC is now 0x10

        // =====================================================================
        // --- Cache miss: cache_valid=0 → PC frozen ---
        // PC stays at 0x10 (never reaches 0x14 while miss is active)
        // =====================================================================
        @(negedge clk); cache_valid = 1'b0;
        @(posedge clk); #1; check_pc(32'h10, 1'b1, "cache miss: PC frozen at 0x10");
        @(posedge clk); #1; check_pc(32'h10, 1'b1, "cache miss: PC still 0x10");

        @(negedge clk); cache_valid = 1'b1;
        @(posedge clk); #1; check_pc(32'h14, 1'b1, "cache back: advance 0x10 → 0x14");
        // PC is now 0x14

        // =====================================================================
        // --- CWF: cache_valid=1 but cache_ready=0 → PC frozen ---
        // =====================================================================
        @(negedge clk); cache_ready = 1'b0;
        @(posedge clk); #1; check_pc(32'h14, 1'b1, "CWF: valid=1 ready=0, frozen at 0x14");
        @(posedge clk); #1; check_pc(32'h14, 1'b1, "CWF: still frozen at 0x14");

        @(negedge clk); cache_ready = 1'b1;
        @(posedge clk); #1; check_pc(32'h18, 1'b1, "CWF done: advance 0x14 → 0x18");
        // PC is now 0x18

        // =====================================================================
        // --- Stall: PC frozen, if_req deasserted ---
        // =====================================================================
        @(negedge clk); stall = 1'b1;
        @(posedge clk); #1; check_pc(32'h18, 1'b0, "stall: frozen at 0x18, if_req=0");
        @(posedge clk); #1; check_pc(32'h18, 1'b0, "stall: still frozen 0x18");

        @(negedge clk); stall = 1'b0;
        @(posedge clk); #1; check_pc(32'h1C, 1'b1, "stall released: advance 0x18 → 0x1C");
        // PC is now 0x1C

        // =====================================================================
        // --- Branch prediction taken: PC → pred_target immediately ---
        // When pred_taken=1: next_pc = pred_target (not pc_reg+4).
        // The jump happens ON THE FIRST posedge after pred_taken goes high.
        // While pred_taken stays 1 and pred_target=0x200, PC stays at 0x200
        // (next_pc = pred_target = 0x200 every cycle).
        // =====================================================================
        @(negedge clk); pred_taken = 1'b1; pred_target = 32'h200;
        @(posedge clk); #1; check_pc(32'h200, 1'b1, "pred taken: PC jumps to 0x200 immediately");
        @(posedge clk); #1; check_pc(32'h200, 1'b1, "pred taken: PC stays at 0x200 (pred still=1)");

        // Drop pred_taken → sequential from 0x200
        @(negedge clk); pred_taken = 1'b0; pred_target = '0;
        @(posedge clk); #1; check_pc(32'h204, 1'b1, "pred off: advance 0x200 → 0x204");
        @(posedge clk); #1; check_pc(32'h208, 1'b1, "advance 0x204 → 0x208");
        // PC is now 0x208

        // =====================================================================
        // --- Mispredict redirect: priority 1, if_req deasserted ---
        // PC jumps to ex_correct_pc ON THE mispredict posedge itself.
        // =====================================================================
        @(negedge clk); ex_mispredict = 1'b1; ex_correct_pc = 32'h500;
        @(posedge clk); #1;
        // On this posedge: pc_reg <= ex_correct_pc = 0x500, if_req = 0
        if (if_req === 1'b0 && if_pc === 32'h500) begin
            $display("PASS | %-45s  pc=%h if_req=%0b", "mispredict: PC=0x500 if_req=0", if_pc, if_req);
            pass_count++;
        end else begin
            $display("FAIL | mispredict: PC=0x500 if_req=0");
            if (if_req !== 1'b0)       $display("       if_req: got=%0b exp=0", if_req);
            if (if_pc  !== 32'h500)    $display("       if_pc : got=%h exp=0x500", if_pc);
            fail_count++;
        end

        // Deassert mispredict → PC resumes as pc_reg+4 = 0x504
        @(negedge clk); ex_mispredict = 1'b0; ex_correct_pc = '0;
        @(posedge clk); #1; check_pc(32'h504, 1'b1, "mispredict off: resume 0x500 → 0x504");

        // =====================================================================
        // --- Mispredict clears if_id_pred_taken/target combinatorially ---
        // =====================================================================
        @(negedge clk);
        pred_taken    = 1'b1;
        pred_target   = 32'hABC;
        ex_mispredict = 1'b1;
        ex_correct_pc = 32'h600;
        #1; // combinational settle
        if (if_id_pred_taken === 1'b0 && if_id_pred_target === 32'h0) begin
            $display("PASS | mispredict clears if_id_pred_taken/target");
            pass_count++;
        end else begin
            $display("FAIL | mispredict should clear pred outputs");
            if (if_id_pred_taken  !== 1'b0)  $display("       if_id_pred_taken : got=%0b exp=0", if_id_pred_taken);
            if (if_id_pred_target !== 32'h0) $display("       if_id_pred_target: got=%h exp=0", if_id_pred_target);
            fail_count++;
        end

        // No mispredict → pred_taken/target pass through
        ex_mispredict = 1'b0;
        #1;
        if (if_id_pred_taken === 1'b1 && if_id_pred_target === 32'hABC) begin
            $display("PASS | no mispredict: pred_taken/target pass through");
            pass_count++;
        end else begin
            $display("FAIL | pred pass-through failed");
            if (if_id_pred_taken  !== 1'b1)    $display("       if_id_pred_taken : got=%0b exp=1", if_id_pred_taken);
            if (if_id_pred_target !== 32'hABC) $display("       if_id_pred_target: got=%h exp=%h", if_id_pred_target, 32'hABC);
            fail_count++;
        end

        // Clean up pred signals
        pred_taken = 1'b0; pred_target = '0;

        // =====================================================================
        // --- Mispredict overrides stall (priority 1) ---
        // Even with stall=1, ex_mispredict redirects PC.
        // =====================================================================
        @(negedge clk);
        stall         = 1'b1;
        ex_mispredict = 1'b1;
        ex_correct_pc = 32'h700;
        @(posedge clk); #1;
        // pc_reg = 0x700 (mispredict wins), if_req = 0 (stall OR mispredict)
        if (if_req === 1'b0 && if_pc === 32'h700) begin
            $display("PASS | %-45s  pc=%h if_req=%0b", "mispredict overrides stall: PC=0x700", if_pc, if_req);
            pass_count++;
        end else begin
            $display("FAIL | mispredict overrides stall");
            if (if_req !== 1'b0)    $display("       if_req: got=%0b exp=0", if_req);
            if (if_pc  !== 32'h700) $display("       if_pc : got=%h exp=0x700", if_pc);
            fail_count++;
        end

        @(negedge clk); stall = 1'b0; ex_mispredict = 1'b0; ex_correct_pc = '0;
        @(posedge clk); #1; check_pc(32'h704, 1'b1, "after override: resume 0x700 → 0x704");

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("FCU TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
