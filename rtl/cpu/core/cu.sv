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
// Module       : Control Unit
// Description  : Generate control signals base on instruction 
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-16
// Version      : 1.0
// -----------------------------------------------------------------------------

module cu
    import cpu_pkg::*;
(
    input logic [DATA_WIDTH-1:0]    instr,

    //EX stage
    output logic [3:0]              alu_op,
    output logic                    alu_src,    //0=rs2,  1=imm
    output logic                    alu_src_a,  //0=rs1,  1=PC  (AUIPC)

    //MEM stage
    output logic                    mem_req,
    output logic                    mem_we,
    output logic [2:0]              mem_size,   //funct3 passthrough

    //WB stage
    output logic                    reg_we,
    output logic [1:0]              wb_sel,     //WB_ALU / WB_MEM / WB_PC4

    //branch/jump
    output logic                    branch,
    output logic                    jump
);
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    always_comb begin
        //defaults
        alu_op    = ALU_ADD;
        alu_src   = 1'b0;
        alu_src_a = 1'b0;
        mem_req   = 1'b0;
        mem_we    = 1'b0;
        mem_size  = funct3;
        reg_we    = 1'b0;
        wb_sel    = WB_ALU;
        branch    = 1'b0;
        jump      = 1'b0;

        case (opcode)
            OP_R: begin
                reg_we  = 1'b1;
            end

            OP_I_ALU: begin
                reg_we  = 1'b1;
                alu_src = 1'b1;
            end

            OP_I_LOAD: begin 
                reg_we  = 1'b1; 
                alu_src = 1'b1;
                mem_req = 1'b1; 
                wb_sel  = WB_MEM;                     
            end

            OP_I_JALR: begin 
                reg_we  = 1'b1; 
                alu_src = 1'b1;
                wb_sel  = WB_PC4; 
                jump    = 1'b1;                            
            end

            OP_S: begin
                alu_src = 1'b1; 
                mem_req = 1'b1; 
                mem_we  = 1'b1;          
            end

            OP_B: begin
                branch  = 1'b1;     
            end

            OP_J: begin
                reg_we  = 1'b1; 
                wb_sel  = WB_PC4; 
                jump    = 1'b1;
            end

            OP_U_LUI: begin 
                reg_we  = 1'b1; 
                alu_src = 1'b1;        
            end

            OP_U_AUIPC: begin 
                reg_we  = 1'b1; 
                alu_src = 1'b1; 
                alu_src_a = 1'b1;       
            end

            default: ;
        endcase

        //only OP_R and OP_I_ALU need deep decode
        case (opcode)
            OP_R: begin
                case ({funct7[5], funct3})
                    4'b0_000: alu_op = ALU_ADD;
                    4'b1_000: alu_op = ALU_SUB;
                    4'b0_001: alu_op = ALU_SLL;
                    4'b0_010: alu_op = ALU_SLT;
                    4'b0_011: alu_op = ALU_SLTU;
                    4'b0_100: alu_op = ALU_XOR;
                    4'b0_101: alu_op = ALU_SRL;
                    4'b1_101: alu_op = ALU_SRA;
                    4'b0_110: alu_op = ALU_OR;
                    4'b0_111: alu_op = ALU_AND;
                    default:  alu_op = ALU_ADD;
                endcase
            end

            OP_U_LUI:   alu_op = ALU_PASS_B;  //rd = imm, ignore rs1
            
            OP_I_ALU: begin
                case (funct3)
                    3'b000: alu_op = ALU_ADD;   //addi
                    3'b001: alu_op = ALU_SLL;   //slli
                    3'b010: alu_op = ALU_SLT;   //slti
                    3'b011: alu_op = ALU_SLTU;  //sltu
                    3'b100: alu_op = ALU_XOR;   //xori
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;    //ori
                    3'b111: alu_op = ALU_AND;   //andi
                endcase
            end

            default:    alu_op = ALU_ADD;
        endcase
    end
endmodule
