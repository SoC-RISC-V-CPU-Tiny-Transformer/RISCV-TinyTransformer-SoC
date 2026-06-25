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
// Module       : forwarding unit
// Description  : Detects data hazards and generates forwarding mux select signals
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-17
// Version      : 1.0
// -----------------------------------------------------------------------------

module fu
    import cpu_pkg::*;
(
    //ex stage (register dang duoc dung)
    input logic [4:0]   ex_rs1,
    input logic [4:0]   ex_rs2,

    //mem stage (ai dang o mem)
    input logic [4:0]   mem_rd,
    input logic         mem_reg_we,

    //wb stage (ai dang o wb)
    input logic [4:0]   wb_rd,
    input logic         wb_reg_we,

    //forward signals
    output logic [1:0]  forward_a,
    output logic [1:0]  forward_b
);
    // 2'b00 = no forward 
    // 2'b01 = MEM/WB
    // 2'b10 = EX/MEM 
    always_comb begin
        //forward_a
        if (mem_reg_we && mem_rd != 5'b0 && ex_rs1 == mem_rd)
            forward_a = 2'b10;
        else if (wb_reg_we && wb_rd != 5'b0 && ex_rs1 == wb_rd)
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        //forward_b
        if (mem_reg_we && mem_rd != 5'b0 && ex_rs2 == mem_rd)
            forward_b = 2'b10;
        else if (wb_reg_we && wb_rd != 5'b0 && ex_rs2 == wb_rd)
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end
endmodule
