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
// Module       : cache_pkg
// Description  : Shared parameters, types, constants for cache subsystem
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-04
// Version      : 1.0
// -----------------------------------------------------------------------------

package cache_pkg;
    //global parameters
    localparam ADDR_WIDTH       = 32;
    localparam DATA_WIDTH       = 32;
    localparam STRB_WIDTH       = DATA_WIDTH / 8;
    localparam LINE_BYTES       = 16;
    localparam WORDS_PER_LINE    = LINE_BYTES / (DATA_WIDTH / 8);
    localparam WORD_OFF_BITS    = $clog2(DATA_WIDTH / 8);
    localparam LINE_OFF_BITS    = $clog2(LINE_BYTES);
    localparam WORD_SEL_BITS    = $clog2(WORDS_PER_LINE);

    //I-Cache parameters
    localparam IC_SIZE_BYTES    = 4096;
    localparam IC_WAYS          = 1;
    localparam IC_SETS          = IC_SIZE_BYTES / (LINE_BYTES / IC_WAYS);
    localparam IC_IDX_BITS      = $clog2(IC_SETS);
    localparam IC_TAG_BITS      = ADDR_WIDTH - IC_IDX_BITS - LINE_OFF_BITS;

    //D-Cache parameters
    localparam DC_SIZE_BYTES    = 4096;
    localparam DC_WAYS          = 2;
    localparam DC_SETS          = DC_SIZE_BYTES / (LINE_BYTES * DC_WAYS);
    localparam DC_IDX_BITS      = $clog2(DC_SETS);
    localparam DC_TAG_BITS      = ADDR_WIDTH - DC_IDX_BITS - LINE_OFF_BITS;

    //Write-Buffer parameters
    localparam WB_DEPTH         = 4;
    localparam WB_PTR_BITS      = $clog2(WB_DEPTH);
endpackage
