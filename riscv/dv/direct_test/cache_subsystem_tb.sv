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
// Module       : cache_subsystem_tb

// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-14
// Version      : 1.0
// -----------------------------------------------------------------------------

module cache_subsystem_tb;
    import cache_pkg::*;
    import axi_pkg::*;

    //system
    logic clk;
    logic rst_n;

    //if stage
    logic [ADDR_WIDTH-1:0]  if_pc;
    logic                   if_req;
    logic [DATA_WIDTH-1:0]  if_instr;
    logic                   if_icache_ready;
    logic                   if_icache_valid;

    //mem stage
    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req;
    logic                   mem_we;
    logic [DATA_WIDTH-1:0]  mem_wdata;
    logic [STRB_WIDTH-1:0]  mem_wstrb;
    logic [DATA_WIDTH-1:0]  mem_rdata;
    logic                   mem_dcache_ready;
    logic                   mem_dcache_valid;

    //fence
    logic                   fence;
    logic                   fence_done;

    //axi4 master
    logic                   axi_arvalid;
    logic                   axi_arready;
    logic [ADDR_WIDTH-1:0]  axi_araddr;
    logic [7:0]             axi_arlen;
    logic [2:0]             axi_arsize;
    logic [1:0]             axi_arburst;
    logic                   axi_rvalid;
    logic                   axi_rready;
    logic [DATA_WIDTH-1:0]  axi_rdata;
    logic [1:0]             axi_rresp;
    logic                   axi_rlast;
    logic                   axi_awvalid;
    logic                   axi_awready;
    logic [ADDR_WIDTH-1:0]  axi_awaddr;
    logic [7:0]             axi_awlen;
    logic [2:0]             axi_awsize;
    logic [1:0]             axi_awburst;
    logic                   axi_wvalid;
    logic                   axi_wready;
    logic [DATA_WIDTH-1:0]  axi_wdata;
    logic [STRB_WIDTH-1:0]  axi_wstrb;
    logic                   axi_wlast;
    logic                   axi_bvalid;
    logic                   axi_bready;
    logic [1:0]             axi_bresp;

    //cache_subsystem instance
    cache_subsystem u_dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .if_pc              (if_pc),
        .if_req             (if_req),
        .if_instr           (if_instr),
        .if_icache_ready    (if_icache_ready),
        .if_icache_valid    (if_icache_valid),
        .mem_addr           (mem_addr),
        .mem_req            (mem_req),
        .mem_we             (mem_we),
        .mem_wdata          (mem_wdata),
        .mem_wstrb          (mem_wstrb),
        .mem_rdata          (mem_rdata),
        .mem_dcache_ready   (mem_dcache_ready),
        .mem_dcache_valid   (mem_dcache_valid),
        .fence              (fence),
        .fence_done         (fence_done),
        .m_axi_arvalid      (axi_arvalid),
        .m_axi_arready      (axi_arready),
        .m_axi_araddr       (axi_araddr),
        .m_axi_arlen        (axi_arlen),
        .m_axi_arsize       (axi_arsize),
        .m_axi_arburst      (axi_arburst),
        .m_axi_rvalid       (axi_rvalid),
        .m_axi_rready       (axi_rready),
        .m_axi_rdata        (axi_rdata),
        .m_axi_rresp        (axi_rresp),
        .m_axi_rlast        (axi_rlast),
        .m_axi_awvalid      (axi_awvalid),
        .m_axi_awready      (axi_awready),
        .m_axi_awaddr       (axi_awaddr),
        .m_axi_awlen        (axi_awlen),
        .m_axi_awsize       (axi_awsize),
        .m_axi_awburst      (axi_awburst),
        .m_axi_wvalid       (axi_wvalid),
        .m_axi_wready       (axi_wready),
        .m_axi_wdata        (axi_wdata),
        .m_axi_wstrb        (axi_wstrb),
        .m_axi_wlast        (axi_wlast),
        .m_axi_bvalid       (axi_bvalid),
        .m_axi_bready       (axi_bready),
        .m_axi_bresp        (axi_bresp)
    );

    //axi_slave_model instance
    axi_slave_model #(
        .MEM_SIZE       (65536),
        .READ_LATENCY   (5),
        .WRITE_LATENCY  (5),
        .VERBOSE        (1'b0)
    ) u_mem_model (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_arvalid  (axi_arvalid),
        .s_axi_araddr   (axi_araddr),
        .s_axi_arlen    (axi_arlen),
        .s_axi_arsize   (axi_arsize),
        .s_axi_arburst  (axi_arburst),
        .s_axi_arready  (axi_arready),
        .s_axi_rvalid   (axi_rvalid),
        .s_axi_rdata    (axi_rdata),
        .s_axi_rresp    (axi_rresp),
        .s_axi_rlast    (axi_rlast),
        .s_axi_rready   (axi_rready),
        .s_axi_awvalid  (axi_awvalid),
        .s_axi_awaddr   (axi_awaddr),
        .s_axi_awlen    (axi_awlen),
        .s_axi_awsize   (axi_awsize),
        .s_axi_awburst  (axi_awburst),
        .s_axi_awready  (axi_awready),
        .s_axi_wvalid   (axi_wvalid),
        .s_axi_wdata    (axi_wdata),
        .s_axi_wstrb    (axi_wstrb),
        .s_axi_wlast    (axi_wlast),
        .s_axi_wready   (axi_wready),
        .s_axi_bvalid   (axi_bvalid),
        .s_axi_bresp    (axi_bresp),
        .s_axi_bready   (axi_bready)
    );

    //clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    //tasks
    task automatic reset_sys();
        rst_n = 1'b0;
        if_pc = '0; if_req = 1'b0;
        mem_addr = '0; mem_req = 1'b0; mem_we = 1'b0; mem_wdata = '0; mem_wstrb = '0; fence = 1'b0;
        #20 rst_n = 1'b1;
        #10;
    endtask

    task automatic i_read(input logic [31:0] addr, input logic [31:0] expected);
        @(posedge clk);
        if_pc = addr;
        if_req = 1'b1;
        wait(if_icache_ready && if_icache_valid);
        @(posedge clk);
        if (if_instr !== expected) 
            $error("[I-CACHE FAIL] Addr %h: Exp %h, Got %h", addr, expected, if_instr);
        else 
            $display("[I-CACHE PASS] Addr %h: %h", addr, if_instr);
        if_req = 1'b0;
    endtask

    task automatic d_read(input logic [31:0] addr, input logic [31:0] expected);
        @(posedge clk);
        mem_addr = addr;
        mem_req = 1'b1;
        mem_we = 1'b0;
        wait(mem_dcache_ready && mem_dcache_valid);
        @(posedge clk);
        if (mem_rdata !== expected) 
            $error("[D-CACHE FAIL] Addr %h: Exp %h, Got %h", addr, expected, mem_rdata);
        else 
            $display("[D-CACHE PASS] Addr %h: %h", addr, mem_rdata);
        mem_req = 1'b0;
    endtask

    task automatic d_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
        @(posedge clk);
        mem_addr = addr;
        mem_wdata = data;
        mem_wstrb = strb;
        mem_req = 1'b1;
        mem_we = 1'b1;
        wait(mem_dcache_ready); 
        @(posedge clk);
        $display("[D-CACHE WRITE] Addr %h, Data %h, Strb %b", addr, data, strb);
        mem_req = 1'b0;
        mem_we = 1'b0;
    endtask

    //main test sequence
    initial begin
        $display("==================================================");
        $display("   STARTING CACHE SUBSYSTEM TESTBENCH");
        $display("==================================================");
        
        reset_sys();

        //preload data to memory model
        u_mem_model.write_word(32'h0000_1000, 32'hDEADBEEF);
        u_mem_model.write_word(32'h0000_1004, 32'hCAFEBABE);
        u_mem_model.write_word(32'h0000_2000, 32'h11223344);

        $display("\n--- [TEST 1] I-CACHE COLD MISS & HIT ---");
        i_read(32'h0000_1000, 32'hDEADBEEF); // Cold miss 
        i_read(32'h0000_1004, 32'hCAFEBABE); // Hit 
        i_read(32'h0000_1000, 32'hDEADBEEF); // Hit

        $display("\n--- [TEST 2] D-CACHE WRITE-THROUGH & WRITE BUFFER ---");
        d_write(32'h0000_3000, 32'hAABBCCDD, 4'b1111); 
        d_write(32'h0000_3004, 32'h55667788, 4'b1111); 
        
        $display("\n--- [TEST 3] STORE-TO-LOAD FORWARDING (RAW HAZARD) ---");
        d_read(32'h0000_3000, 32'hAABBCCDD); 
        d_read(32'h0000_3004, 32'h55667788);

        $display("\n--- [TEST 4] PARTIAL WRITE & MERGE ---");
        d_write(32'h0000_2000, 32'h99, 4'b0001); 
        d_read(32'h0000_2000, 32'h11223399);

        $display("\n--- [TEST 5] FENCE SYNCHRONIZATION ---");
        @(posedge clk);
        fence = 1'b1;
        wait(fence_done);
        @(posedge clk);
        fence = 1'b0;
        $display("[FENCE PASS] Write Buffer drained completely.");

        #100;
        $display("==================================================");
        $display("   TESTBENCH COMPLETED");
        $display("==================================================");
        $finish;
    end
endmodule
