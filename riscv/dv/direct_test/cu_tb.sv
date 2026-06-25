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
// Module       : cu_tb
// Description  : Testbench for Control Unit — verifies all control signals
//                for every RV32I opcode: OP_R, OP_I_ALU, OP_I_LOAD, OP_I_JALR,
//                OP_S, OP_B, OP_U_LUI, OP_U_AUIPC, OP_J, and default (invalid).
//                Also verifies alu_op deep-decode for OP_R / OP_I_ALU across
//                all 10 {funct7[5], funct3} combinations.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-02
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module cu_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] instr;

    logic [3:0]  alu_op;
    logic        alu_src;
    logic        alu_src_a;
    logic        mem_req;
    logic        mem_we;
    logic [2:0]  mem_size;
    logic        reg_we;
    logic [1:0]  wb_sel;
    logic        branch;
    logic        jump;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    cu dut (
        .instr      (instr),
        .alu_op     (alu_op),
        .alu_src    (alu_src),
        .alu_src_a  (alu_src_a),
        .mem_req    (mem_req),
        .mem_we     (mem_we),
        .mem_size   (mem_size),
        .reg_we     (reg_we),
        .wb_sel     (wb_sel),
        .branch     (branch),
        .jump       (jump)
    );

    // -------------------------------------------------------------------------
    // Test utilities
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    // Build a 32-bit instruction word from its fields.
    // CU only reads opcode[6:0], funct3[14:12], funct7[31:25] — R-type layout 
    function automatic logic [31:0] mk_instr;
        input logic [6:0] funct7;
        input logic [4:0] rs2, rs1, rd;
        input logic [2:0] funct3;
        input logic [6:0] opcode;
        return {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    // Check all 10 CU outputs in one shot.
    task check_ctrl;
        input logic [DATA_WIDTH-1:0] test_instr;
        input string                 desc;

        // expected values
        input logic [3:0] exp_alu_op;
        input logic       exp_alu_src;
        input logic       exp_alu_src_a;
        input logic       exp_mem_req;
        input logic       exp_mem_we;
        input logic [2:0] exp_mem_size;
        input logic       exp_reg_we;
        input logic [1:0] exp_wb_sel;
        input logic       exp_branch;
        input logic       exp_jump;

        logic ok;
        begin
            instr = test_instr;
            #1;

            ok = (alu_op    === exp_alu_op)    &&
                 (alu_src   === exp_alu_src)    &&
                 (alu_src_a === exp_alu_src_a)  &&
                 (mem_req   === exp_mem_req)    &&
                 (mem_we    === exp_mem_we)     &&
                 (mem_size  === exp_mem_size)   &&
                 (reg_we    === exp_reg_we)     &&
                 (wb_sel    === exp_wb_sel)     &&
                 (branch    === exp_branch)     &&
                 (jump      === exp_jump);

            if (ok) begin
                $display("PASS | %s", desc);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (alu_op    !== exp_alu_op)    $display("       alu_op   : got=%0d exp=%0d", alu_op,    exp_alu_op);
                if (alu_src   !== exp_alu_src)   $display("       alu_src  : got=%0b exp=%0b", alu_src,   exp_alu_src);
                if (alu_src_a !== exp_alu_src_a) $display("       alu_src_a: got=%0b exp=%0b", alu_src_a, exp_alu_src_a);
                if (mem_req   !== exp_mem_req)   $display("       mem_req  : got=%0b exp=%0b", mem_req,   exp_mem_req);
                if (mem_we    !== exp_mem_we)    $display("       mem_we   : got=%0b exp=%0b", mem_we,    exp_mem_we);
                if (mem_size  !== exp_mem_size)  $display("       mem_size : got=%0b exp=%0b", mem_size,  exp_mem_size);
                if (reg_we    !== exp_reg_we)    $display("       reg_we   : got=%0b exp=%0b", reg_we,    exp_reg_we);
                if (wb_sel    !== exp_wb_sel)    $display("       wb_sel   : got=%0b exp=%0b", wb_sel,    exp_wb_sel);
                if (branch    !== exp_branch)    $display("       branch   : got=%0b exp=%0b", branch,    exp_branch);
                if (jump      !== exp_jump)      $display("       jump     : got=%0b exp=%0b", jump,      exp_jump);
                fail_count++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test vectors
    // -------------------------------------------------------------------------
    // check_ctrl(instr, desc,
    //   alu_op, alu_src, alu_src_a, mem_req, mem_we, mem_size,
    //   reg_we, wb_sel, branch, jump)
    // -------------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        // --- OP_R: ADD x1, x2, x3 ---
        // reg_we=1, alu_src=0, alu_src_a=0, mem=off, wb=ALU, branch=0, jump=0
        // alu_op from {funct7[5], funct3}
        check_ctrl(mk_instr(7'b0000000, 5'd3, 5'd2, 5'd1, 3'b000, OP_R), "OP_R ADD",
            ALU_ADD,  0, 0, 0, 0, 3'b000, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0100000, 5'd3, 5'd2, 5'd1, 3'b000, OP_R), "OP_R SUB",
            ALU_SUB,  0, 0, 0, 0, 3'b000, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd3, 5'd2, 5'd1, 3'b001, OP_R), "OP_R SLL",
            ALU_SLL,  0, 0, 0, 0, 3'b001, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd3, 5'd2, 5'd1, 3'b010, OP_R), "OP_R SLT",
            ALU_SLT,  0, 0, 0, 0, 3'b010, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd3, 5'd2, 5'd1, 3'b011, OP_R), "OP_R SLTU",
            ALU_SLTU, 0, 0, 0, 0, 3'b011, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd3, 5'd2, 5'd1, 3'b100, OP_R), "OP_R XOR",
            ALU_XOR,  0, 0, 0, 0, 3'b100, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd3, 5'd2, 5'd1, 3'b101, OP_R), "OP_R SRL",
            ALU_SRL,  0, 0, 0, 0, 3'b101, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0100000, 5'd3, 5'd2, 5'd1, 3'b101, OP_R), "OP_R SRA",
            ALU_SRA,  0, 0, 0, 0, 3'b101, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd3, 5'd2, 5'd1, 3'b110, OP_R), "OP_R OR",
            ALU_OR,   0, 0, 0, 0, 3'b110, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd3, 5'd2, 5'd1, 3'b111, OP_R), "OP_R AND",
            ALU_AND,  0, 0, 0, 0, 3'b111, 1, WB_ALU, 0, 0);

        // --- OP_I_ALU: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI x1, x2, imm ---
        // alu_src=1 (uses imm), reg_we=1, mem=off, wb=ALU, branch=0, jump=0
        // Note: for SRAI the immediate encodes funct7[5]=1 in bit[30] of the I-type
        check_ctrl(mk_instr(7'b0000000, 5'd0, 5'd2, 5'd1, 3'b000, OP_I_ALU), "OP_I_ALU ADDI",
            ALU_ADD,  1, 0, 0, 0, 3'b000, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd0, 5'd2, 5'd1, 3'b010, OP_I_ALU), "OP_I_ALU SLTI",
            ALU_SLT,  1, 0, 0, 0, 3'b010, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd0, 5'd2, 5'd1, 3'b011, OP_I_ALU), "OP_I_ALU SLTIU",
            ALU_SLTU, 1, 0, 0, 0, 3'b011, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd0, 5'd2, 5'd1, 3'b100, OP_I_ALU), "OP_I_ALU XORI",
            ALU_XOR,  1, 0, 0, 0, 3'b100, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd0, 5'd2, 5'd1, 3'b110, OP_I_ALU), "OP_I_ALU ORI",
            ALU_OR,   1, 0, 0, 0, 3'b110, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd0, 5'd2, 5'd1, 3'b111, OP_I_ALU), "OP_I_ALU ANDI",
            ALU_AND,  1, 0, 0, 0, 3'b111, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd0, 5'd2, 5'd1, 3'b001, OP_I_ALU), "OP_I_ALU SLLI",
            ALU_SLL,  1, 0, 0, 0, 3'b001, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0000000, 5'd0, 5'd2, 5'd1, 3'b101, OP_I_ALU), "OP_I_ALU SRLI",
            ALU_SRL,  1, 0, 0, 0, 3'b101, 1, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'b0100000, 5'd0, 5'd2, 5'd1, 3'b101, OP_I_ALU), "OP_I_ALU SRAI",
            ALU_SRA,  1, 0, 0, 0, 3'b101, 1, WB_ALU, 0, 0);

        // --- OP_I_LOAD: LB/LH/LW/LBU/LHU x1, imm(x2) ---
        // alu_src=1, mem_req=1, reg_we=1, wb=MEM, branch=0, jump=0
        // alu_op=ALU_ADD (address calc), mem_size=funct3
        check_ctrl(mk_instr(7'd0, 5'd0, 5'd2, 5'd1, 3'b000, OP_I_LOAD), "OP_I_LOAD LB",
            ALU_ADD, 1, 0, 1, 0, 3'b000, 1, WB_MEM, 0, 0);

        check_ctrl(mk_instr(7'd0, 5'd0, 5'd2, 5'd1, 3'b001, OP_I_LOAD), "OP_I_LOAD LH",
            ALU_ADD, 1, 0, 1, 0, 3'b001, 1, WB_MEM, 0, 0);

        check_ctrl(mk_instr(7'd0, 5'd0, 5'd2, 5'd1, 3'b010, OP_I_LOAD), "OP_I_LOAD LW",
            ALU_ADD, 1, 0, 1, 0, 3'b010, 1, WB_MEM, 0, 0);

        check_ctrl(mk_instr(7'd0, 5'd0, 5'd2, 5'd1, 3'b100, OP_I_LOAD), "OP_I_LOAD LBU",
            ALU_ADD, 1, 0, 1, 0, 3'b100, 1, WB_MEM, 0, 0);

        check_ctrl(mk_instr(7'd0, 5'd0, 5'd2, 5'd1, 3'b101, OP_I_LOAD), "OP_I_LOAD LHU",
            ALU_ADD, 1, 0, 1, 0, 3'b101, 1, WB_MEM, 0, 0);

        // --- OP_I_JALR: JALR x1, imm(x2) ---
        // alu_src=1, reg_we=1, wb=PC4, jump=1, mem=off, branch=0
        check_ctrl(mk_instr(7'd0, 5'd0, 5'd2, 5'd1, 3'b000, OP_I_JALR), "OP_I_JALR",
            ALU_ADD, 1, 0, 0, 0, 3'b000, 1, WB_PC4, 0, 1);

        // --- OP_S: SB/SH/SW x1, imm(x2) ---
        // alu_src=1, mem_req=1, mem_we=1, reg_we=0, wb=ALU, branch=0, jump=0
        check_ctrl(mk_instr(7'd0, 5'd1, 5'd2, 5'd0, 3'b000, OP_S), "OP_S SB",
            ALU_ADD, 1, 0, 1, 1, 3'b000, 0, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'd0, 5'd1, 5'd2, 5'd0, 3'b001, OP_S), "OP_S SH",
            ALU_ADD, 1, 0, 1, 1, 3'b001, 0, WB_ALU, 0, 0);

        check_ctrl(mk_instr(7'd0, 5'd1, 5'd2, 5'd0, 3'b010, OP_S), "OP_S SW",
            ALU_ADD, 1, 0, 1, 1, 3'b010, 0, WB_ALU, 0, 0);

        // --- OP_B: BEQ/BNE/BLT/BGE/BLTU/BGEU x1, x2, imm ---
        // branch=1, all others default: alu_src=0, reg_we=0, mem=off, jump=0
        // alu_op=ALU_ADD (default), mem_size=funct3 (passthrough, ignored for branch)
        check_ctrl(mk_instr(7'd0, 5'd2, 5'd1, 5'd0, 3'b000, OP_B), "OP_B BEQ",
            ALU_ADD, 0, 0, 0, 0, 3'b000, 0, WB_ALU, 1, 0);

        check_ctrl(mk_instr(7'd0, 5'd2, 5'd1, 5'd0, 3'b001, OP_B), "OP_B BNE",
            ALU_ADD, 0, 0, 0, 0, 3'b001, 0, WB_ALU, 1, 0);

        check_ctrl(mk_instr(7'd0, 5'd2, 5'd1, 5'd0, 3'b100, OP_B), "OP_B BLT",
            ALU_ADD, 0, 0, 0, 0, 3'b100, 0, WB_ALU, 1, 0);

        check_ctrl(mk_instr(7'd0, 5'd2, 5'd1, 5'd0, 3'b101, OP_B), "OP_B BGE",
            ALU_ADD, 0, 0, 0, 0, 3'b101, 0, WB_ALU, 1, 0);

        check_ctrl(mk_instr(7'd0, 5'd2, 5'd1, 5'd0, 3'b110, OP_B), "OP_B BLTU",
            ALU_ADD, 0, 0, 0, 0, 3'b110, 0, WB_ALU, 1, 0);

        check_ctrl(mk_instr(7'd0, 5'd2, 5'd1, 5'd0, 3'b111, OP_B), "OP_B BGEU",
            ALU_ADD, 0, 0, 0, 0, 3'b111, 0, WB_ALU, 1, 0);

        // --- OP_U_LUI: LUI x1, imm ---
        // alu_op=PASS_B, alu_src=1, reg_we=1, wb=ALU, mem=off, branch=0, jump=0
        check_ctrl(mk_instr(7'd0, 5'd0, 5'd0, 5'd1, 3'b000, OP_U_LUI), "OP_U_LUI",
            ALU_PASS_B, 1, 0, 0, 0, 3'b000, 1, WB_ALU, 0, 0);

        // --- OP_U_AUIPC: AUIPC x1, imm ---
        // alu_src=1, alu_src_a=1 (PC as operand A), reg_we=1, wb=ALU, mem=off, branch=0, jump=0
        check_ctrl(mk_instr(7'd0, 5'd0, 5'd0, 5'd1, 3'b000, OP_U_AUIPC), "OP_U_AUIPC",
            ALU_ADD, 1, 1, 0, 0, 3'b000, 1, WB_ALU, 0, 0);

        // --- OP_J: JAL x1, imm ---
        // reg_we=1, wb=PC4, jump=1, alu_src=0, mem=off, branch=0
        check_ctrl(mk_instr(7'd0, 5'd0, 5'd0, 5'd1, 3'b000, OP_J), "OP_J JAL",
            ALU_ADD, 0, 0, 0, 0, 3'b000, 1, WB_PC4, 0, 1);

        // --- default / invalid opcode → all defaults ---
        // alu_op=ALU_ADD, alu_src=0, alu_src_a=0, mem=off, reg_we=0, wb=ALU, branch=0, jump=0
        check_ctrl(mk_instr(7'd0, 5'd0, 5'd0, 5'd0, 3'b000, 7'h7F), "default opcode 0x7F",
            ALU_ADD, 0, 0, 0, 0, 3'b000, 0, WB_ALU, 0, 0);

        check_ctrl(32'h0000_0000, "all-zero instruction",
            ALU_ADD, 0, 0, 0, 0, 3'b000, 0, WB_ALU, 0, 0);

        // -------------------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("CU TB done: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------");
        $finish;
    end
endmodule
