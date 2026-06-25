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
// Module       : alu
// Description  : Executes RV32I arithmetic, logic, shift, and compare operations
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-17
// Version      : 1.0
// -----------------------------------------------------------------------------

module alu
    import cpu_pkg::*;
(
    input logic [3:0]   alu_op,
    input logic [DATA_WIDTH-1:0]    src_a,
    input logic [DATA_WIDTH-1:0]    src_b,

    output logic [DATA_WIDTH-1:0]   result
);
    //ahrithmetic
    always_comb begin
        case (alu_op) 
            ALU_ADD:    result = src_a + src_b;
            ALU_SUB:    result = src_a - src_b;
            ALU_SLL:    result = src_a << src_b[4:0];   //shift left logical
            ALU_SLT:    result = $signed(src_a) < $signed(src_b) ? 32'd1 : 32'd0;   //signed compare
            ALU_SLTU:   result = src_a < src_b ? 32'd1 : 32'd0; //unsigned compare
            ALU_XOR:    result = src_a ^ src_b;
            ALU_SRL:    result = src_a >> src_b[4:0];   //shift right logical
            ALU_SRA:    result = $signed(src_a) >>> src_b[4:0]; //shift right arithmetic
            ALU_OR:     result = src_a | src_b;
            ALU_AND:    result = src_a & src_b;
            ALU_PASS_B: result = src_b; 

            default:    result = '0;
        endcase
    end
endmodule
