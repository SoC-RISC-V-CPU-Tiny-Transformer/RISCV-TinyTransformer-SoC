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
// Module       : riscv_pkg
// Description  : Shared parameters, types, constants for cpu core
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-15
// Version      : 1.0
// -----------------------------------------------------------------------------

package cpu_pkg;
    //base parameters
    localparam DATA_WIDTH   = 32; 
    localparam ADDR_WIDTH   = 32;

    //nop instr (addi x0, x0, 0) for flush
    localparam NOP_INSTR = 32'h0000_0013; 

    //pc reset vector
    localparam PC_RESET_VEC = 32'h0000_0000;
 
    //Dynamic Branch Predictor (2-bit BHT + BTB)
    localparam BP_ENTRIES   = 1024;
    localparam BP_IDX_BITS  = $clog2(BP_ENTRIES);
    localparam BTB_TAG_BITS = ADDR_WIDTH - BP_IDX_BITS - 2;

    //saturating counter
    localparam PRED_BITS    = 2;

    localparam STRONGLY_NT  = 2'b00;
    localparam WEAKLY_NT    = 2'b01;
    localparam WEAKLY_T     = 2'b10;
    localparam STRONGLY_T   = 2'b11;

    //ALU operations
    localparam ALU_ADD    = 4'd0;
    localparam ALU_SUB    = 4'd1;
    localparam ALU_SLL    = 4'd2;
    localparam ALU_SLT    = 4'd3;
    localparam ALU_SLTU   = 4'd4;
    localparam ALU_XOR    = 4'd5;
    localparam ALU_SRL    = 4'd6;
    localparam ALU_SRA    = 4'd7;
    localparam ALU_OR     = 4'd8;
    localparam ALU_AND    = 4'd9;
    localparam ALU_PASS_B = 4'd10;  //pass imm through (LUI)

    //WB select
    localparam WB_ALU  = 2'b00;
    localparam WB_MEM  = 2'b01;
    localparam WB_PC4  = 2'b10;     //JAL, JALR: rd = PC+4

    //OPCODE
    localparam OP_R         = 7'b0110011;

    localparam OP_I_ALU     = 7'b0010011;
    localparam OP_I_LOAD    = 7'b0000011;
    localparam OP_I_JALR    = 7'b1100111;

    localparam OP_S         = 7'b0100011;

    localparam OP_B         = 7'b1100011;
    
    localparam OP_U_LUI     = 7'b0110111;
    localparam OP_U_AUIPC   = 7'b0010111;
    
    localparam OP_J         = 7'b1101111;
endpackage
