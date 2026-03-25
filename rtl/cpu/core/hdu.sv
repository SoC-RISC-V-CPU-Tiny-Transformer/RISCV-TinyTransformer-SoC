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
// Module       : Hazard Detection Unit
// Description  : Detects load-use and dcache-miss hazards, generates stall/flush
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-25
// Version      : 1.1
// Changes      : Added dcache-miss stall (dcache_stall output).
//                Renamed stall -> load_use_stall for clarity.
// -----------------------------------------------------------------------------

module hdu
    import cpu_pkg::*;
(
    //EX instruction
    input logic         ex_mem_req,
    input logic         ex_mem_we,
    input logic [4:0]   ex_rd,

    //ID instruction
    input logic [4:0]   id_rs1,
    input logic [4:0]   id_rs2,

    //MEM stage dcache status
    input logic         mem_req,
    input logic         mem_valid,

    //load-use: stall IF+ID, flush ID/EX
    output logic        load_use_stall,
    output logic        ex_flush,

    //dcache miss: stall entire pipeline
    output logic        dcache_stall
);
    assign load_use_stall = ex_mem_req && !ex_mem_we && ex_rd != 5'b0
                         && (ex_rd == id_rs1 || ex_rd == id_rs2);

    assign ex_flush       = load_use_stall;

    assign dcache_stall   = mem_req && !mem_valid;
endmodule
