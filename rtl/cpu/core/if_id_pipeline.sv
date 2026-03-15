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
// Module       : IF/ID Pipeline Register
// Description  : 
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-15
// Version      : 1.0
// -----------------------------------------------------------------------------

module if_id_pipeline
    import cpu_pkg::*;
(   
    //system interface
    input logic clk, rst_n,

    //if interface
    input logic [ADDR_WIDTH-1:0]    if_pc_i,
    input logic [DATA_WIDTH-1:0]    if_instr_i,
    input logic                     if_pred_taken_i,

    //id interface
    output logic [ADDR_WIDTH-1:0]   id_pc_o,
    output logic [DATA_WIDTH-1:0]   id_instr_o,
    output logic                    id_pred_taken_o,

    //hdu interface
    input logic                     stall,
    input logic                     flush
);  
    //pipeline register
    logic [ADDR_WIDTH-1:0]  pc;
    logic [DATA_WIDTH-1:0]  instr;
    logic                   pred_taken;
    
    //update pipeline register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc          <= '0;
            instr       <= NOP_INSTR;
            pred_taken  <= 1'b0;
        end else begin
            //priority: flush > stall > update
            if (flush) begin
                pc          <= '0;
                instr       <= NOP_INSTR;
                pred_taken  <= 1'b0;
            end else if (stall) begin
                pc          <= pc;
                instr       <= instr;
                pred_taken  <= pred_taken;
            end else begin
                pc          <= if_pc_i;
                instr       <= if_instr_i;
                pred_taken  <= if_pred_taken_i;
            end
        end
    end

    assign id_pc_o          = pc;
    assign id_instr_o       = instr;
    assign id_pred_taken_o  = pred_taken;
endmodule
