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
// Module       : rf_tb
// Description  : Testbench for Register File — verifies:
//                  normal write + read-back (sync write, async read)
//                  write-first forwarding on rs1 and rs2 simultaneously
//                  x0 hardwired-zero (write blocked, read always 0)
//                  write-enable guard (reg_we=0 → no write)
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-02
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module rf_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                     clk;
    logic [DATA_WIDTH-1:0]    instr;
    logic [DATA_WIDTH-1:0]    rdata1, rdata2;
    logic                     reg_we;
    logic [4:0]               rd;
    logic [DATA_WIDTH-1:0]    wdata;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    rf dut (
        .clk    (clk),
        .instr  (instr),
        .rdata1 (rdata1),
        .rdata2 (rdata2),
        .reg_we (reg_we),
        .rd     (rd),
        .wdata  (wdata)
    );

    // -------------------------------------------------------------------------
    // Clock generation: 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    // Build instr word with rs1 at [19:15] and rs2 at [24:20]
    function automatic logic [31:0] mk_instr;
        input logic [4:0] rs1, rs2;
        logic [31:0] i;
        i = 32'h0;
        i[19:15] = rs1;
        i[24:20] = rs2;
        return i;
    endfunction

    // Write a value to rd on the next posedge, then idle (reg_we=0)
    task do_write;
        input logic [4:0]               t_rd;
        input logic [DATA_WIDTH-1:0]    t_wdata;
        begin
            @(negedge clk);     // set up before posedge
            rd     = t_rd;
            wdata  = t_wdata;
            reg_we = 1'b1;
            @(posedge clk);     // write latched here
            #1;                 // small settle after edge
            reg_we = 1'b0;
        end
    endtask

    // Read rs1/rs2 and compare with expected values (combinational, no clock)
    task check_read;
        input logic [4:0]               t_rs1, t_rs2;
        input logic [DATA_WIDTH-1:0]    exp1,  exp2;
        input string                    desc;
        begin
            instr = mk_instr(t_rs1, t_rs2);
            #1;
            if (rdata1 === exp1 && rdata2 === exp2) begin
                $display("PASS | %s  rdata1=%h rdata2=%h", desc, rdata1, rdata2);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (rdata1 !== exp1) $display("       rdata1: got=%h exp=%h", rdata1, exp1);
                if (rdata2 !== exp2) $display("       rdata2: got=%h exp=%h", rdata2, exp2);
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

        reg_we = 0;
        rd     = 0;
        wdata  = 0;
        instr  = 0;

        // =====================================================================
        // --- Basic write and read-back ---
        // =====================================================================

        do_write(5'd1,  32'hDEAD_BEEF);
        do_write(5'd2,  32'hCAFE_BABE);
        do_write(5'd3,  32'h1234_5678);
        do_write(5'd4,  32'hA5A5_A5A5);
        do_write(5'd5,  32'h0000_0001);
        do_write(5'd31, 32'hFFFF_FFFF);

        // Read back with no concurrent write (reg_we=0 at this point)
        check_read(5'd1, 5'd2, 32'hDEAD_BEEF, 32'hCAFE_BABE, "read x1, x2");
        check_read(5'd3, 5'd4, 32'h1234_5678, 32'hA5A5_A5A5, "read x3, x4");
        check_read(5'd5, 5'd31, 32'h0000_0001, 32'hFFFF_FFFF, "read x5, x31");

        // Same register on both ports
        check_read(5'd3, 5'd3, 32'h1234_5678, 32'h1234_5678, "read same reg on both ports");

        // =====================================================================
        // --- x0 hardwired zero ---
        // =====================================================================

        // Write to x0 — should be silently ignored
        do_write(5'd0, 32'hDEAD_BEEF);

        // x0 must still read as 0
        check_read(5'd0, 5'd0, 32'h0, 32'h0, "x0 always 0 after write attempt");
        check_read(5'd0, 5'd1, 32'h0, 32'hDEAD_BEEF, "x0=0 on rs1, x1 normal on rs2");

        // =====================================================================
        // --- reg_we = 0: no write ---
        // =====================================================================

        // Try to overwrite x1 with reg_we=0
        @(negedge clk);
        rd     = 5'd1;
        wdata  = 32'h1111_1111;
        reg_we = 1'b0;
        @(posedge clk);
        #1;
        // x1 must still hold its original value
        check_read(5'd1, 5'd2, 32'hDEAD_BEEF, 32'hCAFE_BABE, "reg_we=0: x1 unchanged");

        // =====================================================================
        // --- Write-first forwarding ---
        // =====================================================================
        // While reg_we=1 and rd=rs1: rdata1 should immediately return wdata
        // (combinational bypass before the clock edge latches the value)

        @(negedge clk);
        rd     = 5'd6;
        wdata  = 32'hABCD_1234;
        reg_we = 1'b1;
        instr  = mk_instr(5'd6, 5'd2);  // rs1=x6, rs2=x2
        #1;
        // rdata1 should forward wdata for x6; rdata2 reads stored x2
        if (rdata1 === 32'hABCD_1234 && rdata2 === 32'hCAFE_BABE) begin
            $display("PASS | write-first fwd rs1: rdata1 forwarded=%h rdata2=%h", rdata1, rdata2);
            pass_count++;
        end else begin
            $display("FAIL | write-first fwd rs1");
            if (rdata1 !== 32'hABCD_1234) $display("       rdata1: got=%h exp=%h", rdata1, 32'hABCD_1234);
            if (rdata2 !== 32'hCAFE_BABE) $display("       rdata2: got=%h exp=%h", rdata2, 32'hCAFE_BABE);
            fail_count++;
        end
        @(posedge clk); #1;
        reg_we = 0;

        // Forwarding on rs2
        @(negedge clk);
        rd     = 5'd7;
        wdata  = 32'h9999_9999;
        reg_we = 1'b1;
        instr  = mk_instr(5'd1, 5'd7);  // rs1=x1, rs2=x7
        #1;
        if (rdata1 === 32'hDEAD_BEEF && rdata2 === 32'h9999_9999) begin
            $display("PASS | write-first fwd rs2: rdata1=%h rdata2 forwarded=%h", rdata1, rdata2);
            pass_count++;
        end else begin
            $display("FAIL | write-first fwd rs2");
            if (rdata1 !== 32'hDEAD_BEEF) $display("       rdata1: got=%h exp=%h", rdata1, 32'hDEAD_BEEF);
            if (rdata2 !== 32'h9999_9999) $display("       rdata2: got=%h exp=%h", rdata2, 32'h9999_9999);
            fail_count++;
        end
        @(posedge clk); #1;
        reg_we = 0;

        // Forwarding on both rs1 and rs2 (both read the register being written)
        @(negedge clk);
        rd     = 5'd8;
        wdata  = 32'h5A5A_5A5A;
        reg_we = 1'b1;
        instr  = mk_instr(5'd8, 5'd8);  // rs1=rs2=x8
        #1;
        if (rdata1 === 32'h5A5A_5A5A && rdata2 === 32'h5A5A_5A5A) begin
            $display("PASS | write-first fwd rs1+rs2: both forwarded=%h", rdata1);
            pass_count++;
        end else begin
            $display("FAIL | write-first fwd rs1+rs2");
            if (rdata1 !== 32'h5A5A_5A5A) $display("       rdata1: got=%h exp=%h", rdata1, 32'h5A5A_5A5A);
            if (rdata2 !== 32'h5A5A_5A5A) $display("       rdata2: got=%h exp=%h", rdata2, 32'h5A5A_5A5A);
            fail_count++;
        end
        @(posedge clk); #1;
        reg_we = 0;

        // x0 guard on forwarding: writing to x0 with reg_we=1 must NOT forward
        @(negedge clk);
        rd     = 5'd0;
        wdata  = 32'hDEAD_DEAD;
        reg_we = 1'b1;
        instr  = mk_instr(5'd0, 5'd0);
        #1;
        if (rdata1 === 32'h0 && rdata2 === 32'h0) begin
            $display("PASS | x0 forward guard: no fwd when rd=x0, rdata1=%h rdata2=%h", rdata1, rdata2);
            pass_count++;
        end else begin
            $display("FAIL | x0 forward guard");
            if (rdata1 !== 32'h0) $display("       rdata1: got=%h exp=0", rdata1);
            if (rdata2 !== 32'h0) $display("       rdata2: got=%h exp=0", rdata2);
            fail_count++;
        end
        @(posedge clk); #1;
        reg_we = 0;

        // =====================================================================
        // --- Verify forwarded values were actually written (read after clock) ---
        // =====================================================================
        check_read(5'd6, 5'd7, 32'hABCD_1234, 32'h9999_9999, "post-fwd write: x6 and x7 retained");
        check_read(5'd8, 5'd0, 32'h5A5A_5A5A, 32'h0,         "post-fwd write: x8 retained, x0=0");

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("RF TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
