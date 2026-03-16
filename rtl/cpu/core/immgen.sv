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
// Module       : Imm gen
// Description  : Generate immediate base on different instruction type
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-16
// Version      : 1.0
// -----------------------------------------------------------------------------

module immgen
    import cpu_pkg::*;
(
    input logic [DATA_WIDTH-1:0]    instr,
    output logic [DATA_WIDTH-1:0]   imm
);  
    //instruction type
    logic [6:0] opcode;
    assign opcode = instr[6:0];

    //concat and extend imm from different opcode
    always_comb begin
        case (opcode)
            OP_R: begin
                imm = '0;
            end

            OP_I_ALU, OP_I_LOAD, OP_I_JALR: begin
                imm = {{20{instr[31]}} , instr[31:20]};
            end

            OP_S: begin
                imm = {{20{instr[31]}} , instr[31:25], instr[11:7]};
            end

            OP_B: begin
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            end

            OP_U_LUI, OP_U_AUIPC: begin
                imm = {instr[31:12], 12'b0};
            end

            OP_J: begin
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            end

            default:
                imm = '0;
        endcase
    end 
endmodule
