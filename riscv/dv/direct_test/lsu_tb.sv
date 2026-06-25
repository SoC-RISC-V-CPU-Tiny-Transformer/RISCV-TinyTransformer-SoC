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
// Module       : lsu_tb
// Description  : Testbench for Load/Store Unit — verifies:
//
//                STORE PATH (mem_we=1):
//                  dc_wstrb : byte×4 positions, half×2 positions, word×1
//                  dc_wdata : byte replicate, half replicate, word passthrough
//
//                LOAD PATH (mem_we=0):
//                  byte extraction  : addr[1:0] selects correct byte lane
//                  half extraction  : addr[1] selects correct 16-bit lane
//                  LB  (3'b000)     : sign-extend byte
//                  LH  (3'b001)     : sign-extend halfword
//                  LW  (3'b010)     : word passthrough
//                  LBU (3'b100)     : zero-extend byte
//                  LHU (3'b101)     : zero-extend halfword
//
//                PASSTHROUGH:
//                  dc_addr = addr, dc_req = mem_req, dc_we = mem_we
//                  mem_valid = dc_valid, mem_ready = dc_ready
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-04
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module lsu_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                   mem_req, mem_we;
    logic [2:0]             mem_size;
    logic [ADDR_WIDTH-1:0]  addr;
    logic [DATA_WIDTH-1:0]  wdata;

    logic [DATA_WIDTH-1:0]  mem_rdata;
    logic                   mem_valid, mem_ready;

    logic [ADDR_WIDTH-1:0]  dc_addr;
    logic                   dc_req, dc_we;
    logic [DATA_WIDTH-1:0]  dc_wdata;
    logic [3:0]             dc_wstrb;

    logic [DATA_WIDTH-1:0]  dc_rdata;
    logic                   dc_valid, dc_ready;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    lsu dut (
        .mem_req    (mem_req),
        .mem_we     (mem_we),
        .mem_size   (mem_size),
        .addr       (addr),
        .wdata      (wdata),
        .mem_rdata  (mem_rdata),
        .mem_valid  (mem_valid),
        .mem_ready  (mem_ready),
        .dc_addr    (dc_addr),
        .dc_req     (dc_req),
        .dc_we      (dc_we),
        .dc_wdata   (dc_wdata),
        .dc_wstrb   (dc_wstrb),
        .dc_rdata   (dc_rdata),
        .dc_valid   (dc_valid),
        .dc_ready   (dc_ready)
    );

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    // --- Store checker: verifies wstrb + wdata simultaneously ---
    task check_store;
        input logic [2:0]             t_mem_size;
        input logic [ADDR_WIDTH-1:0]  t_addr;
        input logic [DATA_WIDTH-1:0]  t_wdata;
        input logic [3:0]             exp_wstrb;
        input logic [DATA_WIDTH-1:0]  exp_wdata;
        input string                  desc;
        begin
            mem_req  = 1'b1;
            mem_we   = 1'b1;
            mem_size = t_mem_size;
            addr     = t_addr;
            wdata    = t_wdata;
            dc_rdata = '0;
            #1;
            if (dc_wstrb === exp_wstrb && dc_wdata === exp_wdata) begin
                $display("PASS | %s", desc);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (dc_wstrb !== exp_wstrb) $display("       dc_wstrb: got=%04b exp=%04b", dc_wstrb, exp_wstrb);
                if (dc_wdata !== exp_wdata) $display("       dc_wdata: got=%h   exp=%h",   dc_wdata, exp_wdata);
                fail_count++;
            end
        end
    endtask

    // --- Load checker: verifies mem_rdata (sign/zero extension + lane extraction) ---
    task check_load;
        input logic [2:0]             t_mem_size;
        input logic [ADDR_WIDTH-1:0]  t_addr;
        input logic [DATA_WIDTH-1:0]  t_dc_rdata;
        input logic [DATA_WIDTH-1:0]  exp_rdata;
        input string                  desc;
        begin
            mem_req  = 1'b1;
            mem_we   = 1'b0;
            mem_size = t_mem_size;
            addr     = t_addr;
            wdata    = '0;
            dc_rdata = t_dc_rdata;
            #1;
            if (mem_rdata === exp_rdata) begin
                $display("PASS | %s", desc);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                $display("       mem_rdata: got=%h exp=%h", mem_rdata, exp_rdata);
                fail_count++;
            end
        end
    endtask

    // --- Passthrough checker ---
    task check_passthrough;
        input logic                   t_mem_req, t_mem_we;
        input logic [ADDR_WIDTH-1:0]  t_addr;
        input logic                   t_dc_valid, t_dc_ready;
        input string                  desc;
        begin
            mem_req  = t_mem_req;
            mem_we   = t_mem_we;
            addr     = t_addr;
            dc_valid = t_dc_valid;
            dc_ready = t_dc_ready;
            #1;
            if (dc_req === t_mem_req && dc_we === t_mem_we &&
                dc_addr === t_addr   &&
                mem_valid === t_dc_valid && mem_ready === t_dc_ready) begin
                $display("PASS | %s", desc);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (dc_req   !== t_mem_req)   $display("       dc_req  : got=%0b exp=%0b", dc_req,   t_mem_req);
                if (dc_we    !== t_mem_we)    $display("       dc_we   : got=%0b exp=%0b", dc_we,    t_mem_we);
                if (dc_addr  !== t_addr)      $display("       dc_addr : got=%h  exp=%h",  dc_addr,  t_addr);
                if (mem_valid !== t_dc_valid) $display("       mem_valid: got=%0b exp=%0b", mem_valid, t_dc_valid);
                if (mem_ready !== t_dc_ready) $display("       mem_ready: got=%0b exp=%0b", mem_ready, t_dc_ready);
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
        dc_valid   = 1'b1;
        dc_ready   = 1'b1;

        // =====================================================================
        // --- STORE PATH ---
        // =====================================================================

        // --- Byte store: wstrb one-hot, wdata replicated to all 4 lanes ---
        // Use 0xAB to catch zero-pad bug (if wrong: lane != addr[1:0] gets 0x00)
        check_store(3'b000, 32'h100, 32'hABCD_1234, 4'b0001, 32'h3434_3434, "SB addr[1:0]=00: wstrb=0001, wdata replicated");
        check_store(3'b000, 32'h101, 32'hABCD_1234, 4'b0010, 32'h3434_3434, "SB addr[1:0]=01: wstrb=0010, wdata replicated");
        check_store(3'b000, 32'h102, 32'hABCD_1234, 4'b0100, 32'h3434_3434, "SB addr[1:0]=10: wstrb=0100, wdata replicated");
        check_store(3'b000, 32'h103, 32'hABCD_1234, 4'b1000, 32'h3434_3434, "SB addr[1:0]=11: wstrb=1000, wdata replicated");

        // --- Halfword store: wstrb 2-bit aligned, wdata replicated to both halves ---
        check_store(3'b001, 32'h100, 32'hABCD_1234, 4'b0011, 32'h1234_1234, "SH addr[1]=0: wstrb=0011, wdata replicated");
        check_store(3'b001, 32'h102, 32'hABCD_1234, 4'b1100, 32'h1234_1234, "SH addr[1]=1: wstrb=1100, wdata replicated");

        // --- Word store: all bytes enabled, wdata passthrough ---
        check_store(3'b010, 32'h100, 32'hDEAD_BEEF, 4'b1111, 32'hDEAD_BEEF, "SW: wstrb=1111, wdata passthrough");

        // =====================================================================
        // --- LOAD PATH ---
        // =====================================================================
        // dc_rdata = 32'hAABBCCDD  (AA=byte3, BB=byte2, CC=byte1, DD=byte0)
        //                           byte3[31:24] byte2[23:16] byte1[15:8] byte0[7:0]

        // --- LB (3'b000): sign-extend byte ---
        // 0xDD = 1101_1101 → sign bit=1 → sign-extend to 0xFFFF_FFDD
        check_load(3'b000, 32'h100, 32'hAABBCCDD, 32'hFFFF_FFDD, "LB addr[1:0]=00: extract byte0=0xDD, sign-extend");
        check_load(3'b000, 32'h101, 32'hAABBCCDD, 32'hFFFF_FFCC, "LB addr[1:0]=01: extract byte1=0xCC, sign-extend");
        check_load(3'b000, 32'h102, 32'hAABBCCDD, 32'hFFFF_FFBB, "LB addr[1:0]=10: extract byte2=0xBB, sign-extend");
        check_load(3'b000, 32'h103, 32'hAABBCCDD, 32'hFFFF_FFAA, "LB addr[1:0]=11: extract byte3=0xAA, sign-extend");
        // positive byte: 0x7F → sign-extend to 0x0000_007F
        check_load(3'b000, 32'h100, 32'hAABBCC7F, 32'h0000_007F, "LB positive byte (0x7F): no sign-extend");

        // --- LBU (3'b100): zero-extend byte ---
        // same 0xDD but zero-extended → 0x0000_00DD
        check_load(3'b100, 32'h100, 32'hAABBCCDD, 32'h0000_00DD, "LBU addr[1:0]=00: zero-extend, no sign");
        check_load(3'b100, 32'h102, 32'hAABBCCDD, 32'h0000_00BB, "LBU addr[1:0]=10: zero-extend");

        // --- LH (3'b001): sign-extend halfword ---
        // addr[1]=0 → lower half = 0xCCDD, sign bit(15)=1 → 0xFFFF_CCDD
        check_load(3'b001, 32'h100, 32'hAABBCCDD, 32'hFFFF_CCDD, "LH addr[1]=0: extract lower half, sign-extend");
        // addr[1]=1 → upper half = 0xAABB, sign bit(15)=1 → 0xFFFF_AABB
        check_load(3'b001, 32'h102, 32'hAABBCCDD, 32'hFFFF_AABB, "LH addr[1]=1: extract upper half, sign-extend");
        // positive half: 0x7FFF → 0x0000_7FFF
        check_load(3'b001, 32'h100, 32'hAABB7FFF, 32'h0000_7FFF, "LH positive half (0x7FFF): no sign-extend");

        // --- LHU (3'b101): zero-extend halfword ---
        check_load(3'b101, 32'h100, 32'hAABBCCDD, 32'h0000_CCDD, "LHU addr[1]=0: zero-extend lower half");
        check_load(3'b101, 32'h102, 32'hAABBCCDD, 32'h0000_AABB, "LHU addr[1]=1: zero-extend upper half");

        // --- LW (3'b010): word passthrough, addr ignored ---
        check_load(3'b010, 32'h100, 32'hDEAD_BEEF, 32'hDEAD_BEEF, "LW: word passthrough");

        // =====================================================================
        // --- PASSTHROUGH signals ---
        // =====================================================================
        check_passthrough(1'b1, 1'b0, 32'hABCD_0000, 1'b1, 1'b1, "passthrough: req=1 we=0 valid=1 ready=1");
        check_passthrough(1'b0, 1'b0, 32'h1234_5678, 1'b0, 1'b1, "passthrough: req=0 → dc_req=0");
        check_passthrough(1'b1, 1'b1, 32'hDEAD_BEEF, 1'b0, 1'b0, "passthrough: valid=0 ready=0 (cache miss)");

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("LSU TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
