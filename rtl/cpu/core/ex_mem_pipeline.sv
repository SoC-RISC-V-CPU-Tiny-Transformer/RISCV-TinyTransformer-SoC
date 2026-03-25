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
// Module       : EX/MEM Pipeline Register
// Description  : 
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-18
// Version      : 1.0
// -----------------------------------------------------------------------------

module ex_mem_pipeline
    import cpu_pkg::*;
(
    //system interface
    input logic clk, rst_n,

    //hazard control
    input logic     stall,
    input logic     flush,

    //ex interface
    input logic [DATA_WIDTH-1:0]    alu_result_i,   //mem addr or alu result
    input logic [DATA_WIDTH-1:0]    rdata2_i,       //store data (forwarded rs2)
    input logic [ADDR_WIDTH-1:0]    pc_i,           //for pc+4 at WB (JAL/JALR)

    //mem stage
    input logic                     mem_req_i,
    input logic                     mem_we_i,
    input logic [2:0]               mem_size_i,

    //wb stage
    input logic                     reg_we_i,
    input logic [1:0]               wb_sel_i,
    input logic [4:0]               rd_i,

    //mem interface
    output logic [DATA_WIDTH-1:0]   alu_result_o,
    output logic [DATA_WIDTH-1:0]   rdata2_o,
    output logic [ADDR_WIDTH-1:0]   pc_o,

    output logic                    mem_req_o,
    output logic                    mem_we_o,
    output logic [2:0]              mem_size_o,

    output logic                    reg_we_o,
    output logic [1:0]              wb_sel_o,
    output logic [4:0]              rd_o
);
    //pipeline registers
    logic [DATA_WIDTH-1:0]  alu_result;
    logic [DATA_WIDTH-1:0]  rdata2;
    logic [ADDR_WIDTH-1:0]  pc;

    logic                   mem_req;
    logic                   mem_we;
    logic [2:0]             mem_size;

    logic                   reg_we;
    logic [1:0]             wb_sel;
    logic [4:0]             rd;

    //update pipeline register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result  <= '0;
            rdata2      <= '0;
            pc          <= '0;
            mem_req     <= 1'b0;
            mem_we      <= 1'b0;
            mem_size    <= '0;
            reg_we      <= 1'b0;
            wb_sel      <= '0;
            rd          <= '0;
        end else begin
            if (flush) begin
                alu_result  <= '0;
                rdata2      <= '0;
                pc          <= '0;
                mem_req     <= 1'b0;
                mem_we      <= 1'b0;
                mem_size    <= '0;
                reg_we      <= 1'b0;
                wb_sel      <= '0;
                rd          <= '0;
            end else if (stall) begin
                alu_result  <= alu_result;
                rdata2      <= rdata2;
                pc          <= pc;
                mem_req     <= mem_req;
                mem_we      <= mem_we;
                mem_size    <= mem_size;
                reg_we      <= reg_we;
                wb_sel      <= wb_sel;
                rd          <= rd;
            end else begin
                alu_result  <= alu_result_i;
                rdata2      <= rdata2_i;
                pc          <= pc_i;
                mem_req     <= mem_req_i;
                mem_we      <= mem_we_i;
                mem_size    <= mem_size_i;
                reg_we      <= reg_we_i;
                wb_sel      <= wb_sel_i;
                rd          <= rd_i;
            end
        end
    end

    assign alu_result_o = alu_result;
    assign rdata2_o     = rdata2;
    assign pc_o         = pc;
    assign mem_req_o    = mem_req;
    assign mem_we_o     = mem_we;
    assign mem_size_o   = mem_size;
    assign reg_we_o     = reg_we;
    assign wb_sel_o     = wb_sel;
    assign rd_o         = rd;
endmodule
