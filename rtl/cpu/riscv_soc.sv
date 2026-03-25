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
// Project      : Advanced RISC-V 32-bit SoC
// Module       : riscv_soc
// Description  : Top-level SoC wrapper connecting riscv_core and
//                cache_subsystem. Exposes an AXI4 master port to main memory.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-25
// Version      : 1.0
// -----------------------------------------------------------------------------

module riscv_soc
    import cache_pkg::*;
(
    //system
    input  logic                    clk,
    input  logic                    rst_n,

    //fence interface
    input  logic                    fence,
    output logic                    fence_done,

    //axi4 master - read address
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [7:0]              m_axi_arlen,
    output logic [2:0]              m_axi_arsize,
    output logic [1:0]              m_axi_arburst,

    //axi4 master - read data
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,
    input  logic [DATA_WIDTH-1:0]   m_axi_rdata,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rlast,

    //axi4 master - write address
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [7:0]              m_axi_awlen,
    output logic [2:0]              m_axi_awsize,
    output logic [1:0]              m_axi_awburst,

    //axi4 master - write data
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [STRB_WIDTH-1:0]   m_axi_wstrb,
    output logic                    m_axi_wlast,

    //axi4 master - write response
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,
    input  logic [1:0]              m_axi_bresp
);
    //internal wires: riscv_core <-> cache_subsystem
    //if channel
    logic [ADDR_WIDTH-1:0]  if_pc;
    logic                   if_req;
    logic [DATA_WIDTH-1:0]  if_instr;
    logic                   if_icache_ready, if_icache_valid;

    //mem channel
    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req, mem_we;
    logic [DATA_WIDTH-1:0]  mem_wdata, mem_rdata;
    logic [STRB_WIDTH-1:0]  mem_wstrb;
    logic                   mem_dcache_ready, mem_dcache_valid;

    //riscv_core instance
    riscv_core u_riscv_core (
        .clk              (clk),
        .rst_n            (rst_n),
        .if_req           (if_req),
        .if_pc            (if_pc),
        .if_instr         (if_instr),
        .if_icache_ready  (if_icache_ready),
        .if_icache_valid  (if_icache_valid),
        .mem_addr         (mem_addr),
        .mem_req          (mem_req),
        .mem_we           (mem_we),
        .mem_wdata        (mem_wdata),
        .mem_wstrb        (mem_wstrb),
        .mem_rdata        (mem_rdata),
        .mem_dcache_ready (mem_dcache_ready),
        .mem_dcache_valid (mem_dcache_valid)
    );

    //cache_subsystem instance
    cache_subsystem u_cache_subsystem (
        .clk              (clk),
        .rst_n            (rst_n),
        .if_pc            (if_pc),
        .if_req           (if_req),
        .if_instr         (if_instr),
        .if_icache_ready  (if_icache_ready),
        .if_icache_valid  (if_icache_valid),
        .mem_addr         (mem_addr),
        .mem_req          (mem_req),
        .mem_we           (mem_we),
        .mem_wdata        (mem_wdata),
        .mem_wstrb        (mem_wstrb),
        .mem_rdata        (mem_rdata),
        .mem_dcache_ready (mem_dcache_ready),
        .mem_dcache_valid (mem_dcache_valid),
        .fence            (fence),
        .fence_done       (fence_done),
        .m_axi_arvalid    (m_axi_arvalid),
        .m_axi_arready    (m_axi_arready),
        .m_axi_araddr     (m_axi_araddr),
        .m_axi_arlen      (m_axi_arlen),
        .m_axi_arsize     (m_axi_arsize),
        .m_axi_arburst    (m_axi_arburst),
        .m_axi_rvalid     (m_axi_rvalid),
        .m_axi_rready     (m_axi_rready),
        .m_axi_rdata      (m_axi_rdata),
        .m_axi_rresp      (m_axi_rresp),
        .m_axi_rlast      (m_axi_rlast),
        .m_axi_awvalid    (m_axi_awvalid),
        .m_axi_awready    (m_axi_awready),
        .m_axi_awaddr     (m_axi_awaddr),
        .m_axi_awlen      (m_axi_awlen),
        .m_axi_awsize     (m_axi_awsize),
        .m_axi_awburst    (m_axi_awburst),
        .m_axi_wvalid     (m_axi_wvalid),
        .m_axi_wready     (m_axi_wready),
        .m_axi_wdata      (m_axi_wdata),
        .m_axi_wstrb      (m_axi_wstrb),
        .m_axi_wlast      (m_axi_wlast),
        .m_axi_bvalid     (m_axi_bvalid),
        .m_axi_bready     (m_axi_bready),
        .m_axi_bresp      (m_axi_bresp)
    );
endmodule
