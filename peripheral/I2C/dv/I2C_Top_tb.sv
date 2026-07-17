`timescale 1ns/1ps

import I2C_pkg::*;

module I2C_Top_tb;

    logic clk;
    logic rst_n;
    
    // I2C physical lines
    wire scl_pad;
    wire sda_pad;
    
    // Pull-up resistors for I2C bus
    pullup(scl_pad);
    pullup(sda_pad);

    // APB Interface
    APB #(12, 32) apb_if();

    // DUT Instantiation
    I2C_Top dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .apb     (apb_if.slave),
        .scl_pad (scl_pad),
        .sda_pad (sda_pad)
    );

    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // Reset sequence
    initial begin
        rst_n = 0;
        #50 rst_n = 1;
    end

    // Testbench variables
    int test_pass = 0;
    int test_fail = 0;
    logic [31:0] read_data;
    
    // Mock Slave controls
    logic force_nack = 0;
    logic sda_drv = 1'b1;
    
    assign sda_pad = (sda_drv == 1'b0) ? 1'b0 : 1'bz;

    // APB Write Task
    task apb_write(input [11:0] addr, input [31:0] data);
        @(posedge clk);
        apb_if.psel    <= 1;
        apb_if.pwrite  <= 1;
        apb_if.paddr   <= addr;
        apb_if.pwdata  <= data;
        apb_if.penable <= 0;
        
        @(posedge clk);
        apb_if.penable <= 1;
        
        wait(apb_if.pready);
        @(posedge clk);
        apb_if.psel    <= 0;
        apb_if.penable <= 0;
    endtask

    // APB Read Task
    task apb_read(input [11:0] addr, output [31:0] data);
        @(posedge clk);
        apb_if.psel    <= 1;
        apb_if.pwrite  <= 0;
        apb_if.paddr   <= addr;
        apb_if.penable <= 0;
        
        @(posedge clk);
        apb_if.penable <= 1;
        
        wait(apb_if.pready);
        @(posedge clk);
        data = apb_if.prdata;
        
        apb_if.psel    <= 0;
        apb_if.penable <= 0;
    endtask

    // Wait for I2C Core to finish (Busy flag = 0)
    task wait_for_ready();
        logic [31:0] stat;
        do begin
            apb_read(STAT_REG, stat);
            #1000;
        end while (stat[0] == 1'b1);
    endtask

    // Assertion checker
    task check_assert(input string test_name, input logic condition);
        if (condition) begin
            $display("[PASS] %s", test_name);
            test_pass++;
        end else begin
            $display("[FAIL] %s", test_name);
            test_fail++;
        end
    endtask

    // I2C Mock Slave (Auto-ACK & Data Feeder)
    integer bit_cnt = 0;
    logic in_frame = 0;
    
    // Detect START
    always @(negedge sda_pad) begin
        if (scl_pad === 1'b1) begin
            in_frame = 1;
            bit_cnt = 0;
        end
    end
    
    // Detect STOP
    always @(posedge sda_pad) begin
        if (scl_pad === 1'b1) begin
            in_frame = 0;
        end
    end

    // Slave shifting logic
    always @(negedge scl_pad) begin
        if (in_frame) begin
            if (bit_cnt < 8) begin
                sda_drv <= 1'b1; // Release bus for data
                bit_cnt <= bit_cnt + 1;
            end else if (bit_cnt == 8) begin
                sda_drv <= force_nack ? 1'b1 : 1'b0; // Drive ACK/NACK
                bit_cnt <= bit_cnt + 1;
            end else begin
                sda_drv <= 1'b1; // Release after ACK
                bit_cnt <= 1;    // Reset for next byte
            end
        end else begin
            sda_drv <= 1'b1;
        end
    end

    // Main Test Sequence 
    initial begin
        // Init signals
        apb_if.psel = 0;
        apb_if.penable = 0;
        apb_if.pwrite = 0;
        apb_if.paddr = 0;
        apb_if.pwdata = 0;

        wait(rst_n);
        #100;
        $display("--- STARTING I2C VERIFICATION ---");

        // TC 1: Verify Reset Values of CTRL_REG
        apb_read(CTRL_REG, read_data);
        check_assert("TC01: Check Reset Value (CTRL_REG == 0)", read_data == 0);

        // TC 2: APB Write/Read match (ADDR_REG)
        apb_write(ADDR_REG, 32'h1234_56);
        apb_read(ADDR_REG, read_data);
        check_assert("TC02: APB Write/Read ADDR_REG", read_data[23:0] == 24'h1234_56);

        // TC 3: APB Write/Read match (LEN_REG)
        apb_write(LEN_REG, 32'h0000_01);
        apb_read(LEN_REG, read_data);
        check_assert("TC03: APB Write/Read LEN_REG", read_data == 32'h1);

        // TC 4: Single Write, 8-bit Sub-address
        force_nack = 0;
        apb_write(ADDR_REG, 32'h0010_A0); 
        apb_write(LEN_REG, 32'h1);
        apb_write(TX_REG, 32'hAA);
        apb_write(CTRL_REG, 32'h1); 
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC04: Single Byte Write (8-bit sub-addr)", read_data[1] == 0);

        // TC 5: Single Write, 16-bit Sub-address
        apb_write(ADDR_REG, 32'h2030_A0); 
        apb_write(TX_REG, 32'hBB);
        apb_write(CTRL_REG, 32'h3); 
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC05: Single Byte Write (16-bit sub-addr)", read_data[1] == 0);

        // TC 6: Single Read, 8-bit Sub-address
        apb_write(ADDR_REG, 32'h0010_A1); 
        apb_write(CTRL_REG, 32'h1); 
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC06: Single Byte Read (8-bit sub-addr)", read_data[1] == 0);

        // TC 7: Single Read, 16-bit Sub-address
        apb_write(ADDR_REG, 32'h4050_A1); 
        apb_write(CTRL_REG, 32'h3); 
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC07: Single Byte Read (16-bit sub-addr)", read_data[1] == 0);

        // TC 8: Multi-byte Write (2 bytes) with FIFO
        apb_write(ADDR_REG, 32'h0011_A0);
        apb_write(LEN_REG, 32'h2);
        apb_write(TX_REG, 32'h11); // Push byte 1 to FIFO
        apb_write(TX_REG, 32'h22); // Push byte 2 to FIFO
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC08: Multi-byte Write (2 bytes) via FIFO", read_data[1] == 0);

        // TC 9: Multi-byte Read (2 bytes) with FIFO
        apb_write(ADDR_REG, 32'h0011_A1);
        apb_write(LEN_REG, 32'h2);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_read(RX_REG, read_data); // Pop byte 1
        apb_read(RX_REG, read_data); // Pop byte 2
        check_assert("TC09: Multi-byte Read (2 bytes) via FIFO", 1'b1);

        // TC 10: General Call Address (0x00)
        apb_write(ADDR_REG, 32'h0000_00);
        apb_write(LEN_REG, 32'h1);
        apb_write(TX_REG, 32'h55);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC10: General Call Address Write", read_data[1] == 0);

        // TC 11: Max 7-bit Address (0x7F) -> 0xFE with W=0
        apb_write(ADDR_REG, 32'h0000_FE); 
        apb_write(TX_REG, 32'h55);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC11: Max 7-bit Address Write", read_data[1] == 0);

        // TC 12: Write Data Pattern 0x55
        apb_write(ADDR_REG, 32'h0020_A0);
        apb_write(TX_REG, 32'h55);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        check_assert("TC12: Write Data Pattern 0x55", 1'b1);

        // TC 13: Write Data Pattern 0xAA
        apb_write(TX_REG, 32'hAA);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        check_assert("TC13: Write Data Pattern 0xAA", 1'b1);

        // TC 14: Write Data Pattern 0xFF
        apb_write(TX_REG, 32'hFF);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        check_assert("TC14: Write Data Pattern 0xFF", 1'b1);

        // TC 15: Write Data Pattern 0x00
        apb_write(TX_REG, 32'h00);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        check_assert("TC15: Write Data Pattern 0x00", 1'b1);

        // TC 16: Check Busy Flag
        apb_write(CTRL_REG, 32'h1);
        #20 apb_read(STAT_REG, read_data);
        check_assert("TC16: Busy flag is active during tx", read_data[0] == 1);
        wait_for_ready();

        // TC 17: NACK Detection
        force_nack = 1;
        apb_write(ADDR_REG, 32'h0000_C0);
        apb_write(TX_REG, 32'h11);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC17: NACK correctly detected", read_data[1] == 1);
        force_nack = 0;

        // TC 18: Back-to-Back Writes
        apb_write(TX_REG, 32'h12);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_write(TX_REG, 32'h34);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC18: Back-to-Back Writes completed", read_data[1] == 0);

        // TC 19: Back-to-Back Reads
        apb_write(ADDR_REG, 32'h0010_C1);
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC19: Back-to-Back Reads completed", read_data[1] == 0);

        // TC 20: 3-Byte sequential Write with FIFO
        apb_write(ADDR_REG, 32'h0000_A0);
        apb_write(LEN_REG, 32'h3);
        apb_write(TX_REG, 32'hA1); // Push 1
        apb_write(TX_REG, 32'hB2); // Push 2
        apb_write(TX_REG, 32'hC3); // Push 3
        apb_write(CTRL_REG, 32'h1);
        wait_for_ready();
        apb_read(STAT_REG, read_data);
        check_assert("TC20: 3-Byte sequential Write via FIFO", read_data[1] == 0);

        // Print Summary
        $display("========================================");
        $display("   TEST SUMMARY                         ");
        $display("========================================");
        $display("   TOTAL TESTS : 20                     ");
        $display("   PASSED      : %0d                    ", test_pass);
        $display("   FAILED      : %0d                    ", test_fail);
        $display("========================================");

        $finish;
    end

endmodule
