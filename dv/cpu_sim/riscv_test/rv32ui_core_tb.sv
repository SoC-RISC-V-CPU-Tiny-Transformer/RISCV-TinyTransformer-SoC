// -----------------------------------------------------------------------------
// Copyright (c) 2026 NGUYEN TO QUOC VIET
// Ho Chi Minh City University of Technology (HCMUT-VNU)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit SoC
// Module       : rv32ui_core_tb
// Description  : Chay rv32ui-p official ISA tests THANG VAO CORE,
//                BYPASS hoan toan cache_subsystem + axi.
//
//                Muc dich: tach baseline pass-rate cua core khoi nhieu cua
//                cache. Neu core_tb pass 38/38 -> bug 100% nam o cache.
//                Neu core_tb pass < 38 -> co them bug rieng o core.
//
//                Architecture:
//                  ┌────────────┐
//                  │ riscv_core │
//                  └─┬────────┬─┘
//                    │IF      │MEM
//                  ┌─▼────────▼─┐
//                  │  TB Memory │  <- 1 array, comb read, sync write
//                  │  (256 KB)  │  <- ready/valid = 1 always
//                  └────────────┘
//                  +preload_from_file (.mem hex)
//                  +read_word/write_word (verify tohost)
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-19
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module rv32ui_core_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam TOHOST_ADDR = 32'h1000;
    localparam MAX_CYCLES  = 5_000;
    localparam MEM_BYTES   = 65536;     // 64 KB du cho moi rv32ui-p test

    // -------------------------------------------------------------------------
    // Clock / reset
    // -------------------------------------------------------------------------
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Core I/O
    // -------------------------------------------------------------------------
    logic                   if_req;
    logic [ADDR_WIDTH-1:0]  if_pc;
    logic [DATA_WIDTH-1:0]  if_instr;
    logic                   if_icache_ready, if_icache_valid;

    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req, mem_we;
    logic [DATA_WIDTH-1:0]  mem_wdata;
    logic [3:0]             mem_wstrb;
    logic [DATA_WIDTH-1:0]  mem_rdata;
    logic                   mem_dcache_ready, mem_dcache_valid;

    // -------------------------------------------------------------------------
    // BACKING STORE: byte-addressable, single array (compatible voi $readmemh
    // format giong axi_slave_model)
    // -------------------------------------------------------------------------
    logic [7:0] mem [0:MEM_BYTES-1];

    // -------------------------------------------------------------------------
    // Instruction fetch path: combinational read, ready/valid luon =1
    //   if_pc[1:0] dam bao = 0 (riscv aligned)
    // -------------------------------------------------------------------------
    logic [ADDR_WIDTH-1:0] if_idx;
    assign if_idx = if_pc & 32'h0001_FFFF;  // mask vao 128 KB (bit 16:0)

    assign if_instr        = {mem[if_idx+3], mem[if_idx+2],
                              mem[if_idx+1], mem[if_idx+0]};
    assign if_icache_ready = 1'b1;
    assign if_icache_valid = 1'b1;

    // -------------------------------------------------------------------------
    // Data load path: combinational read tu backing store
    //   Core LSU lo sign-ext + alignment dua tren mem_size
    //   -> TB chi can tra ve word-aligned 32 bit
    // -------------------------------------------------------------------------
    logic [ADDR_WIDTH-1:0] mem_idx_word;
    assign mem_idx_word = (mem_addr & 32'h0001_FFFC);  // word-align

    assign mem_rdata        = {mem[mem_idx_word+3], mem[mem_idx_word+2],
                               mem[mem_idx_word+1], mem[mem_idx_word+0]};
    assign mem_dcache_ready = 1'b1;
    assign mem_dcache_valid = 1'b1;

    // -------------------------------------------------------------------------
    // Data store path: sync write voi wstrb byte-enable
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (mem_req && mem_we) begin
            if (mem_wstrb[0]) mem[mem_idx_word+0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) mem[mem_idx_word+1] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) mem[mem_idx_word+2] <= mem_wdata[23:16];
            if (mem_wstrb[3]) mem[mem_idx_word+3] <= mem_wdata[31:24];
        end
    end

    // -------------------------------------------------------------------------
    // DUT: riscv_core (KHONG qua cache_subsystem!)
    // -------------------------------------------------------------------------
    riscv_core dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .if_req           (if_req),
        .if_pc            (if_pc),
        .if_instr         (if_instr),
        .if_icache_ready  (if_icache_ready),
        .if_icache_valid  (if_icache_valid),
        .mem_addr         (mem_addr),
        .mem_req          (mem_req),
        .mem_we           (mem_we),
        .mem_wdata        (mem_wdata),
        .mem_wstrb        (mem_wstrb),
        .mem_rdata        (mem_rdata),
        .mem_dcache_ready (mem_dcache_ready),
        .mem_dcache_valid (mem_dcache_valid)
    );

    // -------------------------------------------------------------------------
    // Memory utilities (clone API tu axi_slave_model)
    // -------------------------------------------------------------------------
    task automatic preload_from_file(input string filepath);
        // Clear memory truoc khi load (tranh leak tu test truoc)
        for (int i = 0; i < MEM_BYTES; i++) mem[i] = 8'h00;
        $readmemh(filepath, mem);
    endtask

    task automatic write_word(input logic [ADDR_WIDTH-1:0] addr,
                              input logic [DATA_WIDTH-1:0] data);
        mem[addr+0] = data[ 7: 0];
        mem[addr+1] = data[15: 8];
        mem[addr+2] = data[23:16];
        mem[addr+3] = data[31:24];
    endtask

    function automatic logic [DATA_WIDTH-1:0] read_word(
        input logic [ADDR_WIDTH-1:0] addr);
        return {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr+0]};
    endfunction

    // -------------------------------------------------------------------------
    // Test runner
    // -------------------------------------------------------------------------
    int  pass_count;
    int  fail_count;
    int  timeout_count;
    int  cycle_cnt;

    task do_reset();
        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
    endtask

    task automatic run_one_test;
        input string mem_path;
        input string test_name;
        output int   result;

        logic [31:0] tohost_val;
        int          failed_vec;
        begin
            // Clear tohost truoc
            write_word(TOHOST_ADDR, 32'h0);

            // Load program
            preload_from_file(mem_path);

            // Reset
            do_reset();

            // Poll tohost
            tohost_val = 32'h0;
            for (cycle_cnt = 0; cycle_cnt < MAX_CYCLES; cycle_cnt++) begin
                @(posedge clk);
                tohost_val = read_word(TOHOST_ADDR);
                if (tohost_val != 32'h0) break;
            end

            // Decode
            if (cycle_cnt == MAX_CYCLES) begin
                $display("TIMEOUT | %-30s  (> %0d cycles)", test_name, MAX_CYCLES);
                timeout_count++;
                result = -1;
            end else if (tohost_val == 32'h1) begin
                $display("PASS    | %-30s  (%0d cycles)", test_name, cycle_cnt);
                pass_count++;
                result = 1;
            end else begin
                failed_vec = int'(tohost_val >> 1);
                $display("FAIL    | %-30s  FAIL at test vector #%0d  (tohost=0x%h, %0d cycles)",
                         test_name, failed_vec, tohost_val, cycle_cnt);
                fail_count++;
                result = 0;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main
    // -------------------------------------------------------------------------
    localparam string MEM_BASE = "../../../../../tb/riscv_test/build/";

    int dummy;

    initial begin
        pass_count    = 0;
        fail_count    = 0;
        timeout_count = 0;
        rst_n         = 1'b1;

        // Init memory toan bo
        for (int i = 0; i < MEM_BYTES; i++) mem[i] = 8'h00;

        $display("============================================================");
        $display("  rv32ui_core_tb -- CORE-ONLY (bypass cache_subsystem)");
        $display("  MAX_CYCLES/test: %0d  |  MEM_BYTES: %0d", MAX_CYCLES, MEM_BYTES);
        $display("============================================================");

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

        // Summary
        $display("============================================================");
        $display("  CORE-ONLY SUMMARY: %0d PASS | %0d FAIL | %0d TIMEOUT  (total: %0d)",
                 pass_count, fail_count, timeout_count,
                 pass_count + fail_count + timeout_count);
        if (fail_count == 0 && timeout_count == 0)
            $display("  >> ALL TESTS PASSED -- CORE 100%% CLEAN, BUG IN CACHE_SUBSYSTEM <<");
        else
            $display("  >> CORE STILL HAS BUGS -- fix these BEFORE debugging cache <<");
        $display("============================================================");

        $finish;
    end

endmodule
