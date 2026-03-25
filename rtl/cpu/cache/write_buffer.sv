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
// Module       : write_buffer
// Description  : 4-Entry FIFO Write Buffer with Store-to-Load Forwarding
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-10
// Version      : 1.0
// -----------------------------------------------------------------------------

module write_buffer
    import cache_pkg::*;
(
    //system
    input logic clk, rst_n,

    //dcache - write buffer interface
    input logic                     push,
    input logic [ADDR_WIDTH-1:0]    push_addr,
    input logic [DATA_WIDTH-1:0]    push_data,
    input logic [STRB_WIDTH-1:0]    push_strb,

    output logic                    wb_full,

    //store-to-load forwarding
    input logic [ADDR_WIDTH-1:0]    fwd_addr,

    output logic                    fwd_hit,
    output logic [DATA_WIDTH-1:0]   fwd_data,
    output logic [STRB_WIDTH-1:0]   fwd_strb,

    //fence support
    input logic     fence,
    
    output logic    fence_done,

    //arbiter - write buffer interface
    output logic                    wb_req,
    output logic [ADDR_WIDTH-1:0]   wb_addr,
    output logic [DATA_WIDTH-1:0]   wb_data,
    output logic [STRB_WIDTH-1:0]   wb_strb,

    input logic                     arb_wr_done
);
    //FIFO storage
    logic [WB_DEPTH-1:0] entry_valid;   //4 entry, small -> use packed
    logic [ADDR_WIDTH-1:0] entry_addr [WB_DEPTH];
    logic [DATA_WIDTH-1:0] entry_data [WB_DEPTH];
    logic [STRB_WIDTH-1:0] entry_strb [WB_DEPTH];
    
    //pointer
    //NOTE: head and tail has 1 more bit, the MSB is for recognize overlap 
    logic [WB_PTR_BITS:0] head, tail; 
    logic [WB_PTR_BITS-1:0] head_idx, tail_idx;

    assign head_idx = head[WB_PTR_BITS-1:0];
    assign tail_idx = tail[WB_PTR_BITS-1:0];

    logic ptr_idx_eq;
    assign ptr_idx_eq = (head_idx == tail_idx);

    logic empty;
    assign empty = ptr_idx_eq && (head[WB_PTR_BITS] == tail[WB_PTR_BITS]);
    assign wb_full = ptr_idx_eq && (head[WB_PTR_BITS] != tail[WB_PTR_BITS]);

    //FIFO control: head/tail/valid with async reset
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head        <= '0;
            tail        <= '0;
            entry_valid <= '0;
        end else begin
            if (push && !wb_full) begin
                entry_valid[tail_idx] <= 1'b1;
                tail <= tail + 1'b1;
            end
            if (arb_wr_done && !empty) begin
                entry_valid[head_idx] <= 1'b0;
                head <= head + 1'b1;
            end
        end
    end

    //FIFO data storage: no async reset, allows DRAM inference
    always_ff @(posedge clk) begin
        if (push && !wb_full) begin
            entry_addr[tail_idx] <= push_addr;
            entry_data[tail_idx] <= push_data;
            entry_strb[tail_idx] <= push_strb;
        end
    end

    //store-to-load forwarding  
    logic [STRB_WIDTH-1:0] byte_covered;

    always_comb begin
        fwd_hit      = 1'b0;
        fwd_data     = '0;
        fwd_strb     = '0;
        byte_covered = '0;

        for (int i = 0; i < WB_DEPTH; i++) begin
            logic [WB_PTR_BITS-1:0] idx;
            //scan from newest to oldest
            idx = tail_idx - 1'b1 - WB_PTR_BITS'(i);

            if (entry_valid[idx] && (entry_addr[idx] == fwd_addr)) begin
                fwd_hit = 1'b1;

                for (int b = 0; b < STRB_WIDTH; b++) begin
                    if (entry_strb[idx][b] && !byte_covered[b]) begin
                        fwd_data[b*8 +: 8] = entry_data[idx][b*8 +: 8];
                        fwd_strb[b]        = 1'b1;
                        byte_covered[b]    = 1'b1;
                    end
                end
            end
        end
    end

    //fence support
    assign fence_done = fence && empty;

    //write drain (pop)
    assign wb_req   = !empty;
    assign wb_addr  = entry_addr[head_idx];
    assign wb_data  = entry_data[head_idx];
    assign wb_strb  = entry_strb[head_idx];
endmodule
