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
// Project      : Advanced RISC-V 32-bit SoC
// Module       : riscv_soc_tb
// Description  : Full-system integration testbench.
//                Loads sw/program.mem (compiled from sw/main.c) into
//                axi_slave_model, resets the SoC, runs until the CPU
//                reaches the _halt loop (PC=0x8), then checks results
//                written by the C program to memory at RESULT_BASE=0x2000.
//
//                Program exercises:
//                  sum 1..10        → 0x2000 = 55
//                  fibonacci f(10)  → 0x2004 = 55
//                  2^8 via loop     → 0x2008 = 256
//                  max{3,1,4,1,5,9,2,6} → 0x200C = 9
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-03
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module riscv_soc_tb;
    import cache_pkg::*;
    import axi_pkg::*;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam RESULT_BASE  = 32'h2000;
    localparam HALT_PC      = 32'h8;        // _halt: j 0x8
    // Run for this many cycles then check results.
    // 2000 cycles >> estimated ~700 needed (15 icache misses × 22cy +
    // 5 dcache misses × 22cy + execution overhead + write-buffer drain).
    localparam RUN_CYCLES   = 2_000;

    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    logic clk, rst_n, fence;
    logic fence_done;

    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // -------------------------------------------------------------------------
    // AXI4 wires between SoC and memory model
    // -------------------------------------------------------------------------
    logic                   m_axi_arvalid, m_axi_arready;
    logic [ADDR_WIDTH-1:0]  m_axi_araddr;
    logic [7:0]             m_axi_arlen;
    logic [2:0]             m_axi_arsize;
    logic [1:0]             m_axi_arburst;

    logic                   m_axi_rvalid,  m_axi_rready;
    logic [DATA_WIDTH-1:0]  m_axi_rdata;
    logic [1:0]             m_axi_rresp;
    logic                   m_axi_rlast;

    logic                   m_axi_awvalid, m_axi_awready;
    logic [ADDR_WIDTH-1:0]  m_axi_awaddr;
    logic [7:0]             m_axi_awlen;
    logic [2:0]             m_axi_awsize;
    logic [1:0]             m_axi_awburst;  // separate from arburst

    logic                   m_axi_wvalid,  m_axi_wready;
    logic [DATA_WIDTH-1:0]  m_axi_wdata;
    logic [STRB_WIDTH-1:0]  m_axi_wstrb;
    logic                   m_axi_wlast;

    logic                   m_axi_bvalid,  m_axi_bready;
    logic [1:0]             m_axi_bresp;

    // -------------------------------------------------------------------------
    // DUT: riscv_soc
    // -------------------------------------------------------------------------
    riscv_soc soc (
        .clk            (clk),
        .rst_n          (rst_n),
        .fence          (fence),
        .fence_done     (fence_done),

        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),

        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),

        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),
        .m_axi_awsize   (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst),

        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),

        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_bresp    (m_axi_bresp)
    );

    // -------------------------------------------------------------------------
    // Memory model: AXI4 slave (64KB, verbose=0 to reduce log noise)
    // -------------------------------------------------------------------------
    axi_slave_model #(
        .MEM_SIZE      (65536),
        .READ_LATENCY  (15),
        .WRITE_LATENCY (10),
        .VERBOSE       (1'b1)
    ) mem_model (
        .clk            (clk),
        .rst_n          (rst_n),

        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),
        .s_axi_araddr   (m_axi_araddr),
        .s_axi_arlen    (m_axi_arlen),
        .s_axi_arsize   (m_axi_arsize),
        .s_axi_arburst  (m_axi_arburst),

        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready),
        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),

        .s_axi_awvalid  (m_axi_awvalid),
        .s_axi_awready  (m_axi_awready),
        .s_axi_awaddr   (m_axi_awaddr),
        .s_axi_awlen    (m_axi_awlen),
        .s_axi_awsize   (m_axi_awsize),
        .s_axi_awburst  (m_axi_awburst),

        .s_axi_wvalid   (m_axi_wvalid),
        .s_axi_wready   (m_axi_wready),
        .s_axi_wdata    (m_axi_wdata),
        .s_axi_wstrb    (m_axi_wstrb),
        .s_axi_wlast    (m_axi_wlast),

        .s_axi_bvalid   (m_axi_bvalid),
        .s_axi_bready   (m_axi_bready),
        .s_axi_bresp    (m_axi_bresp)
    );

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    task check_result;
        input logic [31:0] addr;
        input logic [31:0] expected;
        input string       desc;
        logic [31:0] got;
        begin
            got = mem_model.read_word(addr);
            if (got === expected) begin
                $display("PASS | %-40s  [0x%h] = 0x%h (%0d)", desc, addr, got, got);
                pass_count++;
            end else begin
                $display("FAIL | %-40s  [0x%h] got=0x%h exp=0x%h", desc, addr, got, expected);
                fail_count++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;
        fence      = 1'b0;

        // --- Load program into memory BEFORE reset ---
        mem_model.preload_from_file("../../../../../sw/program.mem");
        $display("========== riscv_soc_tb start ==========");
        $display("[TB] Program loaded: sw/program.mem");
        $display("[TB] Running %0d cycles...", RUN_CYCLES);

        // --- Reset sequence ---
        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;

        // --- Run fixed number of cycles ---
        // Avoids fork/join and while-loop constructs that can hang xvlog.
        // 2000 cycles is well above the ~700 needed to complete the program.
        repeat(RUN_CYCLES) @(posedge clk);

        $display("[TB] %0d cycles done. Checking results...", RUN_CYCLES);

        // --- Check results ---
        $display("[TB] Checking results at RESULT_BASE=0x%h:", RESULT_BASE);
        $display("--------------------------------------------");
        check_result(RESULT_BASE + 'h00, 32'd55,  "sum 1..10 = 55");
        check_result(RESULT_BASE + 'h04, 32'd55,  "fibonacci f(10) = 55");
        check_result(RESULT_BASE + 'h08, 32'd256, "2^8 via doubling = 256");
        check_result(RESULT_BASE + 'h0C, 32'd9,   "max{3,1,4,1,5,9,2,6} = 9");

        $display("--------------------------------------------");
        $display("riscv_soc_tb done: %0d PASS, %0d FAIL  (total cycles: %0d)",
                 pass_count, fail_count, RUN_CYCLES);
        $display("========================================");
        $finish;
    end

endmodule
