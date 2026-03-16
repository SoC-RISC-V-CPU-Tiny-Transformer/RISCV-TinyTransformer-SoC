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
// Module       : ID/EX Pipeline Register
// Description  :
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-16
// Version      : 1.0
// -----------------------------------------------------------------------------

module id_ex_pipeline
    import cpu_pkg::*;
(
    //system interface
    input logic clk, rst_n,

    //hdu interface
    input logic     stall,
    input logic     flush,

    //id interface
    input logic [3:0]               alu_op_i,
    input logic                     alu_src_i,
    input logic                     alu_src_a_i,
    input logic [1:0]               wb_sel_i,
    input logic                     reg_we_i,
    input logic                     mem_req_i,
    input logic                     mem_we_i,
    input logic [2:0]               mem_size_i,
    input logic                     jump_i,
    input logic                     branch_i,

    input logic [DATA_WIDTH-1:0]    rdata1_i,
    input logic [DATA_WIDTH-1:0]    rdata2_i,
    input logic [DATA_WIDTH-1:0]    imm_i,

    input logic [ADDR_WIDTH-1:0]    pc_i,
    input logic [4:0]               rd_i,
    input logic                     pred_taken_i,

    //ex interface
    output logic [3:0]              alu_op_o,
    output logic                    alu_src_o,
    output logic                    alu_src_a_o,
    output logic [1:0]              wb_sel_o,
    output logic                    reg_we_o,
    output logic                    mem_req_o,
    output logic                    mem_we_o,
    output logic [2:0]              mem_size_o,
    output logic                    jump_o,
    output logic                    branch_o,

    output logic [DATA_WIDTH-1:0]   rdata1_o,
    output logic [DATA_WIDTH-1:0]   rdata2_o,
    output logic [DATA_WIDTH-1:0]   imm_o,

    output logic [ADDR_WIDTH-1:0]   pc_o,
    output logic [4:0]              rd_o,
    output logic                    pred_taken_o
);
    //pipeline register
    logic [3:0]             alu_op;
    logic                   alu_src;
    logic                   alu_src_a;
    logic [1:0]             wb_sel;
    logic                   reg_we;
    logic                   mem_req;
    logic                   mem_we;
    logic [2:0]             mem_size;
    logic                   jump;
    logic                   branch;

    logic [DATA_WIDTH-1:0]  rdata1;
    logic [DATA_WIDTH-1:0]  rdata2;
    logic [DATA_WIDTH-1:0]  imm;

    logic [ADDR_WIDTH-1:0]  pc;
    logic [4:0]             rd;
    logic                   pred_taken;

    //update pipeline register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_op      <= '0;
            alu_src     <= 1'b0;
            alu_src_a   <= 1'b0;
            wb_sel      <= '0;
            reg_we      <= 1'b0;
            mem_req     <= 1'b0;
            mem_we      <= 1'b0;
            mem_size    <= '0;
            jump        <= 1'b0;
            branch      <= 1'b0;
            rdata1      <= '0;
            rdata2      <= '0;
            imm         <= '0;
            pc          <= '0;
            rd          <= '0;
            pred_taken  <= 1'b0;
        end else begin
            if (flush) begin
                alu_op      <= '0;
                alu_src     <= 1'b0;
                alu_src_a   <= 1'b0;
                wb_sel      <= '0;
                reg_we      <= 1'b0;
                mem_req     <= 1'b0;
                mem_we      <= 1'b0;
                mem_size    <= '0;
                jump        <= 1'b0;
                branch      <= 1'b0;
                rdata1      <= '0;
                rdata2      <= '0;
                imm         <= '0;
                pc          <= '0;
                rd          <= '0;
                pred_taken  <= 1'b0;
            end else if (stall) begin
                alu_op      <= alu_op;
                alu_src     <= alu_src;
                alu_src_a   <= alu_src_a;
                wb_sel      <= wb_sel;
                reg_we      <= reg_we;
                mem_req     <= mem_req;
                mem_we      <= mem_we;
                mem_size    <= mem_size;
                jump        <= jump;
                branch      <= branch;
                rdata1      <= rdata1;
                rdata2      <= rdata2;
                imm         <= imm;
                pc          <= pc;
                rd          <= rd;
                pred_taken  <= pred_taken;
            end else begin
                alu_op      <= alu_op_i;
                alu_src     <= alu_src_i;
                alu_src_a   <= alu_src_a_i;
                wb_sel      <= wb_sel_i;
                reg_we      <= reg_we_i;
                mem_req     <= mem_req_i;
                mem_we      <= mem_we_i;
                mem_size    <= mem_size_i;
                jump        <= jump_i;
                branch      <= branch_i;
                rdata1      <= rdata1_i;
                rdata2      <= rdata2_i;
                imm         <= imm_i;
                pc          <= pc_i;
                rd          <= rd_i;
                pred_taken  <= pred_taken_i;
            end
        end
    end

    assign alu_op_o     = alu_op;
    assign alu_src_o    = alu_src;
    assign alu_src_a_o  = alu_src_a;
    assign wb_sel_o     = wb_sel;
    assign reg_we_o     = reg_we;
    assign mem_req_o    = mem_req;
    assign mem_we_o     = mem_we;
    assign mem_size_o   = mem_size;
    assign jump_o       = jump;
    assign branch_o     = branch;
    assign rdata1_o     = rdata1;
    assign rdata2_o     = rdata2;
    assign imm_o        = imm;
    assign pc_o         = pc;
    assign rd_o         = rd;
    assign pred_taken_o = pred_taken;
endmodule
