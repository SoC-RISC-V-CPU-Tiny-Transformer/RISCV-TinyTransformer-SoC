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
// Module       : Dynamic Branch Predictor
// Description  : Predict taken/not-taken and target for branch instr 
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-15
// Version      : 1.0
// -----------------------------------------------------------------------------

module dbp
    import cpu_pkg::*;
(
    //system interface
    input logic clk, rst_n,
    
    //if interface
    input logic [ADDR_WIDTH-1:0]    if_pc,

    output logic                    pred_taken,
    output logic [ADDR_WIDTH-1:0]   pred_target,

    //ex interface
    input logic                     ex_update_en,
    input logic [ADDR_WIDTH-1:0]    ex_pc,          //this pc from if -> id -> ex
    input logic                     ex_actual_taken,
    input logic [ADDR_WIDTH-1:0]    ex_actual_target
);
    //BHT and BTB Storage
    logic [PRED_BITS-1:0]       bht         [BP_ENTRIES];

    logic [ADDR_WIDTH-1:0]      btb_target  [BP_ENTRIES];
    logic [BTB_TAG_BITS-1:0]    btb_tag     [BP_ENTRIES];
    logic [BP_ENTRIES-1:0]      btb_valid;  //like cache, small 

    //if read
    logic [BP_IDX_BITS-1:0] if_pc_idx;
    logic [BTB_TAG_BITS-1:0] if_pc_tag;

    assign if_pc_idx = if_pc[11:2];
    assign if_pc_tag = if_pc[31:12];

    logic btb_hit;
    assign btb_hit = btb_valid[if_pc_idx] && (btb_tag[if_pc_idx] == if_pc_tag);

    assign pred_taken  = btb_hit && (bht[if_pc_idx] >= 2);
    assign pred_target = btb_hit ? btb_target[if_pc_idx] : '0;

    //ex write
    logic [BP_IDX_BITS-1:0] ex_pc_idx;
    logic [BTB_TAG_BITS-1:0] ex_pc_tag;

    assign ex_pc_idx = ex_pc[11:2];
    assign ex_pc_tag = ex_pc[31:12];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < BP_ENTRIES; i++) 
                bht[i]  <= WEAKLY_NT; 

            btb_valid   <= '0;
        end else begin
            //neu la lenh branch
            if (ex_update_en) begin
                //BHT update
                //saturate. not wrap
                if (ex_actual_taken) begin
                    if (bht[ex_pc_idx] != STRONGLY_T)
                        bht[ex_pc_idx]  <= bht[ex_pc_idx] + 1;
                end else begin
                    if (bht[ex_pc_idx] != STRONGLY_NT)
                        bht[ex_pc_idx]  <= bht[ex_pc_idx] - 1;
                end

                //BTB update
                if (ex_actual_taken) begin
                    btb_valid[ex_pc_idx]    <= 1'b1;
                    btb_target[ex_pc_idx]   <= ex_actual_target;
                    btb_tag[ex_pc_idx]      <= ex_pc_tag;
                end
            end
        end
    end
endmodule
