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
// Module       : MEM/WB Pipeline Register
// Description  : 
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-25
// Version      : 1.0
// -----------------------------------------------------------------------------

module mem_wb_pipeline
    import cpu_pkg::*;
(
    //system interface
    input logic clk, rst_n,

    //hazard control
    input logic     stall,
    input logic     flush,

    //mem interface
    input logic [DATA_WIDTH-1:0]    mem_rdata_i,    //load data (extracted + extended)
    input logic [DATA_WIDTH-1:0]    alu_result_i,   //alu result for WB_ALU
    input logic [ADDR_WIDTH-1:0]    pc_i,           //for pc+4 (JAL/JALR)

    //wb stage
    input logic                     reg_we_i,
    input logic [1:0]               wb_sel_i,
    input logic [4:0]               rd_i,

    //wb interface
    output logic [DATA_WIDTH-1:0]   mem_rdata_o,
    output logic [DATA_WIDTH-1:0]   alu_result_o,
    output logic [ADDR_WIDTH-1:0]   pc_o,

    output logic                    reg_we_o,
    output logic [1:0]              wb_sel_o,
    output logic [4:0]              rd_o
);
    //pipeline registers
    logic [DATA_WIDTH-1:0]  mem_rdata;
    logic [DATA_WIDTH-1:0]  alu_result;
    logic [ADDR_WIDTH-1:0]  pc;

    logic                   reg_we;
    logic [1:0]             wb_sel;
    logic [4:0]             rd;

    //update pipeline register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_rdata   <= '0;
            alu_result  <= '0;
            pc          <= '0;
            reg_we      <= 1'b0;
            wb_sel      <= '0;
            rd          <= '0;
        end else begin
            if (flush) begin
                mem_rdata   <= '0;
                alu_result  <= '0;
                pc          <= '0;
                reg_we      <= 1'b0;
                wb_sel      <= '0;
                rd          <= '0;
            end else if (stall) begin
                mem_rdata   <= mem_rdata;
                alu_result  <= alu_result;
                pc          <= pc;
                reg_we      <= reg_we;
                wb_sel      <= wb_sel;
                rd          <= rd;
            end else begin
                mem_rdata   <= mem_rdata_i;
                alu_result  <= alu_result_i;
                pc          <= pc_i;
                reg_we      <= reg_we_i;
                wb_sel      <= wb_sel_i;
                rd          <= rd_i;
            end
        end
    end

    assign mem_rdata_o  = mem_rdata;
    assign alu_result_o = alu_result;
    assign pc_o         = pc;
    assign reg_we_o     = reg_we;
    assign wb_sel_o     = wb_sel;
    assign rd_o         = rd;
endmodule
