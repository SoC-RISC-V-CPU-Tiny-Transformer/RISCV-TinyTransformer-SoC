// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit Processor
// Module       : jal_minimal_tb
// Description  : Test toi gian cho lenh JAL.
//                Chuong trinh:
//                  0x00 addi x5, x0, 100      (sentinel: x5 = 100)
//                  0x04 jal  x1, target       (target=0x14, x1 = 0x08)
//                  0x08 addi x5, x0, 222      (BAD: should be skipped, x5=222 thi sai)
//                  0x0C addi x5, x0, 222      (BAD)
//                  0x10 addi x5, x0, 222      (BAD)
//                  0x14 addi x6, x0, 77       (target: x6 = 77)
//                  0x18 jal  x0, halt         (halt at 0x1C)
//                  halt:
//                  0x1C jal  x0, 0            (j .)
//
//                PASS condition:
//                  - x1  = 0x08  (link addr cua JAL dau)
//                  - x5  = 100   (KHONG bi ghi de boi BAD slots)
//                  - x6  = 77    (target da chay)
//                  - PC dung tai 0x1C
//
//                FAIL signature:
//                  - x5 = 222    -> ghost instruction tu fall-through chay vao WB
//                  - x6 != 77    -> jal khong nhay den target
//                  - x1 sai      -> WB_PC4 mux hong
//
// Author       : NGUYEN TO QUOC VIET (sinh boi Claude)
// Date         : 2026-04-18
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module jal_minimal_tb;
    import cpu_pkg::*;

    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    logic                   if_req;
    logic [ADDR_WIDTH-1:0]  if_pc;
    logic [DATA_WIDTH-1:0]  if_instr;
    logic                   if_icache_ready, if_icache_valid;

    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req, mem_we;
    logic [DATA_WIDTH-1:0]  mem_wdata;
    logic [3:0]             mem_wstrb;
    logic [DATA_WIDTH-1:0]  mem_rdata;
    logic                   mem_dcache_ready, mem_dcache_valid;

    // Instruction ROM (verified by riscv64-unknown-elf-as)
    //   0x00 addi x5, x0, 100   -> 0x06400293
    //   0x04 jal  x1, +0x10     -> 0x010000EF   (target = 0x14)
    //   0x08 addi x5, x0, 222   -> 0x0DE00293   <-- BAD ghost
    //   0x0C addi x5, x0, 222   -> 0x0DE00293   <-- BAD ghost
    //   0x10 addi x5, x0, 222   -> 0x0DE00293   <-- BAD ghost
    //   0x14 addi x6, x0, 77    -> 0x04D00313
    //   0x18 jal  x0, +0x04     -> 0x0040006F   (target = 0x1C)
    //   0x1C jal  x0, 0         -> 0x0000006F   (halt: j .)
    always_comb begin
        case (if_pc[7:2])
            6'h00:   if_instr = 32'h0640_0293;  // addi x5, x0, 100
            6'h01:   if_instr = 32'h0100_00EF;  // jal  x1, +0x10  -> 0x14
            6'h02:   if_instr = 32'h0DE0_0293;  // addi x5, x0, 222 (ghost)
            6'h03:   if_instr = 32'h0DE0_0293;  // addi x5, x0, 222 (ghost)
            6'h04:   if_instr = 32'h0DE0_0293;  // addi x5, x0, 222 (ghost)
            6'h05:   if_instr = 32'h04D0_0313;  // addi x6, x0, 77
            6'h06:   if_instr = 32'h0040_006F;  // jal  x0, +0x04  -> 0x1C
            6'h07:   if_instr = 32'h0000_006F;  // jal  x0, 0       (halt)
            default: if_instr = 32'h0000_0013;  // nop
        endcase
    end
    assign if_icache_ready = 1'b1;
    assign if_icache_valid = 1'b1;
    assign mem_rdata        = 32'h0;
    assign mem_dcache_ready = 1'b1;
    assign mem_dcache_valid = 1'b1;

    riscv_core dut (
        .clk(clk), .rst_n(rst_n),
        .if_req(if_req), .if_pc(if_pc), .if_instr(if_instr),
        .if_icache_ready(if_icache_ready), .if_icache_valid(if_icache_valid),
        .mem_addr(mem_addr), .mem_req(mem_req), .mem_we(mem_we),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .mem_dcache_ready(mem_dcache_ready), .mem_dcache_valid(mem_dcache_valid)
    );

    int cyc;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) cyc <= 0;
        else        cyc <= cyc + 1;
    end

    // Verbose monitor: track JAL through every stage
    always @(posedge clk) if (rst_n) begin
        $display("[c=%02d] IF.pc=%h instr=%h | ID.pc=%h instr=%h jp=%b br=%b | EX.pc=%h jp=%b br=%b rd=%0d wsel=%b | MEM.pc=%h rd=%0d we=%b alu=%h | WB.pc=%h rd=%0d we=%b wsel=%b wdata=%h | bru_mispr=%b bru_taken=%b bru_target=%h bru_corr_pc=%h | mispr_r=%b corr_pc_r=%h",
            cyc,
            dut.if_pc, dut.fcu_instr,
            dut.id_pc, dut.id_instr, dut.id_jump, dut.id_branch,
            dut.ex_pc, dut.ex_jump, dut.ex_branch, dut.ex_rd, dut.ex_wb_sel,
            dut.mem_pc, dut.mem_rd, dut.mem_reg_we, dut.mem_alu_result,
            dut.wb_pc, dut.wb_rd, dut.wb_reg_we, dut.wb_wb_sel, dut.wb_wdata,
            dut.bru_mispredict, dut.bru_actual_taken, dut.bru_actual_target, dut.bru_correct_pc,
            dut.mispredict_r, dut.correct_pc_r);
    end

    // Marker: JAL fires in BRU
    always @(posedge clk) if (rst_n) begin
        if (dut.ex_jump && dut.ex_pc == 32'h04) begin
            $display("  >>> JAL@EX (PC=0x04): target=%h corr_pc=%h mispr=%b (target should be 0x14, corr_pc should be 0x14 if mispredicted)",
                     dut.bru_actual_target, dut.bru_correct_pc, dut.bru_mispredict);
        end
        if (dut.ex_jump && dut.ex_pc == 32'h18) begin
            $display("  >>> JAL@EX (PC=0x18): target=%h corr_pc=%h mispr=%b (target should be 0x1C)",
                     dut.bru_actual_target, dut.bru_correct_pc, dut.bru_mispredict);
        end
        if (dut.ex_jump && dut.ex_pc == 32'h1C) begin
            $display("  >>> JAL halt@EX (PC=0x1C, j .): target=%h mispr=%b (target should be 0x1C)",
                     dut.bru_actual_target, dut.bru_mispredict);
        end
        // GHOST detector: any time wb_pc in 0x08..0x10 with reg_we
        if (dut.wb_reg_we && dut.wb_pc >= 32'h08 && dut.wb_pc <= 32'h10 && dut.wb_rd != 0) begin
            $display("  !!! GHOST WRITE: WB.pc=%h rd=%0d wdata=%h <-- ghost instr from fall-through wrote RF!",
                     dut.wb_pc, dut.wb_rd, dut.wb_wdata);
        end
    end

    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
        repeat (40) @(posedge clk);

        $display("\n========================================");
        $display("FINAL REGISTER STATE:");
        $display("  x1  = %h (expect 0x08 = link addr cua JAL dau)", dut.u_rf.register[1]);
        $display("  x5  = %h (expect 0x64 = 100, KHONG phai 222=0xDE)", dut.u_rf.register[5]);
        $display("  x6  = %h (expect 0x4D = 77)", dut.u_rf.register[6]);
        $display("========================================");

        if (dut.u_rf.register[1] === 32'h0000_0008 &&
            dut.u_rf.register[5] === 32'h0000_0064 &&
            dut.u_rf.register[6] === 32'h0000_004D) begin
            $display(">>> PASS: JAL hoat dong dung <<<");
        end else begin
            $display(">>> FAIL: JAL bug. Phan tich:");
            if (dut.u_rf.register[1] !== 32'h08) $display("    - x1 sai: WB_PC4 mux hong hoac id_ex pipe pc loi");
            if (dut.u_rf.register[5] === 32'h0000_00DE)
                $display("    - x5 = 222: GHOST INSTRUCTION da chay (flush KHONG WORK)");
            if (dut.u_rf.register[6] !== 32'h0000_004D) $display("    - x6 sai: JAL khong dat target dung");
        end

        $finish;
    end
endmodule
