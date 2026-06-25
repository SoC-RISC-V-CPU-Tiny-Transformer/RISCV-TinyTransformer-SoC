// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit Processor
// Module       : jal_prologue_tb
// Description  : Replicate byte-by-byte rv32ui-p-jal.elf prologue + test_2 + test_3
//                nhung bypass hoan toan icache/dcache (ROM combinational,
//                mini tohost-memory comb).
//
//                Muc dich: isolate giua hai gia thuyet con lai sau khi bien
//                 (1) immgen, (2) build/.mem, (3) instruction support
//                da bi loai tru.
//
//                Gia thuyet con lai:
//                  - H1: bug o icache/axi memory model (burst refill, tag check)
//                  - H2: bug o core (rd decode sai, ghost write tu mispredict_r)
//
//                Ket qua mong doi:
//                  - Neu PASS (tohost=1)   -> H1 dung, core sach, bug o cache
//                  - Neu FAIL (tohost=3)   -> H2 dung, co repro nho de soi waveform
//                  - Neu tohost khac       -> corruption moi, them clue
//
// Memory map:
//   ROM 0x000..0x08F: copy y ELF cua rv32ui-p-jal (34 instruction)
//   0x090..    : nop (j .)
//   Store den 0x1000 -> capture vao tohost_val (mini data mem)
//   Load tu  0x1000 -> tra ve tohost_val
//
// Author       : NGUYEN TO QUOC VIET (sinh boi Claude - final move)
// Date         : 2026-04-18
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module jal_prologue_tb;
    import cpu_pkg::*;

    // -------------------------------------------------------------------------
    // Clock / reset
    // -------------------------------------------------------------------------
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

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
    // Instruction ROM — copy y byte tu rv32ui-p-jal.elf
    //   Index by if_pc[7:2] (256 byte region = 64 word, du cho 0x00..0x88)
    // -------------------------------------------------------------------------
    always_comb begin
        case (if_pc[7:2])
            // _start
            6'h00:   if_instr = 32'h0000_F137;  // lui  sp, 0xf
            6'h01:   if_instr = 32'h0000_0E13;  // li   t3, 0
            // test_2
            6'h02:   if_instr = 32'h0020_0E13;  // li   t3, 2       <- TESTNUM=2
            6'h03:   if_instr = 32'h0000_0093;  // li   ra, 0
            6'h04:   if_instr = 32'h0100_026F;  // jal  tp, 0x20
            // linkaddr_2 (should be skipped)
            6'h05:   if_instr = 32'h0000_0013;  // nop
            6'h06:   if_instr = 32'h0000_0013;  // nop
            6'h07:   if_instr = 32'h0400_006F;  // j    fail (0x5C)
            // target_2
            6'h08:   if_instr = 32'h0000_0117;  // auipc sp, 0
            6'h09:   if_instr = 32'hFF41_0113;  // addi sp, sp, -12 -> sp=0x14
            6'h0A:   if_instr = 32'h0241_1A63;  // bne  sp, tp, fail  (0x14 == 0x14 -> NOT taken)
            // test_3
            6'h0B:   if_instr = 32'h0030_0E13;  // li   t3, 3       <- TESTNUM=3
            6'h0C:   if_instr = 32'h0010_0093;  // li   ra, 1
            6'h0D:   if_instr = 32'h0140_006F;  // j    0x48
            // 4 GHOST addi (skipped by j above)
            6'h0E:   if_instr = 32'h0010_8093;  // addi ra, ra, 1
            6'h0F:   if_instr = 32'h0010_8093;  // addi ra, ra, 1
            6'h10:   if_instr = 32'h0010_8093;  // addi ra, ra, 1
            6'h11:   if_instr = 32'h0010_8093;  // addi ra, ra, 1
            // target of j
            6'h12:   if_instr = 32'h0010_8093;  // addi ra, ra, 1 -> ra=2
            6'h13:   if_instr = 32'h0010_8093;  // addi ra, ra, 1 -> ra=3
            6'h14:   if_instr = 32'h0030_0393;  // li   t2, 3
            6'h15:   if_instr = 32'h0070_9463;  // bne  ra, t2, fail  (3 == 3 -> NOT taken)
            6'h16:   if_instr = 32'h01C0_1E63;  // bne  x0, t3, pass  (0 != 3 -> TAKEN -> 0x74)
            // fail (should NOT execute if core correct)
            6'h17:   if_instr = 32'h001E_1093;  // slli ra, t3, 1
            6'h18:   if_instr = 32'h0010_E093;  // ori  ra, ra, 1
            6'h19:   if_instr = 32'h0000_1117;  // auipc sp, 1
            6'h1A:   if_instr = 32'hF9C1_0113;  // addi sp, sp, -100 -> sp=0x1000
            6'h1B:   if_instr = 32'h0011_2023;  // sw   ra, 0(sp)  -> tohost = ra
            6'h1C:   if_instr = 32'h0000_006F;  // j    .
            // pass
            6'h1D:   if_instr = 32'h0010_0093;  // li   ra, 1
            6'h1E:   if_instr = 32'h0000_1117;  // auipc sp, 1
            6'h1F:   if_instr = 32'hF881_0113;  // addi sp, sp, -120 -> sp=0x1000
            6'h20:   if_instr = 32'h0011_2023;  // sw   ra, 0(sp)  -> tohost = 1 (PASS)
            6'h21:   if_instr = 32'h0000_006F;  // j    .
            default: if_instr = 32'h0000_0013;  // nop
        endcase
    end

    assign if_icache_ready = 1'b1;
    assign if_icache_valid = 1'b1;

    // -------------------------------------------------------------------------
    // Mini "data memory" - chi care dia chi 0x1000 (tohost)
    // -------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] tohost_val;
    logic                  tohost_hit;
    assign tohost_hit = (mem_addr == 32'h1000);

    assign mem_rdata        = tohost_hit ? tohost_val : 32'h0;
    assign mem_dcache_ready = 1'b1;
    assign mem_dcache_valid = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) tohost_val <= 32'h0;
        else if (mem_req && mem_we && tohost_hit) begin
            // Apply wstrb byte-enable
            if (mem_wstrb[0]) tohost_val[ 7: 0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) tohost_val[15: 8] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) tohost_val[23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) tohost_val[31:24] <= mem_wdata[31:24];
        end
    end

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
    // Cycle counter + WB/x28 audit trail
    // -------------------------------------------------------------------------
    int cyc;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) cyc <= 0;
        else        cyc <= cyc + 1;
    end

    // Per-cycle pipeline snapshot (compact)
    always @(posedge clk) if (rst_n) begin
        $display("[c=%03d] IF=%h | ID=%h(%h) | EX=%h rd=%2d br=%b jp=%b | MEM=%h rd=%2d we=%b alu=%h | WB=%h rd=%2d we=%b wsel=%b wdata=%h | mispr_r=%b corr_pc=%h",
            cyc,
            dut.if_pc,
            dut.id_pc, dut.id_instr,
            dut.ex_pc, dut.ex_rd, dut.ex_branch, dut.ex_jump,
            dut.mem_pc, dut.mem_rd, dut.mem_reg_we, dut.mem_alu_result,
            dut.wb_pc,  dut.wb_rd,  dut.wb_reg_we, dut.wb_wb_sel, dut.wb_wdata,
            dut.mispredict_r, dut.correct_pc_r);
    end

    // Audit: moi lan x28 bi ghi
    always @(posedge clk) if (rst_n) begin
        if (dut.wb_reg_we && dut.wb_rd == 5'd28) begin
            $display("  >>> X28 WRITE: wb_pc=%h  wdata=%h  (cyc=%0d)",
                dut.wb_pc, dut.wb_wdata, cyc);
        end
        // Flag ghost: bat cu WB voi wb_pc trong vung [0x38..0x44] (4 BAD addi)
        if (dut.wb_reg_we && dut.wb_pc >= 32'h38 && dut.wb_pc <= 32'h44) begin
            $display("  !!! GHOST from skipped region: wb_pc=%h rd=%0d wdata=%h",
                dut.wb_pc, dut.wb_rd, dut.wb_wdata);
        end
        // Flag ghost: bat cu WB voi wb_pc trong vung fail [0x5C..0x70] neu da vao pass
        if (dut.wb_reg_we && dut.wb_pc >= 32'h5C && dut.wb_pc <= 32'h70) begin
            $display("  !!! FAIL-REGION WB: wb_pc=%h rd=%0d wdata=%h",
                dut.wb_pc, dut.wb_rd, dut.wb_wdata);
        end
        // Store tohost log
        if (dut.mem_req && dut.mem_we && dut.mem_addr == 32'h1000) begin
            $display("  >>> STORE TOHOST @ cyc=%0d: wdata=%h  (x1=%h x28=%h)",
                cyc, dut.mem_wdata,
                dut.u_rf.register[1], dut.u_rf.register[28]);
        end
    end

    // -------------------------------------------------------------------------
    // Stimulus - poll tohost
    // -------------------------------------------------------------------------
    int timeout_cyc;
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;

        // Poll tohost until != 0 or timeout
        timeout_cyc = 300;
        for (int i = 0; i < timeout_cyc; i++) begin
            @(posedge clk);
            if (tohost_val != 32'h0) break;
        end

        $display("\n========================================");
        $display("FINAL STATE @ cyc=%0d", cyc);
        $display("  tohost = %h", tohost_val);
        $display("  x1  (ra) = %h", dut.u_rf.register[1]);
        $display("  x2  (sp) = %h", dut.u_rf.register[2]);
        $display("  x4  (tp) = %h (expect 0x14 = link addr cua JAL)", dut.u_rf.register[4]);
        $display("  x7  (t2) = %h (expect 0x03)", dut.u_rf.register[7]);
        $display("  x28 (t3) = %h (expect 0x03 = TESTNUM test_3)", dut.u_rf.register[28]);
        $display("----------------------------------------");

        if (tohost_val === 32'h1) begin
            $display(">>> PASS: jal prologue + test_2 + test_3 dung <<<");
            $display(">>> Ket luan: core dung, bug o icache/axi memory model <<<");
        end else if (tohost_val === 32'h3) begin
            $display(">>> FAIL tohost=3: x28=1 luc fail store");
            $display(">>> Ket luan: bug REPRODUCED trong core - soi waveform voi scenario nho nay");
        end else if (tohost_val === 32'h0) begin
            $display(">>> TIMEOUT: khong co store nao den tohost");
            $display(">>> Pipeline co the bi stall hoac PC chay sai");
        end else begin
            $display(">>> FAIL tohost=%h: corruption khac", tohost_val);
            $display(">>> Decode: TESTNUM = %0d (tohost >> 1)", tohost_val >> 1);
        end
        $display("========================================");
        $finish;
    end

endmodule
