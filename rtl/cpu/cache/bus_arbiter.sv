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
// Module       : bus_arbiter
// Description  : AXI4 Read Arbiter and Write Controller
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-08
// Version      : 1.0
// -----------------------------------------------------------------------------

module bus_arbiter
    import cache_pkg::*;
    import axi_pkg::*;
(
    //system
    input logic clk, rst_n,

    //icache - arbiter read interface
    input logic                     icache_req,
    input logic [ADDR_WIDTH-1:0]    icache_addr,

    output logic                    icache_grant,
    output logic [DATA_WIDTH-1:0]   icache_rdata,
    output logic                    icache_valid,
    output logic                    icache_last,

    //dcache - arbiter read interface
    input logic                     dcache_req,
    input logic [ADDR_WIDTH-1:0]    dcache_addr,

    output logic                    dcache_grant,
    output logic [DATA_WIDTH-1:0]   dcache_rdata,
    output logic                    dcache_valid,
    output logic                    dcache_last,

    //write buffer - arbiter write interface
    input  logic                    arb_wr_req,
    input  logic [ADDR_WIDTH-1:0]   arb_wr_addr,
    input  logic [DATA_WIDTH-1:0]   arb_wr_data,
    input  logic [STRB_WIDTH-1:0]   arb_wr_strb,

    output logic                    arb_wr_done,  

    //AXI4 master - read addr channel
    output logic                    m_axi_arvalid,
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [7:0]              m_axi_arlen,
    output logic [2:0]              m_axi_arsize,
    output logic [1:0]              m_axi_arburst,

    input logic                     m_axi_arready,

    //AXI4 master - read data channel
    input logic                     m_axi_rvalid,
    input logic [DATA_WIDTH-1:0]    m_axi_rdata,
    input logic [1:0]               m_axi_rresp,
    input logic                     m_axi_rlast,

    output logic                    m_axi_rready,
    
    //AXI4 master - write address channel   
    output logic                    m_axi_awvalid,
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [7:0]              m_axi_awlen,
    output logic [2:0]              m_axi_awsize,
    output logic [1:0]              m_axi_awburst,
    
    input logic                     m_axi_awready,

    //AXI4 master - write data channel
    output logic                    m_axi_wvalid,
    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [STRB_WIDTH-1:0]   m_axi_wstrb,
    output logic                    m_axi_wlast,

    input logic                     m_axi_wready,

    //AXI4 master - write response channel
    input logic         m_axi_bvalid,
    input logic [1:0]   m_axi_bresp,

    output logic        m_axi_bready
);
    //READ PATH

    //fixed-priority arbiter 
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_ADDR,
        RD_DATA
    } rd_state_t;

    typedef enum logic {
        RD_OWNER_IC,
        RD_OWNER_DC
    } rd_owner_t;

    rd_state_t rd_state, rd_state_next;
    rd_owner_t rd_owner;

    logic [ADDR_WIDTH-1:0] rd_addr_lat;

    //arbitration
    logic       arb_rd_valid;
    rd_owner_t  arb_rd_winner;

    always_comb begin
        arb_rd_valid    = 1'b0;
        arb_rd_winner   = RD_OWNER_IC;

        if (dcache_req) begin
            arb_rd_valid    = 1'b1;
            arb_rd_winner   = RD_OWNER_DC;
        end else if (icache_req) begin
            arb_rd_valid    = 1'b1;
            arb_rd_winner   = RD_OWNER_IC;
        end
    end

    //read next state fsm
    always_comb begin
        rd_state_next   = rd_state;

        case (rd_state)
            RD_IDLE: begin
                if (arb_rd_valid)
                    rd_state_next   = RD_ADDR;
            end

            RD_ADDR: begin
                if (m_axi_arvalid && m_axi_arready)
                    rd_state_next   = RD_DATA;
            end

            RD_DATA: begin
                if (m_axi_rvalid && m_axi_rlast)
                    rd_state_next   = RD_IDLE;
            end
        endcase
    end

    //read register fsm
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state    <= RD_IDLE;
            rd_owner    <= RD_OWNER_IC;
            rd_addr_lat <= '0;
        end else begin
            rd_state    <= rd_state_next;

            if (rd_state == RD_IDLE && arb_rd_valid) begin
                rd_owner    <= arb_rd_winner;
                
                if (arb_rd_winner == RD_OWNER_IC)
                    rd_addr_lat <= icache_addr;
                else 
                    rd_addr_lat <= dcache_addr;
            end
        end
    end

    //read output
    assign icache_grant = (rd_state == RD_IDLE) && arb_rd_valid && (arb_rd_winner == RD_OWNER_IC);
    assign dcache_grant = (rd_state == RD_IDLE) && arb_rd_valid && (arb_rd_winner == RD_OWNER_DC);

    //AXI4 AR channel: WRAP burst, 4 beats x 4 bytes
    assign m_axi_arvalid = (rd_state == RD_ADDR);
    assign m_axi_araddr  = rd_addr_lat;
    assign m_axi_arlen   = AXI_LEN_4BEAT;
    assign m_axi_arsize  = AXI_SIZE_4B;
    assign m_axi_arburst = AXI_BURST_WRAP;

    //AXI4 R channel
    assign m_axi_rready = (rd_state == RD_DATA);

    //route R data to the cache that owns the channel
    always_comb begin
        icache_rdata = '0;
        icache_valid = 1'b0;
        icache_last  = 1'b0;

        dcache_rdata = '0;
        dcache_valid = 1'b0;
        dcache_last  = 1'b0;

        if (rd_state == RD_DATA) begin
            if (rd_owner == RD_OWNER_IC) begin
                icache_rdata = m_axi_rdata;
                icache_valid = m_axi_rvalid;
                icache_last  = m_axi_rlast;
            end else begin
                dcache_rdata = m_axi_rdata;
                dcache_valid = m_axi_rvalid;
                dcache_last  = m_axi_rlast;
            end
        end
    end

    //WRITE PATH

    typedef enum logic [1:0] {
        WR_IDLE,
        WR_ADDR,
        WR_DATA,
        WR_RESP
    } wr_state_t;

    wr_state_t wr_state, wr_state_next;

    logic [ADDR_WIDTH-1:0]  wr_addr_lat;
    logic [DATA_WIDTH-1:0]  wr_data_lat;
    logic [STRB_WIDTH-1:0]  wr_strb_lat;

    //write next state fsm
    always_comb begin
        wr_state_next   = wr_state;

        case (wr_state)
            WR_IDLE: begin
                if (arb_wr_req)
                    wr_state_next   = WR_ADDR;
            end

            WR_ADDR: begin
                if (m_axi_awvalid && m_axi_awready)
                    wr_state_next   = WR_DATA;
            end

            WR_DATA: begin
                if (m_axi_wvalid && m_axi_wready)
                    wr_state_next   = WR_RESP;
            end

            WR_RESP: begin
                if (m_axi_bvalid && m_axi_bready)
                    wr_state_next   = WR_IDLE;
            end
        endcase
    end

    //write register fsm
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state    <= WR_IDLE;
            wr_addr_lat <= '0;
            wr_data_lat <= '0;
            wr_strb_lat <= '0;
        end else begin
            wr_state    <= wr_state_next;

            if (wr_state == WR_IDLE && arb_wr_req) begin
                wr_addr_lat <= arb_wr_addr;
                wr_data_lat <= arb_wr_data;
                wr_strb_lat <= arb_wr_strb;
            end
        end
    end

    //AXI4 AW channel: single beat write
    assign m_axi_awvalid = (wr_state == WR_ADDR);
    assign m_axi_awaddr  = wr_addr_lat;
    assign m_axi_awlen   = 8'd0;            
    assign m_axi_awsize  = AXI_SIZE_4B;
    assign m_axi_awburst = AXI_BURST_INCR;

    //AXI4 W channel
    assign m_axi_wvalid  = (wr_state == WR_DATA);
    assign m_axi_wdata   = wr_data_lat;
    assign m_axi_wstrb   = wr_strb_lat;
    assign m_axi_wlast   = 1'b1; 

    //AXI4 B channel
    assign m_axi_bready  = (wr_state == WR_RESP);

    //pop trigger write buffer
    assign arb_wr_done = (wr_state == WR_RESP) && m_axi_bvalid;
endmodule
