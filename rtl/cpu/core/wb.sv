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
// Module       : Write Back
// Description  : Selects write-back data from ALU result, memory read data,
//                or pc+4 (JAL/JALR), then drives RF write port
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-25
// Version      : 1.0
// -----------------------------------------------------------------------------

module wb
    import cpu_pkg::*;
(
    //data sources
    input logic [DATA_WIDTH-1:0]    alu_result_i,
    input logic [DATA_WIDTH-1:0]    mem_rdata_i,
    input logic [ADDR_WIDTH-1:0]    pc_i,           

    //wb control
    input logic [1:0]               wb_sel_i,       //WB_ALU or WB_MEM or WB_PC4

    //rf write port
    input logic                     reg_we_i,
    input logic [4:0]               rd_i,

    //rf interface
    output logic [DATA_WIDTH-1:0]   wdata_o,
    output logic                    reg_we_o,
    output logic [4:0]              rd_o
);
    //mux selection
    logic [DATA_WIDTH-1:0] reg_wdata;

    always_comb begin
        case (wb_sel_i)
            WB_ALU:  reg_wdata = alu_result_i;
            WB_MEM:  reg_wdata = mem_rdata_i;
            WB_PC4:  reg_wdata = pc_i + 32'd4;
            default:reg_wdata = '0;
        endcase
    end
    
    //out
    assign rd_o     = rd_i;
    assign reg_we_o = reg_we_i;
    assign wdata_o  = reg_wdata; 
endmodule
