// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit Processor
// Module       : bypass_fwd_tb
// Description  : Tai dung FULL TEST_RR_SRC12_BYPASS(24) cua rv32ui-p-add.
//                Bao gom: loop body 2 lan + bne kiem tra ket qua + fail/pass
//                sentinel. Bypass icache/dcache: instr ROM combinational.
//
// Memory map (instruction ROM, indexed by if_pc[7:2]):
//   0x00 li   gp, 24
//   0x04 li   x4, 0                       ; loop counter
//   0x08 li   x1, 14                      ; <-- loop_top
//   0x0C li   x2, 11
//   0x10 nop                              ; src2_nops=1
//   0x14 add  x14, x1, x2                 ; expect x14 = 25
//   0x18 addi x4, x4, 1                   ; loop counter ++
//   0x1C li   x5, 2
//   0x20 bne  x4, x5, -0x18 -> 0x08       ; <-- mispredict NT->T iter1, T->NT iter2
//   0x24 li   x7, 25                      ; expected value
//   0x28 bne  x14, x7, +0x18 -> 0x40      ; check x14 == 25
//   0x2C li   x10, 1                      ; PASS sentinel
//   0x30 jal  x0, 0                       ; halt (infinite loop)
//   0x40 li   x10, 254                    ; FAIL sentinel
//   0x44 jal  x0, 0                       ; halt
//
// Pass condition: x10 = 1, x4 = 2, x14 = 25 sau khi PC dung tai 0x30.
//
// Author       : NGUYEN TO QUOC VIET (sinh boi Claude theo yeu cau debug)
// Date         : 2026-04-18
// Version      : 2.0 — full loop + bne forwarding scenario
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module bypass_fwd_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // Clock & reset
    // -------------------------------------------------------------------------
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // Instruction ROM — combinational, luon ready/valid
    // -------------------------------------------------------------------------
    always_comb begin
        case (if_pc[7:2])
            6'h00:   if_instr = 32'h0180_0193;  // li   gp, 24       (addi x3, x0, 24)
            6'h01:   if_instr = 32'h0000_0213;  // li   x4, 0        (addi x4, x0, 0)
            6'h02:   if_instr = 32'h00E0_0093;  // li   x1, 14       (addi x1, x0, 14)   <-- loop_top
            6'h03:   if_instr = 32'h00B0_0113;  // li   x2, 11       (addi x2, x0, 11)
            6'h04:   if_instr = 32'h0000_0013;  // nop
            6'h05:   if_instr = 32'h0020_8733;  // add  x14, x1, x2  <-- UUT
            6'h06:   if_instr = 32'h0012_0213;  // addi x4, x4, 1
            6'h07:   if_instr = 32'h0020_0293;  // li   x5, 2        (addi x5, x0, 2)
            6'h08:   if_instr = 32'hFE52_14E3;  // bne  x4, x5, -0x18  -> PC=0x08 (verified by gas)
            6'h09:   if_instr = 32'h0190_0393;  // li   x7, 25       (addi x7, x0, 25)
            6'h0A:   if_instr = 32'h0077_1C63;  // bne  x14, x7, +0x18 -> PC=0x40 (verified by gas)
            6'h0B:   if_instr = 32'h0010_0513;  // li   x10, 1       PASS sentinel
            6'h0C:   if_instr = 32'h0000_006F;  // jal  x0, 0        halt (j .)
            6'h10:   if_instr = 32'h0FE0_0513;  // li   x10, 254     FAIL sentinel
            6'h11:   if_instr = 32'h0000_006F;  // jal  x0, 0        halt (j .)
            default: if_instr = 32'h0000_0013;  // nop
        endcase
    end
    assign if_icache_ready = 1'b1;
    assign if_icache_valid = 1'b1;

    // Tie-off mem channel
    assign mem_rdata        = 32'h0;
    assign mem_dcache_ready = 1'b1;
    assign mem_dcache_valid = 1'b1;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    riscv_core dut (
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

    // -------------------------------------------------------------------------
    // Cycle counter + per-cycle monitor
    // -------------------------------------------------------------------------
    int cyc;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) cyc <= 0;
        else        cyc <= cyc + 1;
    end

    always @(posedge clk) if (rst_n) begin
        $display("[cyc=%02d] IF.pc=%h | EX.pc=%h rs1=%0d rs2=%0d rd=%0d br=%b jp=%b | MEM.pc=%h rd=%0d we=%b alu=%h | WB.pc=%h rd=%0d we=%b wsel=%b wdata=%h | fa=%b fb=%b | fw_a=%h fw_b=%h | mispr_r=%b",
            cyc,
            dut.if_pc,
            dut.ex_pc, dut.ex_rs1, dut.ex_rs2, dut.ex_rd, dut.ex_branch, dut.ex_jump,
            dut.mem_pc, dut.mem_rd, dut.mem_reg_we, dut.mem_alu_result,
            dut.wb_pc,  dut.wb_rd,  dut.wb_reg_we,  dut.wb_wb_sel, dut.wb_wdata,
            dut.forward_a, dut.forward_b,
            dut.fw_src_a, dut.fw_src_b,
            dut.mispredict_r);
    end

    // -------------------------------------------------------------------------
    // Smoking-gun markers
    // -------------------------------------------------------------------------
    always @(posedge clk) if (rst_n) begin
        // (1) WB-fwd cho add x14, x1, x2 (li x2 dang o WB, add o EX)
        if (dut.ex_pc == 32'h14 && dut.forward_b == 2'b01) begin
            $display("  >>> [add@EX] WB-fwd rs2=x2: fw_src_b=%h (expect 0x0B)",
                     dut.fw_src_b);
        end
        // (2) bne x4, x5 (rs1 forward x4 vua tinh xong, rs2 forward x5 vua li)
        if (dut.ex_pc == 32'h20 && dut.ex_branch) begin
            $display("  >>> [bne@EX PC=0x20] fa=%b fb=%b | fw_a(x4)=%h fw_b(x5)=%h | actual_taken=%b mispredict=%b",
                     dut.forward_a, dut.forward_b,
                     dut.fw_src_a, dut.fw_src_b,
                     dut.bru_actual_taken, dut.bru_mispredict);
        end
        // (3) bne x14, x7 final check
        if (dut.ex_pc == 32'h28 && dut.ex_branch) begin
            $display("  >>> [bne@EX PC=0x28 final-check] fw_a(x14)=%h fw_b(x7)=%h | actual_taken=%b (taken=FAIL!)",
                     dut.fw_src_a, dut.fw_src_b,
                     dut.bru_actual_taken);
        end
        // (4) Bao dong vao FAIL region
        if (dut.if_pc == 32'h40 && !dut.mispredict_r) begin
            $display("  !!! PC entered FAIL region (0x40) at cyc=%0d", cyc);
        end
    end

    // -------------------------------------------------------------------------
    // Halt detector — chay den khi PC dung tai 0x30 (PASS) hoac 0x44 (FAIL)
    // -------------------------------------------------------------------------
    int halt_cyc_at_30, halt_cyc_at_44;
    initial halt_cyc_at_30 = -1;
    initial halt_cyc_at_44 = -1;

    always @(posedge clk) if (rst_n) begin
        if (dut.if_pc == 32'h30 && halt_cyc_at_30 == -1) halt_cyc_at_30 <= cyc;
        if (dut.if_pc == 32'h44 && halt_cyc_at_44 == -1) halt_cyc_at_44 <= cyc;
    end

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;

        // Du cho 2 lan loop body + epilogue (~ 60 cycle voi mispredict penalty)
        repeat (80) @(posedge clk);

        $display("\n========================================");
        $display("FINAL REGISTER STATE:");
        $display("  x1  = %h (expect 0x0E = 14)",  dut.u_rf.register[1]);
        $display("  x2  = %h (expect 0x0B = 11)",  dut.u_rf.register[2]);
        $display("  x3  = %h (expect 0x18 = 24)",  dut.u_rf.register[3]);
        $display("  x4  = %h (expect 0x02 = 2)  <-- loop iter count", dut.u_rf.register[4]);
        $display("  x5  = %h (expect 0x02 = 2)",  dut.u_rf.register[5]);
        $display("  x7  = %h (expect 0x19 = 25)", dut.u_rf.register[7]);
        $display("  x14 = %h (expect 0x19 = 25) <-- UUT result",    dut.u_rf.register[14]);
        $display("  x10 = %h (1=PASS, 0xFE=FAIL)", dut.u_rf.register[10]);
        $display("----------------------------------------");
        $display("  Halted at PC=0x30 cyc=%0d | PC=0x44 cyc=%0d",
                 halt_cyc_at_30, halt_cyc_at_44);
        $display("========================================");

        if (dut.u_rf.register[10] === 32'h0000_0001 &&
            dut.u_rf.register[14] === 32'h0000_0019 &&
            dut.u_rf.register[4]  === 32'h0000_0002) begin
            $display(">>> PASS: forwarding hoat dong dung trong scenario nay <<<");
        end else begin
            $display(">>> FAIL: bug reproduced — trace cycle bne@EX PC=0x20 <<<");
        end

        $finish;
    end

endmodule
