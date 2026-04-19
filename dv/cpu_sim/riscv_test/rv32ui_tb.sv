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
// Module       : rv32ui_tb
// Description  : RISC-V official ISA test runner cho rv32ui-p suite.
//
//                Voi moi test trong TESTS list:
//                  1. Preload .mem vao axi_slave_model
//                  2. Reset SoC
//                  3. Poll tohost (0x1000) moi cycle
//                  4. Khi tohost != 0: decode ket qua
//                       tohost == 1         -> PASS
//                       tohost le (bit0=1)  -> FAIL tai test vector (tohost >> 1)
//                  5. Timeout sau MAX_CYCLES -> TIMEOUT
//                  6. In summary sau khi chay het tat ca tests
//
//                .mem files duoc build tu tb/riscv_test/ (make all)
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-15
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module rv32ui_tb;
    import cache_pkg::*;
    import axi_pkg::*;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam TOHOST_ADDR  = 32'h1000;     // khop voi link.ld
    localparam MAX_CYCLES   = 5_000;        // timeout per test
    //   uoc luong: ~38 tests * ~500 cycles/test << 5000 -> du rong

    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    logic clk, rst_n, fence, fence_done;

    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // -------------------------------------------------------------------------
    // AXI4 wires
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
    logic [1:0]             m_axi_awburst;

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
    // Memory model: VERBOSE=0 de giam log noise khi chay 38 tests lien tiep
    // -------------------------------------------------------------------------
    axi_slave_model #(
        .MEM_SIZE      (65536),
        .READ_LATENCY  (15),
        .WRITE_LATENCY (10),
        .VERBOSE       (1'b0)
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
    // Test runner infrastructure
    // -------------------------------------------------------------------------
    int  pass_count;
    int  fail_count;
    int  timeout_count;
    int  cycle_cnt;

    // Reset task: 4 cycle low, 1 cycle high
    task do_reset();
        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
    endtask

    // Run 1 test: load mem, reset, poll tohost, report
    // Tra ve 1=PASS, 0=FAIL/TIMEOUT
    task automatic run_one_test;
        input string mem_path;
        input string test_name;
        output int   result;    // 1=pass, 0=fail, -1=timeout

        logic [31:0] tohost_val;
        int          failed_vec;
        begin
            // --- Xoa tohost truoc khi load program moi ---
            mem_model.write_word(TOHOST_ADDR, 32'h0);

            // --- Load program ---
            mem_model.preload_from_file(mem_path);

            // --- Reset ---
            do_reset();

            // --- Poll tohost moi cycle ---
            tohost_val = 32'h0;
            for (cycle_cnt = 0; cycle_cnt < MAX_CYCLES; cycle_cnt++) begin
                @(posedge clk);
                tohost_val = mem_model.read_word(TOHOST_ADDR);
                if (tohost_val != 32'h0) break;
            end

            // --- Decode ket qua ---
            if (cycle_cnt == MAX_CYCLES) begin
                $display("TIMEOUT | %-30s  (> %0d cycles)", test_name, MAX_CYCLES);
                timeout_count++;
                result = -1;
            end else if (tohost_val == 32'h1) begin
                $display("PASS    | %-30s  (%0d cycles)", test_name, cycle_cnt);
                pass_count++;
                result = 1;
            end else begin
                // tohost = (failed_vec << 1) | 1
                failed_vec = int'(tohost_val >> 1);
                $display("FAIL    | %-30s  FAIL at test vector #%0d  (tohost=0x%h, %0d cycles)",
                         test_name, failed_vec, tohost_val, cycle_cnt);
                fail_count++;
                result = 0;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main sequence
    // -------------------------------------------------------------------------
    // Duong dan den .mem files (tuong doi so voi noi Vivado chay TCL: work/)
    // Vivado chay tu work/ -> can di len 5 cap de toi tb/riscv_test/build/
    localparam string MEM_BASE = "../../../../../tb/riscv_test/build/";

    int dummy;

    initial begin
        pass_count    = 0;
        fail_count    = 0;
        timeout_count = 0;
        fence         = 1'b0;
        rst_n         = 1'b1;

        $display("============================================================");
        $display("  rv32ui_tb  --  RISC-V Official ISA Test Suite (rv32ui-p)");
        $display("  SoC: Advanced RISC-V 32-bit  |  MAX_CYCLES/test: %0d", MAX_CYCLES);
        $display("============================================================");

        // --- Chay tung test ---
        run_one_test({MEM_BASE, "rv32ui-p-simple.mem"},  "rv32ui-p-simple",  dummy);
        run_one_test({MEM_BASE, "rv32ui-p-add.mem"},     "rv32ui-p-add",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-addi.mem"},    "rv32ui-p-addi",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-and.mem"},     "rv32ui-p-and",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-andi.mem"},    "rv32ui-p-andi",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-auipc.mem"},   "rv32ui-p-auipc",   dummy);
        run_one_test({MEM_BASE, "rv32ui-p-beq.mem"},     "rv32ui-p-beq",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-bge.mem"},     "rv32ui-p-bge",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-bgeu.mem"},    "rv32ui-p-bgeu",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-blt.mem"},     "rv32ui-p-blt",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-bltu.mem"},    "rv32ui-p-bltu",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-bne.mem"},     "rv32ui-p-bne",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-jal.mem"},     "rv32ui-p-jal",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-jalr.mem"},    "rv32ui-p-jalr",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lb.mem"},      "rv32ui-p-lb",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lbu.mem"},     "rv32ui-p-lbu",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lh.mem"},      "rv32ui-p-lh",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lhu.mem"},     "rv32ui-p-lhu",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lw.mem"},      "rv32ui-p-lw",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lui.mem"},     "rv32ui-p-lui",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-or.mem"},      "rv32ui-p-or",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-ori.mem"},     "rv32ui-p-ori",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sb.mem"},      "rv32ui-p-sb",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sh.mem"},      "rv32ui-p-sh",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sw.mem"},      "rv32ui-p-sw",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sll.mem"},     "rv32ui-p-sll",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-slli.mem"},    "rv32ui-p-slli",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-slt.mem"},     "rv32ui-p-slt",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-slti.mem"},    "rv32ui-p-slti",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sltiu.mem"},   "rv32ui-p-sltiu",   dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sltu.mem"},    "rv32ui-p-sltu",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sra.mem"},     "rv32ui-p-sra",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-srai.mem"},    "rv32ui-p-srai",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-srl.mem"},     "rv32ui-p-srl",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-srli.mem"},    "rv32ui-p-srli",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sub.mem"},     "rv32ui-p-sub",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-xor.mem"},     "rv32ui-p-xor",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-xori.mem"},    "rv32ui-p-xori",    dummy);

        // --- Summary ---
        $display("============================================================");
        $display("  SUMMARY: %0d PASS | %0d FAIL | %0d TIMEOUT  (total: %0d)",
                 pass_count, fail_count, timeout_count,
                 pass_count + fail_count + timeout_count);
        if (fail_count == 0 && timeout_count == 0)
            $display("  >> ALL TESTS PASSED <<");
        else
            $display("  >> FAILURES DETECTED -- see FAIL lines above <<");
        $display("============================================================");

        $finish;
    end

endmodule
