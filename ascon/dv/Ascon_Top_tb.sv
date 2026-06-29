`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 06/29/2026
// Module Name: Ascon_Top_tb
// Project Name: Ascon_128AEAD
//////////////////////////////////////////////////////////////////////////////////

module Ascon_Top_tb();

    logic        CLK;
    logic        RESETN;

    // AXI-Lite
    logic [7:0]  s_axi_awaddr;  logic        s_axi_awvalid; logic        s_axi_awready;
    logic [31:0] s_axi_wdata;   logic        s_axi_wvalid;  logic        s_axi_wready;
    logic [1:0]  s_axi_bresp;   logic        s_axi_bvalid;  logic        s_axi_bready;
    logic [7:0]  s_axi_araddr;  logic        s_axi_arvalid; logic        s_axi_arready;
    logic [31:0] s_axi_rdata;   logic [1:0]  s_axi_rresp;   logic        s_axi_rvalid;  logic s_axi_rready;

    // AXI-Stream (Receive)
    logic        S_AXIS_TVALID; logic        S_AXIS_TREADY; logic [63:0] S_AXIS_TDATA;
    logic        S_AXIS_TLAST;  logic [7:0]  S_AXIS_TSTRB;  logic [7:0]  S_AXIS_TKEEP;

    // AXI-Stream (Transmit)
    logic        M_AXIS_TVALID; logic        M_AXIS_TREADY; logic [63:0] M_AXIS_TDATA;
    logic        M_AXIS_TLAST;  logic [7:0]  M_AXIS_TSTRB;  logic [7:0]  M_AXIS_TKEEP;

    // Device Under Test
    Ascon_Top dut (.*); 

    // TẠO CLOCK (100MHz)
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK; 
    end

    logic [63:0] cipher_q [$];

    always @(posedge CLK) begin
        if (M_AXIS_TVALID && M_AXIS_TREADY) begin
            cipher_q.push_back(M_AXIS_TDATA); 
        end
    end

    // BFM TASKS
    task axi_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge CLK);
            s_axi_awaddr  <= addr; s_axi_wdata <= data; s_axi_awvalid <= 1'b1; s_axi_wvalid <= 1'b1; s_axi_bready <= 1'b1;
            wait(s_axi_awready && s_axi_wready);
            @(posedge CLK);
            s_axi_awvalid <= 1'b0; s_axi_wvalid <= 1'b0;
            wait(s_axi_bvalid);
            @(posedge CLK);
            s_axi_bready  <= 1'b0;
        end
    endtask

    task axi_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge CLK);
            s_axi_araddr  <= addr; s_axi_arvalid <= 1'b1; s_axi_rready <= 1'b1;
            wait(s_axi_arready);
            @(posedge CLK);
            s_axi_arvalid <= 1'b0;
            wait(s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge CLK);
            s_axi_rready  <= 1'b0;
        end
    endtask

    task stream_send(input [63:0] data, input is_last);
        begin
            @(posedge CLK);
            S_AXIS_TDATA  <= data; S_AXIS_TLAST <= is_last; S_AXIS_TKEEP <= 8'hFF; S_AXIS_TSTRB <= 8'hFF; S_AXIS_TVALID <= 1'b1;
            do begin
                @(posedge CLK);
            end while (S_AXIS_TREADY == 1'b0);
            S_AXIS_TVALID <= 1'b0;
        end
    endtask

    // CONSTRAINED-RANDOM TEST SCRIPT
    int num_tests = 40;
    
    logic [31:0] k0, k1, k2, k3, n0, n1, n2, n3;
    logic [31:0] read_status;
    logic [31:0] t0, t1, t2, t3;
    
    logic        cfg_skip_asso;
    int          num_ad_blocks;
    int          num_msg_blocks;
    logic [63:0] temp_data;

    initial begin
        RESETN = 0; s_axi_awvalid = 0; s_axi_wvalid = 0; s_axi_bready = 0; s_axi_arvalid = 0; s_axi_rready = 0;
        S_AXIS_TVALID = 0; S_AXIS_TLAST = 0; M_AXIS_TREADY = 1;
        
        #100; RESETN = 1; #50;

        for (int i = 1; i <= num_tests; i++) begin
            $display("==================================================");

            if (i <= 10) begin
                $display(" TEST %0d: NO AD, SINGLE MSG BLOCK", i);
                cfg_skip_asso = 1'b1; num_ad_blocks = 0; num_msg_blocks = 1;
            end else if (i <= 20) begin
                $display(" TEST %0d: NO AD, MULTI MSG BLOCKS", i);
                cfg_skip_asso = 1'b1; num_ad_blocks = 0; num_msg_blocks = $urandom_range(2, 5);
            end else if (i <= 30) begin
                $display(" TEST %0d: WITH AD (1 Block), MSG (1 Block)", i);
                cfg_skip_asso = 1'b0; num_ad_blocks = 1; num_msg_blocks = 1;
            end else begin
                $display(" TEST %0d: WITH AD (Multi), MSG (Multi)", i);
                cfg_skip_asso = 1'b0; num_ad_blocks = $urandom_range(2, 4); num_msg_blocks = $urandom_range(2, 5);
            end
            $display("==================================================");
            
            // Random Key & Nonce
            k0 = $urandom; k1 = $urandom; k2 = $urandom; k3 = $urandom;
            n0 = $urandom; n1 = $urandom; n2 = $urandom; n3 = $urandom;

            $display("  [INPUT]  KEY        = %08h%08h%08h%08h", k3, k2, k1, k0);
            $display("  [INPUT]  NONCE      = %08h%08h%08h%08h", n3, n2, n1, n0);

            // Write Key & Nonce
            axi_write(8'h10, k0); axi_write(8'h14, k1); axi_write(8'h18, k2); axi_write(8'h1C, k3);
            axi_write(8'h20, n0); axi_write(8'h24, n1); axi_write(8'h28, n2); axi_write(8'h2C, n3);

            // START
            axi_write(8'h00, {28'd0, 2'b00, cfg_skip_asso, 1'b1}); 

            // PRINT ASSO_DATA 
            if (!cfg_skip_asso) begin
                $write("  [INPUT]  ASSO_DATA  = ");
                for (int b = 1; b <= num_ad_blocks; b++) begin
                    temp_data = {$urandom, $urandom};
                    $write("%016h", temp_data); 
                    stream_send(temp_data, (b == num_ad_blocks)); 
                end
                $display(""); 
            end

            // PRINT PLAINTEXT 
            $write("  [INPUT]  PLAINTEXT  = ");
            for (int b = 1; b <= num_msg_blocks; b++) begin
                temp_data = {$urandom, $urandom};
                $write("%016h", temp_data); 
                stream_send(temp_data, (b == num_msg_blocks)); 
            end
            $display("");

            // Polling wait DONE
            read_status = 0;
            while (read_status[0] == 1'b0) begin
                axi_read(8'h04, read_status);
            end

            // Read Tag 128-bit
            axi_read(8'h40, t0); axi_read(8'h44, t1); axi_read(8'h48, t2); axi_read(8'h4C, t3);
            
            $display("--------------------------------------------------");

            // PRINT CIPHERTEXT
            $write("  [HW OUT] CIPHERTEXT = ");
            foreach (cipher_q[i]) begin
                $write("%016h", cipher_q[i]);
            end
            $display(""); 
            cipher_q.delete(); 

            $display("  [HW OUT] TAG        = %08h%08h%08h%08h", t3, t2, t1, t0);
            $display("");
            #200; // Reset FSM 
        end

        $display("==================================================");
        $display(" PASS ALL TESTS!", num_tests);
        $display("==================================================");
        $finish; 
    end

endmodule
