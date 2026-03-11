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
// Module       : icache
// Description  : 4KB Direct-Mapped Instruction Cache
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-04
// Version      : 1.0
// -----------------------------------------------------------------------------

module icache 
    import cache_pkg::*;
(
    //system
    input logic clk, rst_n,

    //IF - i-cache interface
    input logic [ADDR_WIDTH-1:0] pc,
    input logic if_req,

    output logic [DATA_WIDTH-1:0] instr,
    output logic icache_ready,
    output logic icache_valid,

    //arbiter - i-cache interface
    input logic [DATA_WIDTH-1:0] arb_rdata,
    input logic arb_valid,
    input logic arb_last,
    input logic arb_grant,

    output logic icache_req,
    output logic [ADDR_WIDTH-1:0] icache_addr
);
    //address decode
    logic [WORD_SEL_BITS-1:0]   pc_word_sel;
    logic [IC_IDX_BITS-1:0]     pc_idx;
    logic [IC_TAG_BITS-1:0]     pc_tag;

    assign pc_word_sel  = pc[WORD_OFF_BITS +: WORD_SEL_BITS];   //3 - 2
    assign pc_idx       = pc[LINE_OFF_BITS +: IC_IDX_BITS];     //11 - 4
    assign pc_tag       = pc[ADDR_WIDTH-1 -: IC_TAG_BITS];      //31 - 12 

    //storage
    logic [IC_TAG_BITS-1:0] cache_tag [IC_SETS];
    logic [DATA_WIDTH-1:0] cache_data [IC_SETS][WORDS_PER_LINE];
    logic [IC_SETS-1:0] cache_valid;    //for simple resest, not large

    //comparator
    logic cache_hit;
    logic [DATA_WIDTH-1:0] hit_data;

    assign cache_hit = cache_valid[pc_idx] && (cache_tag[pc_idx] == pc_tag);
    assign hit_data  = cache_data[pc_idx][pc_word_sel];

    //refill buffer
    logic [DATA_WIDTH-1:0]      rf_buffer [WORDS_PER_LINE];
    logic [WORDS_PER_LINE-1:0]  rf_valid;
    logic [IC_TAG_BITS-1:0]     rf_tag;
    logic [IC_IDX_BITS-1:0]     rf_idx;
    logic [WORD_SEL_BITS-1:0]   rf_word_sel;

    logic rf_buffer_hit;
    assign rf_buffer_hit = rf_valid[pc_word_sel] && (rf_idx == pc_idx) && (rf_tag == pc_tag);

    //fsm
    typedef enum logic [1:0] {
        IDLE,
        REFILL_REQ,
        REFILL_DATA,
        REFILL_DONE
    } state_t;

    state_t state, next_state;

    //FSM: next state logic
    always_comb begin
        //default
        next_state = state;

        case (state)
            IDLE: begin
                if (if_req && !cache_hit) 
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

    //FSM: register state + datapath
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            cache_valid <= '0;
            rf_valid    <= '0;
        end else begin
            state <= next_state;

            case (state) 
                IDLE: begin
                    //neu miss -> latch dia chi miss cho refill
                    if (if_req && !cache_hit) begin
                        rf_tag      <= pc_tag;
                        rf_idx      <= pc_idx;
                        rf_word_sel <= pc_word_sel; //refill tu critical word, khong phai tu 0
                        rf_valid    <= '0;
                    end
                end

                REFILL_REQ: begin

                end


                REFILL_DATA: begin
                    //moi clock ghi 1 word vao refill buffer
                    if (arb_valid) begin
                        rf_buffer[rf_word_sel]  <= arb_rdata;
                        rf_valid[rf_word_sel]   <= 1'b1;

                        rf_word_sel             <= rf_word_sel + 1'b1;  //moi cycle tang len 1, tu wrap ve khi tran bit
                    end
                end

                REFILL_DONE: begin
                    //ghi 1 luc toan bo refill buffer vao SRAM
                    cache_tag[rf_idx]   <= rf_tag;
                    cache_valid[rf_idx] <= 1'b1;

                    for (int w = 0; w < WORDS_PER_LINE; w++)
                        cache_data[rf_idx][w] <= rf_buffer[w];

                    rf_valid    <= '0;    //clear refill buffer
                end
            endcase
        end
    end

    //FSM: output logic
    always_comb begin
        instr           = '0;
        icache_valid    = 1'b0;
        icache_ready    = 1'b0;

        case (state)
            IDLE: begin
                icache_ready = 1'b1;
                
                //neu hit
                if (if_req && cache_hit) begin
                    instr           = hit_data;
                    icache_valid    = 1'b1;
                end
            end

            REFILL_REQ: begin
                
            end

            REFILL_DATA: begin
                if (rf_buffer_hit) begin
                    instr       = rf_buffer[pc_word_sel];
                    icache_valid= 1'b1;
                end

                icache_ready    = 1'b0; //khong nhan pc moi
            end

            REFILL_DONE: begin
                instr       = rf_buffer[pc_word_sel];
                icache_valid= 1'b1;
                icache_ready= 1'b1; //nhan pc moi
            end
        endcase
    end

    //Bus Arbiter
    assign icache_req   = (state == REFILL_REQ);
    assign icache_addr  = {rf_tag, rf_idx, rf_word_sel, {WORD_OFF_BITS{1'b0}}};
endmodule
