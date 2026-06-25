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
// Module       : fu_tb
// Description  : Testbench for Forwarding Unit — verifies forward_a / forward_b
//                mux select encoding for all hazard scenarios:
//                  2'b00 = no forward (use register file)
//                  2'b01 = forward from WB stage
//                  2'b10 = forward from MEM stage (higher priority)
//                Covers: no hazard, MEM forward, WB forward, MEM-over-WB priority,
//                back-to-back same destination, x0 guard.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-02
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module fu_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic [4:0] ex_rs1,    ex_rs2;
    logic [4:0] mem_rd;    logic mem_reg_we;
    logic [4:0] wb_rd;     logic wb_reg_we;
    logic [1:0] forward_a, forward_b;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    fu dut (
        .ex_rs1     (ex_rs1),
        .ex_rs2     (ex_rs2),
        .mem_rd     (mem_rd),
        .mem_reg_we (mem_reg_we),
        .wb_rd      (wb_rd),
        .wb_reg_we  (wb_reg_we),
        .forward_a  (forward_a),
        .forward_b  (forward_b)
    );

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    task check_fwd;
        input logic [4:0] t_ex_rs1, t_ex_rs2;
        input logic [4:0] t_mem_rd; input logic t_mem_we;
        input logic [4:0] t_wb_rd;  input logic t_wb_we;
        input logic [1:0] exp_a, exp_b;
        input string      desc;

        begin
            ex_rs1    = t_ex_rs1;
            ex_rs2    = t_ex_rs2;
            mem_rd    = t_mem_rd;
            mem_reg_we = t_mem_we;
            wb_rd     = t_wb_rd;
            wb_reg_we = t_wb_we;
            #1;

            if (forward_a === exp_a && forward_b === exp_b) begin
                $display("PASS | %s  fwd_a=%0b fwd_b=%0b", desc, forward_a, forward_b);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (forward_a !== exp_a) $display("       forward_a: got=%0b exp=%0b", forward_a, exp_a);
                if (forward_b !== exp_b) $display("       forward_b: got=%0b exp=%0b", forward_b, exp_b);
                fail_count++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test vectors
    // check_fwd(ex_rs1, ex_rs2, mem_rd, mem_we, wb_rd, wb_we, exp_a, exp_b, desc)
    // -------------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        // --- No hazard: no register-write in flight ---
        check_fwd(5'd1, 5'd2, 5'd3, 1'b0, 5'd4, 1'b0,  2'b00, 2'b00, "no hazard, all writes disabled");
        check_fwd(5'd1, 5'd2, 5'd0, 1'b1, 5'd0, 1'b1,  2'b00, 2'b00, "x0 guard: mem_rd=0 wb_rd=0");

        // rs1/rs2 don't match anything in flight
        check_fwd(5'd5, 5'd6, 5'd7, 1'b1, 5'd8, 1'b1,  2'b00, 2'b00, "no match on any stage");

        // --- MEM forwarding (EX/MEM → EX): forward_x = 2'b10 ---
        // rs1 matches MEM, rs2 doesn't match anything
        check_fwd(5'd3, 5'd2, 5'd3, 1'b1, 5'd9, 1'b0,  2'b10, 2'b00, "MEM fwd rs1 only");

        // rs2 matches MEM, rs1 doesn't
        check_fwd(5'd1, 5'd3, 5'd3, 1'b1, 5'd9, 1'b0,  2'b00, 2'b10, "MEM fwd rs2 only");

        // both rs1 and rs2 match MEM (e.g. ADD x5, x3, x3 after SUB x3, ...)
        check_fwd(5'd3, 5'd3, 5'd3, 1'b1, 5'd9, 1'b0,  2'b10, 2'b10, "MEM fwd both rs1 and rs2");

        // MEM forward but mem_reg_we=0 → no forward
        check_fwd(5'd3, 5'd3, 5'd3, 1'b0, 5'd9, 1'b0,  2'b00, 2'b00, "MEM fwd blocked by reg_we=0");

        // MEM forward but rd=x0 → x0 guard blocks forward
        check_fwd(5'd0, 5'd0, 5'd0, 1'b1, 5'd9, 1'b0,  2'b00, 2'b00, "MEM fwd blocked by rd=x0");

        // --- WB forwarding (MEM/WB → EX): forward_x = 2'b01 ---
        // rs1 matches WB, no MEM hazard
        check_fwd(5'd5, 5'd2, 5'd9, 1'b0, 5'd5, 1'b1,  2'b01, 2'b00, "WB fwd rs1 only");

        // rs2 matches WB
        check_fwd(5'd1, 5'd5, 5'd9, 1'b0, 5'd5, 1'b1,  2'b00, 2'b01, "WB fwd rs2 only");

        // both match WB
        check_fwd(5'd5, 5'd5, 5'd9, 1'b0, 5'd5, 1'b1,  2'b01, 2'b01, "WB fwd both");

        // WB forward but wb_reg_we=0 → no forward
        check_fwd(5'd5, 5'd5, 5'd9, 1'b0, 5'd5, 1'b0,  2'b00, 2'b00, "WB fwd blocked by reg_we=0");

        // WB forward but rd=x0 → x0 guard
        check_fwd(5'd0, 5'd0, 5'd9, 1'b0, 5'd0, 1'b1,  2'b00, 2'b00, "WB fwd blocked by wb_rd=x0");

        // --- MEM takes priority over WB (back-to-back RAW) ---
        // rs1 matches both MEM and WB → MEM wins
        check_fwd(5'd4, 5'd2, 5'd4, 1'b1, 5'd4, 1'b1,  2'b10, 2'b00, "MEM priority over WB for rs1");

        // rs2 matches both → MEM wins
        check_fwd(5'd1, 5'd4, 5'd4, 1'b1, 5'd4, 1'b1,  2'b00, 2'b10, "MEM priority over WB for rs2");

        // rs1 → MEM, rs2 → WB (different destinations, no overlap)
        check_fwd(5'd4, 5'd7, 5'd4, 1'b1, 5'd7, 1'b1,  2'b10, 2'b01, "rs1→MEM rs2→WB independent");

        // rs1 → WB, rs2 → MEM
        check_fwd(5'd7, 5'd4, 5'd4, 1'b1, 5'd7, 1'b1,  2'b01, 2'b10, "rs1→WB rs2→MEM independent");

        // MEM disabled, WB enabled — rs1 matches MEM rd but reg_we=0 → falls to WB
        check_fwd(5'd4, 5'd2, 5'd4, 1'b0, 5'd4, 1'b1,  2'b01, 2'b00, "MEM disabled → falls through to WB");

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("FU TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
