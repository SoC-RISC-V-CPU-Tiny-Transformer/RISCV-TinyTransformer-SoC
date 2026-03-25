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
// Module       : Load Store Unit
// Description  : Translates pipeline mem requests to dcache interface.
//                Generates wstrb for stores, extracts and sign/zero extends
//                rdata for loads.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-18
// Version      : 1.0
// -----------------------------------------------------------------------------

module lsu
    import cpu_pkg::*;
(
    //pipeline interface
    input logic                     mem_req,
    input logic                     mem_we,
    input logic [2:0]               mem_size,   //funct3: [1:0]=size, [2]=unsigned
    input logic [ADDR_WIDTH-1:0]    addr,       //alu_result
    input logic [DATA_WIDTH-1:0]    wdata,      

    output logic [DATA_WIDTH-1:0]   mem_rdata,  
    output logic                    mem_valid,
    output logic                    mem_ready,

    //dcache interface
    output logic [ADDR_WIDTH-1:0]   dc_addr,
    output logic                    dc_req,
    output logic                    dc_we,
    output logic [DATA_WIDTH-1:0]   dc_wdata,
    output logic [3:0]              dc_wstrb,

    input logic [DATA_WIDTH-1:0]    dc_rdata,
    input logic                     dc_valid,
    input logic                     dc_ready
);
    logic [7:0]  byte_data;
    logic [15:0] half_data;

    //dcache request passthrough
    assign dc_addr  = addr;
    assign dc_req   = mem_req;
    assign dc_we    = mem_we;

    //store: wstrb generation 
    always_comb begin
        case (mem_size[1:0])
            2'b00: begin    //byte
                case (addr[1:0])
                    2'b00:  dc_wstrb = 4'b0001;
                    2'b01:  dc_wstrb = 4'b0010;
                    2'b10:  dc_wstrb = 4'b0100;
                    2'b11:  dc_wstrb = 4'b1000;
                endcase
            end

            2'b01: begin    //halfword
                dc_wstrb = addr[1] ? 4'b1100 : 4'b0011;
            end

            2'b10:   dc_wstrb = 4'b1111;    //word

            default: dc_wstrb = 4'b0000;
        endcase
    end

    //store: replicate wdata to all byte lanes, wstrb selects correct bytes
    always_comb begin
        case (mem_size[1:0])
            2'b00:   dc_wdata = {4{wdata[7:0]}};        //byte
            2'b01:   dc_wdata = {2{wdata[15:0]}};       //half
            default: dc_wdata = wdata;                  //word
        endcase
    end

    //load: extract byte/halfword from correct lane based on addr[1:0]
    always_comb begin
        case (addr[1:0])
            2'b00:   byte_data = dc_rdata[7:0];
            2'b01:   byte_data = dc_rdata[15:8];
            2'b10:   byte_data = dc_rdata[23:16];
            2'b11: byte_data = dc_rdata[31:24];
        endcase
    end

    assign half_data = addr[1] ? dc_rdata[31:16] : dc_rdata[15:0];

    //load: sign/zero extend based on mem_size 
    always_comb begin
        case (mem_size)
            3'b000: mem_rdata = {{24{byte_data[7]}},  byte_data};   //LB
            3'b001: mem_rdata = {{16{half_data[15]}}, half_data};   //LH
            3'b010: mem_rdata = dc_rdata;                           //LW
            3'b100: mem_rdata = {24'b0, byte_data};                 //LBU
            3'b101: mem_rdata = {16'b0, half_data};                 //LHU
            default: mem_rdata = dc_rdata;
        endcase
    end

    //status passthrough
    assign mem_valid = dc_valid;
    assign mem_ready = dc_ready;
endmodule
