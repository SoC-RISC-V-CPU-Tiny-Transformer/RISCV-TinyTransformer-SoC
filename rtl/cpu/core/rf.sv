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
// Module       : Register File
// Description  : 32 bit 32 registers 
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-16
// Version      : 1.0
// -----------------------------------------------------------------------------

module rf
    import cpu_pkg::*;
(
    //system interface
    input logic clk,
    
    //(read port)
    input logic [DATA_WIDTH-1:0]    instr,

    output logic [DATA_WIDTH-1:0]   rdata1,
    output logic [DATA_WIDTH-1:0]   rdata2,

    //wb (write port) interface
    input logic                     reg_we,
    input logic [4:0]               rd,
    input logic [DATA_WIDTH-1:0]    wdata
);
    //decode
    //logic [6:0] opcode;
    logic [4:0] rs1;
    logic [4:0] rs2;

    //assign opcode   = instr[6:0];
    assign rs1      = instr[19:15];
    assign rs2      = instr[24:20];

    //register files
    logic [DATA_WIDTH-1:0] register [31:0];

    //read
    //forward
    assign rdata1   = (reg_we && rd == rs1 && rd != 5'b0) ? wdata : register[rs1];
    assign rdata2   = (reg_we && rd == rs2 && rd != 5'b0) ? wdata : register[rs2];

    //write
    always_ff @(posedge clk) begin
        //tranh ghi vao $0
        if (reg_we && rd != 5'd0)
            register[rd]    <= wdata;
    end
endmodule
