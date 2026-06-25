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
// Module       : axi_pkg
// Description  : Shared parameters, types, constants for AMBA AXI4 protocol
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-11
// Version      : 1.0
// -----------------------------------------------------------------------------

package axi_pkg;
    //response status
    localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam logic [1:0] AXI_RESP_EXOKAY = 2'b01;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;
    localparam logic [1:0] AXI_RESP_DECERR = 2'b11;
    
    //burst type
    localparam logic [1:0] AXI_BURST_FIXED = 2'b00;
    localparam logic [1:0] AXI_BURST_INCR  = 2'b01;
    localparam logic [1:0] AXI_BURST_WRAP  = 2'b10;
    localparam logic [1:0] AXI_BURST_RSVD  = 2'b11;
    
    //burst size
    localparam logic [2:0] AXI_SIZE_1B   = 3'b000;
    localparam logic [2:0] AXI_SIZE_2B   = 3'b001;
    localparam logic [2:0] AXI_SIZE_4B   = 3'b010;
    localparam logic [2:0] AXI_SIZE_8B   = 3'b011;
    localparam logic [2:0] AXI_SIZE_16B  = 3'b100;
    localparam logic [2:0] AXI_SIZE_32B  = 3'b101;
    localparam logic [2:0] AXI_SIZE_64B  = 3'b110;
    localparam logic [2:0] AXI_SIZE_128B = 3'b111;

    //burst length
    localparam logic [7:0] AXI_LEN_SINGLE = 8'd0; 
    localparam logic [7:0] AXI_LEN_4BEAT  = 8'd3;
    
    //protection attributes
    localparam logic [2:0] AXI_PROT_UNPRIVILEGED = 3'b000;
    localparam logic [2:0] AXI_PROT_PRIVILEGED   = 3'b001;
    localparam logic [2:0] AXI_PROT_SECURE       = 3'b000;
    localparam logic [2:0] AXI_PROT_NONSECURE    = 3'b010;
    localparam logic [2:0] AXI_PROT_DATA         = 3'b000;
    localparam logic [2:0] AXI_PROT_INSTRUCTION  = 3'b100;
    
    //memory attributes
    localparam logic [3:0] AXI_CACHE_DEV_NONBUF          = 4'b0000;
    localparam logic [3:0] AXI_CACHE_DEV_BUF             = 4'b0001;
    localparam logic [3:0] AXI_CACHE_NORM_NONCACHE_NONBUF= 4'b0010;
    localparam logic [3:0] AXI_CACHE_NORM_NONCACHE_BUF   = 4'b0011;
    localparam logic [3:0] AXI_CACHE_WT_NOALLOC          = 4'b0110;
    localparam logic [3:0] AXI_CACHE_WT_READALLOC        = 4'b0110;
    localparam logic [3:0] AXI_CACHE_WT_WRITEALLOC       = 4'b1110;
    localparam logic [3:0] AXI_CACHE_WT_RWALLOC          = 4'b1110;
    localparam logic [3:0] AXI_CACHE_WB_NOALLOC          = 4'b0111;
    localparam logic [3:0] AXI_CACHE_WB_READALLOC        = 4'b0111;
    localparam logic [3:0] AXI_CACHE_WB_WRITEALLOC       = 4'b1111;
    localparam logic [3:0] AXI_CACHE_WB_RWALLOC          = 4'b1111;
endpackage
