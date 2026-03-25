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
// Module       : Fetch Control Unit
// Description  : Read Instr and Control PC 
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-15
// Version      : 1.1
// -----------------------------------------------------------------------------

module fcu
    import cpu_pkg::*;
(   
    //system interface
    input logic clk, rst_n,
    
    //cache_subsystem interface
    input logic [DATA_WIDTH-1:0]    instr_i,
    input logic                     cache_valid,
    input logic                     cache_ready,

    output logic                    if_req,
    output logic [ADDR_WIDTH-1:0]   if_pc,

    //Dynamic Branch Prediction interface
    input logic                     pred_taken,
    input logic [ADDR_WIDTH-1:0]    pred_target,

    //EX-Stage Feedback interface
    input logic                     ex_mispredict,
    input logic [ADDR_WIDTH-1:0]    ex_correct_pc,

    //Hazard Control Unit interface
    input logic                     stall,
    //input logic                     flush,

    //IF_ID Pipeline inteface
    output logic [DATA_WIDTH-1:0]   instr_o,
    output logic [ADDR_WIDTH-1:0]   if_id_pc,
    output logic                    if_id_pred_taken,
    output logic [ADDR_WIDTH-1:0]   if_id_pred_target
);
    //PC Control
    logic [ADDR_WIDTH-1:0] pc_reg;
    logic [ADDR_WIDTH-1:0] next_pc;

    always_comb begin
        if (pred_taken)
            next_pc = pred_target;
        else
            next_pc = pc_reg + 4;
    end

    //PC Update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg  <= PC_RESET_VEC;
        end else begin
            //priority 1: REDIRECT PC
            if (ex_mispredict) 
                pc_reg  <= ex_correct_pc;
            //priority 2: Update normal PC
            //phai stall de khong cap nhat them pc + 4
            //cache_ready: tranh advance PC khi cache dang busy (CWF trong REFILL_DATA)
            else if (!stall && cache_valid && cache_ready)
                pc_reg  <= next_pc;
        end
    end
    
    //output to icache
    assign if_pc  = pc_reg;
    assign if_req = !stall && !ex_mispredict;

    //output to IF_ID Pipeline
    assign instr_o          = instr_i;
    assign if_id_pc         = pc_reg;
    assign if_id_pred_taken  = ex_mispredict ? 1'b0  : pred_taken;
    assign if_id_pred_target = ex_mispredict ? '0    : pred_target;
endmodule
