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
// Module       : riscv_core
// Description  : Top-level wrapper for the 5-stage pipeline RISC-V CPU Core.
//                Mispredict feedback (BRU→FCU) is registered 1 cycle to cut
//                the 14-level combinational path across the full pipeline,
//                enabling 100MHz+ timing closure on xc7z020.
//                Trade-off: branch mispredict penalty 2→3 cycles.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-26
// Version      : 1.1
// Changes      : Registered bru_mispredict/bru_correct_pc (mispredict_r,
//                correct_pc_r) to fix timing critical path EX→IF feedback.
//                Added ex_mem_flush = mispredict_r to flush extra wrong
//                instruction that enters EX during the extra latency cycle.
// -----------------------------------------------------------------------------

module riscv_core
    import cpu_pkg::*;
(
    //system
    input  logic                    clk,
    input  logic                    rst_n,

    //if interface
    output logic                    if_req,
    output logic [ADDR_WIDTH-1:0]   if_pc,
    input  logic [DATA_WIDTH-1:0]   if_instr,
    input  logic                    if_icache_ready,
    input  logic                    if_icache_valid,

    //mem interface
    output logic [ADDR_WIDTH-1:0]   mem_addr,
    output logic                    mem_req,
    output logic                    mem_we,
    output logic [DATA_WIDTH-1:0]   mem_wdata,
    output logic [3:0]              mem_wstrb,
    input  logic [DATA_WIDTH-1:0]   mem_rdata,
    input  logic                    mem_dcache_ready,
    input  logic                    mem_dcache_valid,

    //refill abandon - registered mispredict to icache
    output logic                    flush_refill_o
);

    //internal wires
    //hazard control
    logic                   load_use_stall, dcache_stall, ex_flush;
    logic                   fcu_stall, if_id_stall, id_ex_stall, ex_mem_stall, mem_wb_stall;
    logic                   if_id_flush, id_ex_flush, ex_mem_flush, mem_wb_flush;

    //if stage
    logic                   if_pred_taken;
    logic [ADDR_WIDTH-1:0]  if_pred_target;
    logic [DATA_WIDTH-1:0]  fcu_instr;
    logic [ADDR_WIDTH-1:0]  fcu_if_id_pc;
    logic                   fcu_if_id_pred_taken;
    logic [ADDR_WIDTH-1:0]  fcu_if_id_pred_target;

    //id stage
    logic [ADDR_WIDTH-1:0]  id_pc;
    logic [DATA_WIDTH-1:0]  id_instr;
    logic                   id_pred_taken;
    logic [ADDR_WIDTH-1:0]  id_pred_target;
    logic [4:0]             id_rs1, id_rs2, id_rd;
    logic [3:0]             id_alu_op;
    logic                   id_alu_src, id_alu_src_a;
    logic                   id_mem_req, id_mem_we;
    logic [2:0]             id_mem_size;
    logic                   id_reg_we;
    logic [1:0]             id_wb_sel;
    logic                   id_jump, id_branch;
    logic [DATA_WIDTH-1:0]  id_rdata1, id_rdata2, id_imm;

    //ex stage
    logic [ADDR_WIDTH-1:0]  ex_pc;
    logic [3:0]             ex_alu_op;
    logic                   ex_alu_src, ex_alu_src_a;
    logic                   ex_mem_req, ex_mem_we;
    logic [2:0]             ex_mem_size;
    logic                   ex_reg_we;
    logic [1:0]             ex_wb_sel;
    logic                   ex_jump, ex_branch;
    logic [DATA_WIDTH-1:0]  ex_rdata1, ex_rdata2, ex_imm;
    logic [4:0]             ex_rs1, ex_rs2, ex_rd;
    logic                   ex_pred_taken;
    logic [ADDR_WIDTH-1:0]  ex_pred_target;
    
    logic [DATA_WIDTH-1:0]  fw_src_a, fw_src_b;
    logic [DATA_WIDTH-1:0]  alu_src_a_val, alu_src_b_val;
    logic [DATA_WIDTH-1:0]  ex_alu_result;
    
    logic                   bru_update_en, bru_actual_taken, bru_mispredict;
    logic [ADDR_WIDTH-1:0]  bru_actual_target, bru_correct_pc;
    logic [1:0]             forward_a, forward_b;

    //registered mispredict feedback — cuts long combinational path EX→IF
    logic                   mispredict_r;
    logic [ADDR_WIDTH-1:0]  correct_pc_r;

    //mem stage
    logic [ADDR_WIDTH-1:0]  mem_pc;
    logic [DATA_WIDTH-1:0]  mem_alu_result, mem_rdata2;
    logic                   mem_req_ex, mem_we_ex, mem_reg_we;
    logic [2:0]             mem_size;
    logic [1:0]             mem_wb_sel;
    logic [4:0]             mem_rd;
    
    logic [DATA_WIDTH-1:0]  mem_rdata_ext;
    logic                   mem_valid_out, mem_ready_out;

    //wb stage — mem_wb_pipeline outputs
    logic [ADDR_WIDTH-1:0]  wb_pc;
    logic [DATA_WIDTH-1:0]  wb_mem_rdata, wb_alu_result;
    logic                   mwb_reg_we;    //intermediate: mem_wb → wb module
    logic [1:0]             wb_wb_sel;
    logic [4:0]             mwb_rd;        //intermediate: mem_wb → wb module
    //wb module outputs (drive RF)
    logic                   wb_reg_we;
    logic [4:0]             wb_rd;
    logic [DATA_WIDTH-1:0]  wb_wdata;

    //hazard control logic
    assign fcu_stall    = dcache_stall | load_use_stall;
    assign if_id_stall  = dcache_stall | load_use_stall;
    assign id_ex_stall  = dcache_stall;
    assign ex_mem_stall = dcache_stall;
    assign mem_wb_stall = dcache_stall;

    //CWF + if_id_flush now inside FCU — removed from here
    assign id_ex_flush  = mispredict_r | ex_flush;
    assign ex_mem_flush = mispredict_r;   //extra flush: wrong instr already in EX
    assign mem_wb_flush = 1'b0;

    //expose registered mispredict to cache_subsystem
    assign flush_refill_o = mispredict_r;

    //register mispredict 1 cycle: cuts 14-level combinational feedback path
    //penalty: 2→3 cycles on mispredict, but timing budget restored
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mispredict_r <= 1'b0;
            correct_pc_r <= '0;
        end else begin
            mispredict_r <= bru_mispredict && !mispredict_r;
            correct_pc_r <= bru_correct_pc;
        end
    end

    //instruction decode
    assign id_rs1 = id_instr[19:15];
    assign id_rs2 = id_instr[24:20];
    assign id_rd  = id_instr[11:7];

    //hdu instance
    hdu u_hdu (
        .ex_mem_req     (ex_mem_req),
        .ex_mem_we      (ex_mem_we),
        .ex_rd          (ex_rd),
        .id_rs1         (id_rs1),
        .id_rs2         (id_rs2),
        .mem_req        (mem_req_ex),
        .mem_valid      (mem_valid_out),
        .load_use_stall (load_use_stall),
        .ex_flush       (ex_flush),
        .dcache_stall   (dcache_stall)
    );

    //fcu instance
    fcu u_fcu (
        .clk              (clk),
        .rst_n            (rst_n),
        .instr_i          (if_instr),
        .cache_valid      (if_icache_valid),
        .cache_ready      (if_icache_ready),
        .if_req           (if_req),
        .if_pc            (if_pc),
        .pred_taken       (if_pred_taken),
        .pred_target      (if_pred_target),
        .ex_mispredict    (mispredict_r),
        .ex_correct_pc    (correct_pc_r),
        .stall            (fcu_stall),
        .instr_o          (fcu_instr),
        .if_id_pc         (fcu_if_id_pc),
        .if_id_pred_taken (fcu_if_id_pred_taken),
        .if_id_pred_target(fcu_if_id_pred_target),
        .if_id_flush      (if_id_flush)
    );

    //dbp instance
    dbp u_dbp (
        .clk              (clk),
        .rst_n            (rst_n),
        .if_pc            (if_pc),
        .pred_taken       (if_pred_taken),
        .pred_target      (if_pred_target),
        .ex_update_en     (bru_update_en),
        .ex_pc            (ex_pc),
        .ex_actual_taken  (bru_actual_taken),
        .ex_actual_target (bru_actual_target)
    );

    //if_id_pipeline instance
    if_id_pipeline u_if_id (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (if_id_stall),
        .flush            (if_id_flush),
        .if_pc_i          (fcu_if_id_pc),
        .if_instr_i       (fcu_instr),
        .if_pred_taken_i  (fcu_if_id_pred_taken),
        .if_pred_target_i (fcu_if_id_pred_target),
        .id_pc_o          (id_pc),
        .id_instr_o       (id_instr),
        .id_pred_taken_o  (id_pred_taken),
        .id_pred_target_o (id_pred_target)
    );

    //cu instance
    cu u_cu (
        .instr            (id_instr),
        .alu_op           (id_alu_op),
        .alu_src          (id_alu_src),
        .alu_src_a        (id_alu_src_a),
        .mem_req          (id_mem_req),
        .mem_we           (id_mem_we),
        .mem_size         (id_mem_size),
        .reg_we           (id_reg_we),
        .wb_sel           (id_wb_sel),
        .branch           (id_branch),
        .jump             (id_jump)
    );

    //rf instance
    rf u_rf (
        .clk              (clk),
        .instr            (id_instr),
        .rdata1           (id_rdata1),
        .rdata2           (id_rdata2),
        .reg_we           (wb_reg_we),
        .rd               (wb_rd),
        .wdata            (wb_wdata)
    );

    //immgen instance
    immgen u_immgen (
        .instr            (id_instr),
        .imm              (id_imm)
    );

    //id_ex_pipeline instance
    id_ex_pipeline u_id_ex (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (id_ex_stall),
        .flush            (id_ex_flush),
        .alu_op_i         (id_alu_op),
        .alu_src_i        (id_alu_src),
        .alu_src_a_i      (id_alu_src_a),
        .wb_sel_i         (id_wb_sel),
        .reg_we_i         (id_reg_we),
        .mem_req_i        (id_mem_req),
        .mem_we_i         (id_mem_we),
        .mem_size_i       (id_mem_size),
        .jump_i           (id_jump),
        .branch_i         (id_branch),
        .rdata1_i         (id_rdata1),
        .rdata2_i         (id_rdata2),
        .imm_i            (id_imm),
        .pc_i             (id_pc),
        .rs1_i            (id_rs1),
        .rs2_i            (id_rs2),
        .rd_i             (id_rd),
        .pred_taken_i     (id_pred_taken),
        .pred_target_i    (id_pred_target),
        .alu_op_o         (ex_alu_op),
        .alu_src_o        (ex_alu_src),
        .alu_src_a_o      (ex_alu_src_a),
        .wb_sel_o         (ex_wb_sel),
        .reg_we_o         (ex_reg_we),
        .mem_req_o        (ex_mem_req),
        .mem_we_o         (ex_mem_we),
        .mem_size_o       (ex_mem_size),
        .jump_o           (ex_jump),
        .branch_o         (ex_branch),
        .rdata1_o         (ex_rdata1),
        .rdata2_o         (ex_rdata2),
        .imm_o            (ex_imm),
        .pc_o             (ex_pc),
        .rs1_o            (ex_rs1),
        .rs2_o            (ex_rs2),
        .rd_o             (ex_rd),
        .pred_taken_o     (ex_pred_taken),
        .pred_target_o    (ex_pred_target)
    );

    //fu instance
    fu u_fu (
        .ex_rs1           (ex_rs1),
        .ex_rs2           (ex_rs2),
        .mem_rd           (mem_rd),
        .mem_reg_we       (mem_reg_we),
        .wb_rd            (wb_rd),
        .wb_reg_we        (wb_reg_we),
        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

    //forwarding muxes
    logic [DATA_WIDTH-1:0] mem_fwd_val;
    assign mem_fwd_val  = (mem_wb_sel == WB_PC4) ? (mem_pc + 32'd4) : mem_alu_result;

    assign fw_src_a = (forward_a == 2'b10) ? mem_fwd_val : 
                      (forward_a == 2'b01) ? wb_wdata : ex_rdata1;

    assign fw_src_b = (forward_b == 2'b10) ? mem_fwd_val : 
                      (forward_b == 2'b01) ? wb_wdata : ex_rdata2;

    //alu operand muxes
    assign alu_src_a_val = ex_alu_src_a ? ex_pc  : fw_src_a;
    assign alu_src_b_val = ex_alu_src   ? ex_imm : fw_src_b;

    //alu instance
    alu u_alu (
        .alu_op           (ex_alu_op),
        .src_a            (alu_src_a_val),
        .src_b            (alu_src_b_val),
        .result           (ex_alu_result)
    );

    //bru instance
    bru u_bru (
        .branch           (ex_branch),
        .jump             (ex_jump),
        .alu_src          (ex_alu_src), 
        .funct3           (ex_mem_size),
        .src_a            (fw_src_a),
        .src_b            (fw_src_b),
        .imm              (ex_imm),
        .pc               (ex_pc),
        .pred_taken       (ex_pred_taken),
        .pred_target      (ex_pred_target),
        .ex_update_en     (bru_update_en),
        .ex_actual_taken  (bru_actual_taken),
        .ex_actual_target (bru_actual_target),
        .ex_mispredict    (bru_mispredict),
        .ex_correct_pc    (bru_correct_pc)
    );

    //ex_mem_pipeline instance
    ex_mem_pipeline u_ex_mem (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (ex_mem_stall),
        .flush            (ex_mem_flush),
        .alu_result_i     (ex_alu_result),
        .rdata2_i         (fw_src_b),
        .pc_i             (ex_pc),
        .mem_req_i        (ex_mem_req),
        .mem_we_i         (ex_mem_we),
        .mem_size_i       (ex_mem_size),
        .reg_we_i         (ex_reg_we),
        .wb_sel_i         (ex_wb_sel),
        .rd_i             (ex_rd),
        .alu_result_o     (mem_alu_result),
        .rdata2_o         (mem_rdata2),
        .pc_o             (mem_pc),
        .mem_req_o        (mem_req_ex),
        .mem_we_o         (mem_we_ex),
        .mem_size_o       (mem_size),
        .reg_we_o         (mem_reg_we),
        .wb_sel_o         (mem_wb_sel),
        .rd_o             (mem_rd)
    );

    //lsu instance
    lsu u_lsu (
        .mem_req          (mem_req_ex),
        .mem_we           (mem_we_ex),
        .mem_size         (mem_size),
        .addr             (mem_alu_result),
        .wdata            (mem_rdata2),
        .mem_rdata        (mem_rdata_ext),
        .mem_valid        (mem_valid_out),
        .mem_ready        (mem_ready_out),
        .dc_addr          (mem_addr),
        .dc_req           (mem_req),
        .dc_we            (mem_we),
        .dc_wdata         (mem_wdata),
        .dc_wstrb         (mem_wstrb),
        .dc_rdata         (mem_rdata),
        .dc_valid         (mem_dcache_valid),
        .dc_ready         (mem_dcache_ready)
    );

    //mem_wb_pipeline instance
    mem_wb_pipeline u_mem_wb (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (mem_wb_stall),
        .flush            (mem_wb_flush),
        .mem_rdata_i      (mem_rdata_ext),
        .alu_result_i     (mem_alu_result),
        .pc_i             (mem_pc),
        .reg_we_i         (mem_reg_we),
        .wb_sel_i         (mem_wb_sel),
        .rd_i             (mem_rd),
        .mem_rdata_o      (wb_mem_rdata),
        .alu_result_o     (wb_alu_result),
        .pc_o             (wb_pc),
        .reg_we_o         (mwb_reg_we),
        .wb_sel_o         (wb_wb_sel),
        .rd_o             (mwb_rd)
    );

    //wb instance
    wb u_wb (
        .alu_result_i     (wb_alu_result),
        .mem_rdata_i      (wb_mem_rdata),
        .pc_i             (wb_pc),
        .wb_sel_i         (wb_wb_sel),
        .reg_we_i         (mwb_reg_we),
        .rd_i             (mwb_rd),
        .wdata_o          (wb_wdata),
        .reg_we_o         (wb_reg_we),
        .rd_o             (wb_rd)
    );

endmodule
