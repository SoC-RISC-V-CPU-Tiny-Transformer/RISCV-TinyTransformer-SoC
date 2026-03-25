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
// Module       : Branch Resolution Unit
// Description  : Evaluates branch/jump outcome, detects misprediction,
//                generates redirect PC and DBP update signals
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-18
// Version      : 1.0
// -----------------------------------------------------------------------------

module bru
    import cpu_pkg::*;
(
    //instruction class
    input logic         branch,
    input logic         jump,
    input logic         alu_src,    //0=JAL (pc+imm), 1=JALR (rs1+imm)
    input logic [2:0]   funct3,     //branch condition type

    //operands (post-forwarding)
    input logic [DATA_WIDTH-1:0]    src_a,  //rs1
    input logic [DATA_WIDTH-1:0]    src_b,  //rs2
    input logic [DATA_WIDTH-1:0]    imm,

    input logic [ADDR_WIDTH-1:0]    pc,

    //prediction from DBP 
    input logic                     pred_taken,
    input logic [ADDR_WIDTH-1:0]    pred_target,

    //DBP update interface 
    output logic                    ex_update_en,
    output logic                    ex_actual_taken,
    output logic [ADDR_WIDTH-1:0]   ex_actual_target,

    //pipeline redirect 
    output logic                    ex_mispredict,
    output logic [ADDR_WIDTH-1:0]   ex_correct_pc
);
    logic branch_cond;

    //branch conditions
    always_comb begin
        case (funct3)
            3'b000: branch_cond = (src_a == src_b);                           // BEQ
            3'b001: branch_cond = (src_a != src_b);                           // BNE
            3'b100: branch_cond = ($signed(src_a) <  $signed(src_b));         // BLT
            3'b101: branch_cond = ($signed(src_a) >= $signed(src_b));         // BGE
            3'b110: branch_cond = (src_a <  src_b);                           // BLTU
            3'b111: branch_cond = (src_a >= src_b);                           // BGEU
            default: branch_cond = 1'b0;
        endcase
    end

    //jump is always taken; branch depends on condition
    assign ex_actual_taken = (branch && branch_cond) || jump;

    //JALR: clear LSB per spec; JAL/branch: PC-relative
    assign ex_actual_target = (jump && alu_src) ? ((src_a + imm) & ~32'h1)
                                                : (pc + imm);

    //mispredict: wrong taken bit OR correct taken but wrong target
    assign ex_mispredict = (ex_actual_taken != pred_taken) ||
                           (ex_actual_taken && (ex_actual_target != pred_target));

    //redirect PC: if not taken, sequential fetch resumes at pc+4
    assign ex_correct_pc = ex_actual_taken ? ex_actual_target : (pc + 32'd4);

    //enable DBP write-back on any branch or jump instruction
    assign ex_update_en  = branch || jump;
endmodule
