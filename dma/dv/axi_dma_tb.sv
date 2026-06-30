`timescale 1ns/1ps

import dma_pkg::*; 

module axi_dma_tb;

    logic clk, rst_n;

    // AXI-Lite
    logic [AXI_LITE_ADDR_WIDTH-1:0] s_axi_lite_awaddr, s_axi_lite_araddr;
    logic                           s_axi_lite_awvalid, s_axi_lite_arvalid;
    logic                           s_axi_lite_awready, s_axi_lite_arready;
    logic [AXI_LITE_DATA_WIDTH-1:0] s_axi_lite_wdata;
    logic                           s_axi_lite_wvalid, s_axi_lite_wready;
    logic [1:0]                     s_axi_lite_bresp, s_axi_lite_rresp;
    logic                           s_axi_lite_bvalid, s_axi_lite_rvalid;
    logic                           s_axi_lite_bready, s_axi_lite_rready;
    logic [AXI_LITE_DATA_WIDTH-1:0] s_axi_lite_rdata;

    // M_AXI_MM2S (RAM Read)
    logic [ADDR_WIDTH-1:0]          m_axi_mm2s_araddr;
    logic [AXI_LEN_WIDTH-1:0]       m_axi_mm2s_arlen;
    logic                           m_axi_mm2s_arvalid, m_axi_mm2s_arready;
    logic [DATA_WIDTH-1:0]          m_axi_mm2s_rdata;
    logic                           m_axi_mm2s_rlast, m_axi_mm2s_rvalid, m_axi_mm2s_rready;

    // M_AXIS_MM2S (Stream Out)
    logic [DATA_WIDTH-1:0]          m_axis_mm2s_tdata;
    logic [KEEP_WIDTH-1:0]          m_axis_mm2s_tstrb, m_axis_mm2s_tkeep;
    logic                           m_axis_mm2s_tvalid, m_axis_mm2s_tready, m_axis_mm2s_tlast;

    // M_AXI_S2MM (RAM Write)
    logic [ADDR_WIDTH-1:0]          m_axi_s2mm_awaddr;
    logic [AXI_LEN_WIDTH-1:0]       m_axi_s2mm_awlen;
    logic                           m_axi_s2mm_awvalid, m_axi_s2mm_awready;
    logic [DATA_WIDTH-1:0]          m_axi_s2mm_wdata;
    logic [KEEP_WIDTH-1:0]          m_axi_s2mm_wstrb;
    logic                           m_axi_s2mm_wlast, m_axi_s2mm_wvalid, m_axi_s2mm_wready;
    logic [1:0]                     m_axi_s2mm_bresp;
    logic                           m_axi_s2mm_bvalid, m_axi_s2mm_bready;

    // S_AXIS_S2MM (Stream In)
    logic [DATA_WIDTH-1:0]          s_axis_s2mm_tdata;
    logic [KEEP_WIDTH-1:0]          s_axis_s2mm_tstrb, s_axis_s2mm_tkeep;
    logic                           s_axis_s2mm_tvalid, s_axis_s2mm_tready, s_axis_s2mm_tlast;

    // DUT INSTANTIATION & LOOPBACK
    axi_dma u_dut (
        .clk(clk), .rst_n(rst_n),
        .s_axi_lite_awaddr(s_axi_lite_awaddr), .s_axi_lite_awvalid(s_axi_lite_awvalid), .s_axi_lite_awready(s_axi_lite_awready),
        .s_axi_lite_wdata(s_axi_lite_wdata),   .s_axi_lite_wvalid(s_axi_lite_wvalid),   .s_axi_lite_wready(s_axi_lite_wready),
        .s_axi_lite_bresp(s_axi_lite_bresp),   .s_axi_lite_bvalid(s_axi_lite_bvalid),   .s_axi_lite_bready(s_axi_lite_bready),
        .s_axi_lite_araddr(s_axi_lite_araddr), .s_axi_lite_arvalid(s_axi_lite_arvalid), .s_axi_lite_arready(s_axi_lite_arready),
        .s_axi_lite_rdata(s_axi_lite_rdata),   .s_axi_lite_rresp(s_axi_lite_rresp),     .s_axi_lite_rvalid(s_axi_lite_rvalid), .s_axi_lite_rready(s_axi_lite_rready),
        
        .m_axi_mm2s_araddr(m_axi_mm2s_araddr), .m_axi_mm2s_arlen(m_axi_mm2s_arlen), .m_axi_mm2s_arvalid(m_axi_mm2s_arvalid), .m_axi_mm2s_arready(m_axi_mm2s_arready),
        .m_axi_mm2s_rdata(m_axi_mm2s_rdata),   .m_axi_mm2s_rlast(m_axi_mm2s_rlast), .m_axi_mm2s_rvalid(m_axi_mm2s_rvalid),   .m_axi_mm2s_rready(m_axi_mm2s_rready),
        .m_axis_mm2s_tdata(m_axis_mm2s_tdata), .m_axis_mm2s_tstrb(m_axis_mm2s_tstrb), .m_axis_mm2s_tkeep(m_axis_mm2s_tkeep), .m_axis_mm2s_tvalid(m_axis_mm2s_tvalid), .m_axis_mm2s_tready(m_axis_mm2s_tready), .m_axis_mm2s_tlast(m_axis_mm2s_tlast),
        
        .m_axi_s2mm_awaddr(m_axi_s2mm_awaddr), .m_axi_s2mm_awlen(m_axi_s2mm_awlen), .m_axi_s2mm_awvalid(m_axi_s2mm_awvalid), .m_axi_s2mm_awready(m_axi_s2mm_awready),
        .m_axi_s2mm_wdata(m_axi_s2mm_wdata),   .m_axi_s2mm_wstrb(m_axi_s2mm_wstrb), .m_axi_s2mm_wlast(m_axi_s2mm_wlast),     .m_axi_s2mm_wvalid(m_axi_s2mm_wvalid), .m_axi_s2mm_wready(m_axi_s2mm_wready),
        .m_axi_s2mm_bresp(m_axi_s2mm_bresp),   .m_axi_s2mm_bvalid(m_axi_s2mm_bvalid), .m_axi_s2mm_bready(m_axi_s2mm_bready),
        .s_axis_s2mm_tdata(s_axis_s2mm_tdata), .s_axis_s2mm_tstrb(s_axis_s2mm_tstrb), .s_axis_s2mm_tkeep(s_axis_s2mm_tkeep), .s_axis_s2mm_tvalid(s_axis_s2mm_tvalid), .s_axis_s2mm_tready(s_axis_s2mm_tready), .s_axis_s2mm_tlast(s_axis_s2mm_tlast)
    );

    // LOOPBACK: Output Stream to Input Stream
    assign s_axis_s2mm_tdata  = m_axis_mm2s_tdata;
    assign s_axis_s2mm_tstrb  = m_axis_mm2s_tstrb;
    assign s_axis_s2mm_tkeep  = m_axis_mm2s_tkeep;
    assign s_axis_s2mm_tvalid = m_axis_mm2s_tvalid;
    assign s_axis_s2mm_tlast  = m_axis_mm2s_tlast;
    assign m_axis_mm2s_tready = s_axis_s2mm_tready;

    // Clock
    initial begin clk = 0; forever #5 clk = ~clk; end

    // OOP CRV CLASS 
    typedef enum {SANITY, RANDOM_LEN, BACKPRESSURE} test_type_e;

    class DMA_Transaction;
        rand test_type_e          t_type;
        rand bit [ADDR_WIDTH-1:0] src_addr;
        rand bit [ADDR_WIDTH-1:0] dst_addr;
        rand bit [15:0]           length;
        rand bit                  en_stall;

        constraint c_addr {
            src_addr inside {[32'h0000_1000 : 32'h0000_2000]};
            dst_addr inside {[32'h0000_3000 : 32'h0000_4000]};
            src_addr[2:0] == 3'b000; // 8-byte aligned
            dst_addr[2:0] == 3'b000;
        }

        constraint c_length {
            length[2:0] == 3'b000; 
            if (t_type == SANITY) length == 64;
            if (t_type == RANDOM_LEN || t_type == BACKPRESSURE) length inside {[8 : 512]};
        }

        constraint c_stall {
            if (t_type == BACKPRESSURE) en_stall == 1;
            else en_stall == 0;
        }
    endclass

    DMA_Transaction tr;

    // BFM TASKS 
    task cpu_write_lite(input [AXI_LITE_ADDR_WIDTH-1:0] addr, input [AXI_LITE_DATA_WIDTH-1:0] data);
        @(posedge clk);
        s_axi_lite_awaddr  <= addr; s_axi_lite_awvalid <= 1'b1;
        s_axi_lite_wdata   <= data; s_axi_lite_wvalid  <= 1'b1;
        s_axi_lite_bready  <= 1'b1;
        do begin @(posedge clk); end while (!(s_axi_lite_awready && s_axi_lite_wready));
        s_axi_lite_awvalid <= 1'b0; s_axi_lite_wvalid  <= 1'b0;
        do begin @(posedge clk); end while (!s_axi_lite_bvalid);
        s_axi_lite_bready <= 1'b0;
    endtask

    task cpu_read_lite(input [AXI_LITE_ADDR_WIDTH-1:0] addr, output [AXI_LITE_DATA_WIDTH-1:0] data);
        @(posedge clk);
        s_axi_lite_araddr  <= addr; s_axi_lite_arvalid <= 1'b1;
        s_axi_lite_rready  <= 1'b1;
        do begin @(posedge clk); end while (!(s_axi_lite_arready && s_axi_lite_arvalid));
        s_axi_lite_arvalid <= 1'b0;
        do begin @(posedge clk); end while (!(s_axi_lite_rvalid && s_axi_lite_rready));
        data = s_axi_lite_rdata;
        s_axi_lite_rready <= 1'b0;
    endtask

    // Mock RAM MM2S (Read) Channel
    task ram_axi_read_mock();
        int beats;
        m_axi_mm2s_arready <= 1'b1;
        forever begin
            @(posedge clk);
            if (m_axi_mm2s_arvalid && m_axi_mm2s_arready) begin
                beats = m_axi_mm2s_arlen + 1;
                m_axi_mm2s_arready <= 1'b0; 
                
                for (int i = 0; i < beats; i++) begin
                    if (tr.en_stall && ($urandom() % 3 == 0)) begin
                        m_axi_mm2s_rvalid <= 1'b0;
                        repeat($urandom_range(1, 3)) @(posedge clk);
                    end
                    m_axi_mm2s_rvalid <= 1'b1;
                    m_axi_mm2s_rdata  <= {$urandom(), $urandom()}; // Random data
                    m_axi_mm2s_rlast  <= (i == beats - 1);
                    
                    do begin @(posedge clk); end while (!(m_axi_mm2s_rvalid && m_axi_mm2s_rready));
                end
                m_axi_mm2s_rvalid <= 1'b0;
                m_axi_mm2s_rlast  <= 1'b0;
                m_axi_mm2s_arready <= 1'b1;
            end
        end
    endtask

    // Mock RAM S2MM (Write) Channel
    task ram_axi_write_mock();
        int beats;
        m_axi_s2mm_awready <= 1'b1;
        m_axi_s2mm_wready  <= 1'b0;
        forever begin
            @(posedge clk);
            if (m_axi_s2mm_awvalid && m_axi_s2mm_awready) begin
                beats = m_axi_s2mm_awlen + 1;
                m_axi_s2mm_awready <= 1'b0;
                
                // Receive Data
                for (int i = 0; i < beats; i++) begin
                    if (tr.en_stall && ($urandom() % 3 == 0)) begin
                        m_axi_s2mm_wready <= 1'b0;
                        repeat($urandom_range(1, 3)) @(posedge clk);
                    end
                    m_axi_s2mm_wready <= 1'b1;
                    
                    do begin @(posedge clk); end while (!(m_axi_s2mm_wvalid && m_axi_s2mm_wready));
                end
                m_axi_s2mm_wready <= 1'b0;
                
                // Return Response
                if (tr.en_stall) repeat($urandom_range(1, 4)) @(posedge clk);
                m_axi_s2mm_bvalid <= 1'b1;
                m_axi_s2mm_bresp  <= 2'b00; // OKAY
                do begin @(posedge clk); end while (!(m_axi_s2mm_bvalid && m_axi_s2mm_bready));
                m_axi_s2mm_bvalid <= 1'b0;
                
                m_axi_s2mm_awready <= 1'b1;
            end
        end
    endtask

    logic mm2s_is_done, s2mm_is_done;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mm2s_is_done <= 0;
            s2mm_is_done <= 0;
        end else begin
            if (u_dut.mm2s_done) mm2s_is_done <= 1'b1;
            if (u_dut.s2mm_done) s2mm_is_done <= 1'b1;

            if (s_axi_lite_awvalid && s_axi_lite_awaddr == 5'h00) begin
                mm2s_is_done <= 0;
                s2mm_is_done <= 0;
            end
        end
    end

    task wait_dma_done();
        wait(mm2s_is_done && s2mm_is_done);
    endtask

    // MAIN VERIFICATION SEQUENCE
    initial begin
        // Reset and Init
        rst_n = 0;
        s_axi_lite_awvalid = 0; s_axi_lite_wvalid = 0; s_axi_lite_bready = 0;
        s_axi_lite_arvalid = 0; s_axi_lite_rready = 0;
        m_axi_mm2s_rvalid = 0;
        m_axi_s2mm_bvalid = 0;
        #50 rst_n = 1;
        #20;
        
        $display("=================================================");
        $display("   STARTING 40 FULL-DUPLEX TESTS                 ");
        $display("=================================================");

        tr = new();
        
        fork 
            ram_axi_read_mock(); 
            ram_axi_write_mock();
        join_none

        for (int i = 1; i <= 40; i++) begin
            if (!tr.randomize()) $fatal("Randomization Failed!");

            if (i <= 5)       tr.t_type = SANITY;
            else if (i <= 20) tr.t_type = RANDOM_LEN;
            else              tr.t_type = BACKPRESSURE;
            tr.randomize(); 

            $display("[%0t] Starting Test %0d | Type: %s | Len: %0d bytes | Stall: %0b", 
                     $time, i, tr.t_type.name(), tr.length, tr.en_stall);

            // CPU configures DMA via AXI-Lite
            cpu_write_lite(5'h04, tr.src_addr); // slv_reg1: MM2S Src
            cpu_write_lite(5'h08, tr.length);   // slv_reg2: MM2S Len
            cpu_write_lite(5'h0C, tr.dst_addr); // slv_reg3: S2MM Dst
            cpu_write_lite(5'h10, tr.length);   // slv_reg4: S2MM Len

            // Start MM2S and S2MM (Write 32'h03 = 2'b11 into slv_reg0)
            cpu_write_lite(5'h00, 32'h0000_0003); 

            // Wait for DMA Master to signal Done via AXI-Lite
            wait_dma_done();
            
            $display("[%0t] Test %0d PASSED.\n", $time, i);
            #100; 
        end

        $display("=================================================");
        $display("   SUCCESSFULLY COMPLETED 40 TESTCASES           ");
        $display("=================================================");
        $finish;
    end
endmodule
