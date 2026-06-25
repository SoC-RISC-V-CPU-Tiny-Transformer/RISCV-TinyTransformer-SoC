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
// Module       : hdu_tb
// Description  : Testbench for Hazard Detection Unit — verifies:
//                  load_use_stall / ex_flush : load-use RAW hazard detection
//                  dcache_stall              : D-cache miss stall
//                Covers: normal load-use, store-use (not a hazard), x0 guard,
//                        dcache miss, dcache hit, and combined scenarios.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-02
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module hdu_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic       ex_mem_req, ex_mem_we;
    logic [4:0] ex_rd;
    logic [4:0] id_rs1, id_rs2;
    logic       mem_req, mem_valid;

    logic       load_use_stall, ex_flush, dcache_stall;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    hdu dut (
        .ex_mem_req     (ex_mem_req),
        .ex_mem_we      (ex_mem_we),
        .ex_rd          (ex_rd),
        .id_rs1         (id_rs1),
        .id_rs2         (id_rs2),
        .mem_req        (mem_req),
        .mem_valid      (mem_valid),
        .load_use_stall (load_use_stall),
        .ex_flush       (ex_flush),
        .dcache_stall   (dcache_stall)
    );

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    task check_hdu;
        input logic       t_ex_mem_req, t_ex_mem_we;
        input logic [4:0] t_ex_rd;
        input logic [4:0] t_id_rs1, t_id_rs2;
        input logic       t_mem_req, t_mem_valid;
        // expected outputs
        input logic       exp_lu_stall, exp_ex_flush, exp_dc_stall;
        input string      desc;

        begin
            ex_mem_req = t_ex_mem_req;
            ex_mem_we  = t_ex_mem_we;
            ex_rd      = t_ex_rd;
            id_rs1     = t_id_rs1;
            id_rs2     = t_id_rs2;
            mem_req    = t_mem_req;
            mem_valid  = t_mem_valid;
            #1;

            if (load_use_stall === exp_lu_stall &&
                ex_flush       === exp_ex_flush  &&
                dcache_stall   === exp_dc_stall) begin
                $display("PASS | %s", desc);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (load_use_stall !== exp_lu_stall) $display("       load_use_stall: got=%0b exp=%0b", load_use_stall, exp_lu_stall);
                if (ex_flush       !== exp_ex_flush)  $display("       ex_flush      : got=%0b exp=%0b", ex_flush,       exp_ex_flush);
                if (dcache_stall   !== exp_dc_stall)  $display("       dcache_stall  : got=%0b exp=%0b", dcache_stall,   exp_dc_stall);
                fail_count++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test vectors
    // check_hdu(ex_mem_req, ex_mem_we, ex_rd, id_rs1, id_rs2,
    //           mem_req, mem_valid,
    //           exp_lu_stall, exp_ex_flush, exp_dc_stall, desc)
    // -------------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        // --- No hazard: no memory operation in EX, dcache hit ---
        check_hdu(1'b0, 1'b0, 5'd3, 5'd3, 5'd4, 1'b0, 1'b1,  0, 0, 0, "no hazard: EX not mem, no dcache req");
        check_hdu(1'b0, 1'b0, 5'd3, 5'd3, 5'd3, 1'b1, 1'b1,  0, 0, 0, "no hazard: EX not mem, dcache hit");

        // --- Load-use hazard: EX is a load (mem_req=1, mem_we=0) ---
        // ex_rd matches id_rs1
        check_hdu(1'b1, 1'b0, 5'd3, 5'd3, 5'd5, 1'b0, 1'b1,  1, 1, 0, "load-use: ex_rd matches id_rs1");

        // ex_rd matches id_rs2
        check_hdu(1'b1, 1'b0, 5'd3, 5'd5, 5'd3, 1'b0, 1'b1,  1, 1, 0, "load-use: ex_rd matches id_rs2");

        // ex_rd matches both id_rs1 and id_rs2
        check_hdu(1'b1, 1'b0, 5'd3, 5'd3, 5'd3, 1'b0, 1'b1,  1, 1, 0, "load-use: ex_rd matches both");

        // --- Store-use: EX is a store (mem_we=1) → NOT a hazard ---
        check_hdu(1'b1, 1'b1, 5'd3, 5'd3, 5'd5, 1'b0, 1'b1,  0, 0, 0, "store-use rs1: no hazard (store)");
        check_hdu(1'b1, 1'b1, 5'd3, 5'd5, 5'd3, 1'b0, 1'b1,  0, 0, 0, "store-use rs2: no hazard (store)");

        // --- x0 guard: load to x0 never causes stall ---
        check_hdu(1'b1, 1'b0, 5'd0, 5'd0, 5'd0, 1'b0, 1'b1,  0, 0, 0, "x0 guard: load to x0");
        check_hdu(1'b1, 1'b0, 5'd0, 5'd1, 5'd2, 1'b0, 1'b1,  0, 0, 0, "x0 guard: load rd=x0 any rs");

        // --- No match: ex_rd doesn't match id_rs1 or id_rs2 ---
        check_hdu(1'b1, 1'b0, 5'd7, 5'd3, 5'd5, 1'b0, 1'b1,  0, 0, 0, "load no match: ex_rd differs");

        // --- ex_flush mirrors load_use_stall ---
        // (already covered above; verify explicitly that ex_flush=load_use_stall always)
        check_hdu(1'b1, 1'b0, 5'd4, 5'd4, 5'd9, 1'b0, 1'b1,  1, 1, 0, "ex_flush == load_use_stall when hazard");
        check_hdu(1'b0, 1'b0, 5'd4, 5'd4, 5'd9, 1'b0, 1'b1,  0, 0, 0, "ex_flush == load_use_stall when no hazard");

        // --- D-cache miss stall: mem_req=1, mem_valid=0 ---
        check_hdu(1'b0, 1'b0, 5'd9, 5'd1, 5'd2, 1'b1, 1'b0,  0, 0, 1, "dcache miss: mem_req=1 valid=0");

        // dcache hit: mem_req=1, mem_valid=1 → no stall
        check_hdu(1'b0, 1'b0, 5'd9, 5'd1, 5'd2, 1'b1, 1'b1,  0, 0, 0, "dcache hit:  mem_req=1 valid=1");

        // no dcache request at all
        check_hdu(1'b0, 1'b0, 5'd9, 5'd1, 5'd2, 1'b0, 1'b0,  0, 0, 0, "dcache idle: mem_req=0");

        // --- Combined: load-use hazard AND dcache miss simultaneously ---
        check_hdu(1'b1, 1'b0, 5'd3, 5'd3, 5'd5, 1'b1, 1'b0,  1, 1, 1, "load-use + dcache miss together");

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("HDU TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
