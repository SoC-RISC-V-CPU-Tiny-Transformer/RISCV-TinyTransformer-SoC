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
// Module       : dcache
// Description  : 4KB 2 Way Set-Associative Data Cache
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-08
// Version      : 1.0
// -----------------------------------------------------------------------------

module dcache
    import cache_pkg::*;
(
    //system 
    input logic clk, rst_n,
    
    //lsu - d-cache interface
    input logic [ADDR_WIDTH-1:0] addr,
    input logic mem_req,
    input logic mem_we,

    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb,

    output logic [DATA_WIDTH-1:0] rdata,
    output logic dcache_ready,
    output logic dcache_valid,

    //write buffer - d-cache interface
    output logic wb_push,
    output logic [ADDR_WIDTH-1:0] wb_addr,
    output logic [DATA_WIDTH-1:0] wb_data,
    output logic [STRB_WIDTH-1:0] wb_strb,

    input logic wb_full,
    
    //write buffer forwarding
    output logic [ADDR_WIDTH-1:0] fwd_addr,

    input logic fwd_hit,
    input logic [DATA_WIDTH-1:0] fwd_data,
    input logic [STRB_WIDTH-1:0] fwd_strb,

    //arbiter - d-cache interface
    input logic [DATA_WIDTH-1:0] arb_rdata,
    input logic arb_valid,
    input logic arb_last,
    input logic arb_grant,

    output logic dcache_req,
    output logic [ADDR_WIDTH-1:0] dcache_addr
);
    //address decode
    logic [WORD_SEL_BITS-1:0]   addr_word_sel;
    logic [DC_IDX_BITS-1:0]     addr_idx;
    logic [DC_TAG_BITS-1:0]     addr_tag;

    assign addr_word_sel = addr[WORD_OFF_BITS +: WORD_SEL_BITS];    //3:2
    assign addr_idx      = addr[LINE_OFF_BITS +: DC_IDX_BITS];      //10:4
    assign addr_tag      = addr[ADDR_WIDTH-1  -: DC_TAG_BITS];      //31:11

    //storage (2-way) — 1D flat arrays, index = {set_idx, way_bit}
    //DC_SETS*DC_WAYS = 128*2 = 256 entries, index = {addr_idx, way}
    localparam CACHE_DEPTH = DC_SETS * DC_WAYS;
    localparam LINE_WIDTH  = DATA_WIDTH * WORDS_PER_LINE;
    logic [DC_TAG_BITS-1:0] cache_tag  [CACHE_DEPTH];
    logic [LINE_WIDTH-1:0]  cache_data [CACHE_DEPTH];
    logic [DC_SETS-1:0][DC_WAYS-1:0] cache_valid;
    logic [DC_SETS-1:0] lru;

    //tag check
    logic [DC_WAYS-1:0] way_hit;
    logic cache_hit;
    logic hit_way;  //which way hit
    logic [DATA_WIDTH-1:0] cache_rdata;

    always_comb begin
        for (int w = 0; w < DC_WAYS; w++) begin
            way_hit[w] = cache_valid[addr_idx][w] && (cache_tag[addr_idx * DC_WAYS + w] == addr_tag);
        end

        cache_hit   = |way_hit;
        hit_way     = way_hit[1];   //optimize
        cache_rdata = cache_data[{addr_idx, hit_way}][addr_word_sel*DATA_WIDTH +: DATA_WIDTH];
    end

    //store-to-load forwarding merge
    assign fwd_addr = {addr[ADDR_WIDTH-1:WORD_OFF_BITS], {WORD_OFF_BITS{1'b0}}};
    logic [DATA_WIDTH-1:0] merged_rdata;

    always_comb begin
        for (int b = 0; b < STRB_WIDTH; b++) begin
            if (fwd_hit && fwd_strb[b])
                merged_rdata[b*8 +: 8] = fwd_data[b*8 +: 8];
            else
                merged_rdata[b*8 +: 8] = cache_rdata[b*8 +: 8];
        end
    end

    logic fwd_full_cover;
    assign fwd_full_cover = fwd_hit && (&fwd_strb);

    //refill buffer
    logic [DATA_WIDTH-1:0]      rf_buffer [WORDS_PER_LINE];
    logic [WORDS_PER_LINE-1:0]  rf_valid;
    logic [DC_TAG_BITS-1:0]     rf_tag;
    logic [DC_IDX_BITS-1:0]     rf_idx;
    logic [WORD_SEL_BITS-1:0]   rf_word_sel;

    logic rf_buffer_hit;
    assign rf_buffer_hit = rf_valid[addr_word_sel] && (rf_idx == addr_idx) && (rf_tag == addr_tag);

    //merge refill buffer with WB forwarding
    logic [DATA_WIDTH-1:0] rf_merged_rdata;

    always_comb begin
        for (int b = 0; b < STRB_WIDTH; b++) begin
            if (fwd_hit && fwd_strb[b])
                rf_merged_rdata[b*8 +: 8] = fwd_data[b*8 +: 8];
            else
                rf_merged_rdata[b*8 +: 8] = rf_buffer[addr_word_sel][b*8 +: 8];
        end
    end

    //eviction way selection
    logic evict_way;

    always_comb begin
        if (!cache_valid[rf_idx][0])
            evict_way = 1'b0;
        else if (!cache_valid[rf_idx][1])
            evict_way = 1'b1;
        else
            evict_way = lru[rf_idx];
    end

    //fsm
    typedef enum logic [1:0] {
        IDLE,
        REFILL_REQ,
        REFILL_DATA,
        REFILL_DONE
    } state_t;

    state_t state, next_state;

    //fsm next state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                //only load miss trigger refill
                //write-no-allocate, direct to write buffer, no refill
                if (mem_req && !mem_we && !cache_hit && !fwd_full_cover)
                    next_state = REFILL_REQ;
            end

            REFILL_REQ: begin
                if (arb_grant) 
                    next_state = REFILL_DATA;
            end

            REFILL_DATA: begin
                if (arb_valid && arb_last) 
                    next_state = REFILL_DONE;
            end

            REFILL_DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    //FSM: control registers — only signals that NEED async reset
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            cache_valid <= 'b0;
            rf_valid    <= 'b0;
            lru         <= 'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (mem_req) begin
                        if (!mem_we) begin
                            if (cache_hit)
                                lru[addr_idx] <= ~hit_way;
                            else if (!fwd_full_cover)
                                rf_valid <= '0;
                        end else begin
                            if (cache_hit && !wb_full)
                                lru[addr_idx] <= ~hit_way;
                        end
                    end
                end

                REFILL_DATA: begin
                    if (arb_valid)
                        rf_valid[rf_word_sel] <= 1'b1;
                end

                REFILL_DONE: begin
                    cache_valid[rf_idx][evict_way] <= 1'b1;
                    lru[rf_idx] <= ~evict_way;
                    rf_valid    <= '0;
                end
            endcase
        end
    end

    //FSM: data + address registers — no async reset, allows LUTRAM inference
    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                if (mem_req) begin
                    if (!mem_we && !cache_hit && !fwd_full_cover) begin
                        rf_tag      <= addr_tag;
                        rf_idx      <= addr_idx;
                        rf_word_sel <= addr_word_sel;
                    end
                    if (mem_we && cache_hit && !wb_full) begin
                        for (int b = 0; b < STRB_WIDTH; b++) begin
                            if (wstrb[b])
                                cache_data[{addr_idx, hit_way}][addr_word_sel*DATA_WIDTH + b*8 +: 8] <= wdata[b*8 +: 8];
                        end
                    end
                end
            end

            REFILL_DATA: begin
                if (arb_valid) begin
                    rf_buffer[rf_word_sel] <= arb_rdata;
                    rf_word_sel            <= rf_word_sel + 1'b1;
                end
            end

            REFILL_DONE: begin
                cache_tag[{rf_idx, evict_way}]  <= rf_tag;
                for (int w = 0; w < WORDS_PER_LINE; w++)
                    cache_data[{rf_idx, evict_way}][w*DATA_WIDTH +: DATA_WIDTH] <= rf_buffer[w];
            end
        endcase
    end

    //fsm output logic
    always_comb begin
        rdata           = '0;
        dcache_valid    = 1'b0;
        dcache_ready    = 1'b0;
        
        wb_push         = 1'b0;
        wb_addr         = '0;
        wb_data         = '0;
        wb_strb         = '0;

        case (state)
            IDLE: begin
                if (mem_req) begin
                    //load
                    if (!mem_we) begin
                        //hit
                        if (cache_hit) begin
                            rdata           = merged_rdata;
                            dcache_valid    = 1'b1;
                            dcache_ready    = 1'b1;
                        //miss but have data in write buffer
                        end else if (fwd_full_cover) begin
                            rdata           = fwd_data;
                            dcache_valid    = 1'b1;
                            dcache_ready    = 1'b1;
                        //miss real -> stall 
                        end
                    //store
                    end else begin
                        //push to write buffer
                        if (!wb_full) begin
                            wb_push = 1'b1;
                            wb_addr = {addr[ADDR_WIDTH-1:WORD_OFF_BITS], {WORD_OFF_BITS{1'b0}}};
                            wb_data = wdata;
                            wb_strb = wstrb;
                            dcache_valid = 1'b1;
                            dcache_ready = 1'b1;
                        //write buffer full -> stall
                        end
                    end
                //no request
                end else begin
                    dcache_ready = 1'b1;
                end
            end

            REFILL_REQ: begin
                
            end

            REFILL_DATA: begin
                //cwf
                if (rf_buffer_hit) begin
                    rdata           = rf_merged_rdata;
                    dcache_valid    = 1'b1;
                end

                dcache_ready = 1'b0;    //chua nhan req moi
            end

            REFILL_DONE: begin
                rdata           = rf_merged_rdata;
                dcache_valid    = 1'b1;
                dcache_ready    = 1'b1;
            end
        endcase
    end

    //Bus Arbiter req
    assign dcache_req  = (state == REFILL_REQ);
    assign dcache_addr = {rf_tag, rf_idx, rf_word_sel, {WORD_OFF_BITS{1'b0}}};
endmodule
