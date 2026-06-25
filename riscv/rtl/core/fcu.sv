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
// Version      : 1.3
// Changes v1.2 : optimize by remove redundant guard, documenting
// Changes v1.3 : migrate cwf_consumed + if_id_flush from riscv_core.sv
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
    output logic [ADDR_WIDTH-1:0]   if_id_pred_target,
    output logic                    if_id_flush         //to if_id_pipeline.flush
);
    //PC Control
    logic [ADDR_WIDTH-1:0] pc_reg;
    logic [ADDR_WIDTH-1:0] next_pc;
    
    //NOTE: next_pc = pc tiep theo, hoac la pc duoc du doan, hoac la pc + 4
    /*Neu dat ex_correct_pc o day (redirect path) -> next_pc bi gate boi nhieu tin hieu trong do co STALL -> neu cung luc vua STALL
    vua REDIRECT -> STALL win, PC khong REDIRECT -> WRONG!*/
    always_comb begin
        if (pred_taken)
            next_pc = pred_target;
        else
            next_pc = pc_reg + 4;
    end
    
    //1 cycle delay cho redirect
    //cycle sau redirect flush=0 nhung icache REFILL DONE tra ve rf_buffer KHONG CHECK TAG -> WRONG-PATH instruction
    logic ignore_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ignore_valid    <= 1'b0;
        else
            ignore_valid    <= ex_mispredict;
    end

    //PC Update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg  <= PC_RESET_VEC;
        end else begin
            //PRIORITY 1: REDIRECT OC
            if (ex_mispredict) 
                pc_reg  <= ex_correct_pc;
            //PRIORITY 2: NEXT PC
            /*stall: pipeline dang stall, neu co fetch cung khong con khong gian de execute 
              cache_valid: instr co y nghia
              cache_ready: CWF GUARD -> I-Cache tra ve cache_valid tu luc critical-word duoc tra ve (co the chua fully cache line va
              dang refill trong background) -> khong duoc advance PC
              ignore_valid: cycle truoc la redirect, data cua icache dang bi dirty -> wait 1 cycle
            */
            else if (!stall && cache_valid && cache_ready && !ignore_valid)
                pc_reg  <= next_pc;
        end
    end
    
    //output to icache
    assign if_pc  = pc_reg;
    assign if_req = !stall && !ex_mispredict;   //!stall de save power | !ex_mispredict = PC sai -> req lenh sai -> waste cycle for wrong path refill

    //output to IF_ID Pipeline
    assign instr_o              = (/*ex_mispredict ||*/ ignore_valid) ? NOP_INSTR : instr_i; //guard wrong-path instruction from cache
    assign if_id_pc             = pc_reg;

    assign if_id_pred_taken     = /*ex_mispredict ? 1'b0  :*/ ignore_valid ? 1'b0   : pred_taken;
    assign if_id_pred_target    = /*ex_mispredict ? '0    :*/ ignore_valid ? '0     : pred_target;

    //cwf_consumed: CWF instr da duoc IF/ID capture
    //set: valid=1, ready=0, !stall -> capture 1st cycle
    //clear: ready=1 (refill done) or mispredict (redirect, discard)
    //prevent duplicate: CWF instr chi latch vao IF/ID dung 1 lan
    logic cwf_consumed;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cwf_consumed <= 1'b0;
        else if (cache_ready || ex_mispredict)
            cwf_consumed <= 1'b0;
        else if (cache_valid && !cache_ready && !stall)
            cwf_consumed <= 1'b1;
    end

    //if_id_flush truth table
    //mispredict=1                -> flush (redirect)
    //valid=0, cwf=0, !stall      -> flush (miss, NOP)
    //valid=1, cwf=0, !stall      -> no flush (hit / CWF 1st)
    //valid=1, cwf=1, !stall      -> flush (prevent duplicate CWF)
    //stall=1                     -> no flush (stall wins)
    assign if_id_flush = ex_mispredict | ((!cache_valid || cwf_consumed) && !stall);
endmodule
