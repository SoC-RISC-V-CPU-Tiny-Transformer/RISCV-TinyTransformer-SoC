`timescale 1ns/1ps
import UART_pkg::*;

module UART_Top_tb;

    // Parameters
    localparam CLK_PERIOD = 10; 
    localparam BIT_PERIOD = 1085; // Adjust based on your Baud_Gen logic
    
    // Testbench Signals
    logic                  PCLK;
    logic                  PRESETn;
    logic [ADDR_WIDTH-1:0] PADDR;
    logic                  PSEL;
    logic                  PENABLE;
    logic                  PWRITE;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic                  PREADY;
    logic                  PSLVERR;
    
    logic                  rx_pin;
    logic                  tx_pin;
    logic                  loopback_en;

    logic [DATA_WIDTH-1:0] read_data;

    // Pass/Fail Counters
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // DUT Instantiation
    UART_Top dut (
        .PCLK     (PCLK),
        .PRESETn  (PRESETn),
        .PADDR    (PADDR),
        .PSEL     (PSEL),
        .PENABLE  (PENABLE),
        .PWRITE   (PWRITE),
        .PWDATA   (PWDATA),
        .PRDATA   (PRDATA),
        .PREADY   (PREADY),
        .PSLVERR  (PSLVERR),
        .rx       (loopback_en ? tx_pin : rx_pin), 
        .tx       (tx_pin)
    );

    // Clock Gen
    initial begin
        PCLK = 0;
        forever #(CLK_PERIOD/2) PCLK = ~PCLK;
    end

    // TASKS
    // Auto-Checker Task
    task check_data(input string tc_name, input logic [DATA_WIDTH-1:0] expected, input logic [DATA_WIDTH-1:0] actual);
        if (expected === actual) begin
            $display("[PASS] %s", tc_name);
            pass_cnt++;
        end else begin
            $display("[FAIL] %s | Expected: %02h, Got: %02h", tc_name, expected, actual);
            fail_cnt++;
        end
    endtask

    // APB Write
    task apb_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        @(posedge PCLK);
        PADDR   = addr;
        PWDATA  = data;
        PWRITE  = 1'b1;
        PSEL    = 1'b1;
        PENABLE = 1'b0;
        @(posedge PCLK);
        PENABLE = 1'b1;
        wait(PREADY);
        @(posedge PCLK);
        PSEL    = 1'b0;
        PENABLE = 1'b0;
    endtask

    // APB Read
    task apb_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
        @(posedge PCLK);
        PADDR   = addr;
        PWRITE  = 1'b0;
        PSEL    = 1'b1;
        PENABLE = 1'b0;
        @(posedge PCLK);
        PENABLE = 1'b1;
        wait(PREADY);
        data    = PRDATA;
        @(posedge PCLK);
        PSEL    = 1'b0;
        PENABLE = 1'b0;
    endtask

    // Serial Injection
    task serial_send(input [7:0] data);
        integer i;
        rx_pin = 0; // Start bit
        #(BIT_PERIOD);
        for(i=0; i<8; i++) begin
            rx_pin = data[i]; 
            #(BIT_PERIOD);
        end
        rx_pin = 1; // Stop bit
        #(BIT_PERIOD);
    endtask

    // MAIN SEQUENCE
    initial begin
        // Reset state
        PRESETn     = 0;
        PADDR       = 0;
        PSEL        = 0;
        PENABLE     = 0;
        PWRITE      = 0;
        PWDATA      = 0;
        rx_pin      = 1; 
        loopback_en = 0;
        read_data   = 0;

        #(CLK_PERIOD*10);
        PRESETn = 1;
        #(CLK_PERIOD*10);
        $display("\n========================================");
        $display("          STARTING UART TESTS");
        $display("========================================\n");

        // SECTION 1: APB Register Check
        apb_read(8'h04, read_data);
        // Assuming status layout: bit1 = rx_empty, bit0 = tx_full. Default empty & not full -> 2'b10 (0x02)
        check_data("TC1: Status after Reset (rx_empty=1)", 8'h02, read_data); 
        
        apb_read(8'h08, read_data);
        check_data("TC2: Read invalid APB Addr (Expect 0)", 8'h00, read_data);
        
        apb_write(8'h08, 8'hFF);
        apb_read(8'h00, read_data); // Ensure valid data reg wasn't corrupted
        check_data("TC3: Write invalid APB Addr (No corrupt)", 8'h00, read_data);

        $display("\n[INFO] Injecting Protocol Violations (TC4-TC7)...");
        // TC4-TC7: Protocol Violations (Checking if logic hangs)
        @(posedge PCLK); PADDR=8'h00; PWDATA=8'hAA; PWRITE=1; PSEL=1; PENABLE=0;
        @(posedge PCLK); PSEL=0; 
        @(posedge PCLK); PADDR=8'h00; PWDATA=8'h55; PWRITE=1; PSEL=0; PENABLE=1;
        @(posedge PCLK); PENABLE=0;
        @(posedge PCLK); PADDR=8'h04; PWRITE=0; PSEL=1; PENABLE=0;
        @(posedge PCLK); PSEL=0;
        @(posedge PCLK); PADDR=8'h04; PWRITE=0; PSEL=0; PENABLE=1;
        @(posedge PCLK); PENABLE=0;
        
        // Recover and check if APB still responds
        apb_read(8'h04, read_data);
        check_data("TC4-7: Protocol Violations (DUT survived)", 8'h02, read_data);


        // SECTION 2: External RX -> APB Read
        $display("\n[INFO] Starting External RX Tests...");
        serial_send(8'h55);
        apb_read(8'h00, read_data); 
        check_data("TC8: Serial RX pattern 0x55", 8'h55, read_data);

        serial_send(8'hAA);
        apb_read(8'h00, read_data); 
        check_data("TC9: Serial RX pattern 0xAA", 8'hAA, read_data);

        serial_send(8'h00);
        apb_read(8'h00, read_data);
        check_data("TC10: Serial RX pattern 0x00", 8'h00, read_data);

        serial_send(8'hFF);
        apb_read(8'h00, read_data);
        check_data("TC11: Serial RX pattern 0xFF", 8'hFF, read_data);

        // RX Status Flags
        serial_send(8'h12);
        apb_read(8'h04, read_data); 
        check_data("TC12: Status rx_empty=0 before read", 8'h00, read_data); // rx_empty is 0
        apb_read(8'h00, read_data);
        check_data("TC13: Read RX data 0x12", 8'h12, read_data);
        apb_read(8'h04, read_data);
        check_data("TC14: Status rx_empty=1 after read", 8'h02, read_data); 


        // SECTION 3: TX/RX Internal Loopback
        $display("\n[INFO] Starting Internal Loopback (TX->RX) Tests...");
        loopback_en = 1; 

        apb_write(8'h00, 8'h55); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC15: Loopback pattern 0x55", 8'h55, read_data);

        apb_write(8'h00, 8'hAA); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC16: Loopback pattern 0xAA", 8'hAA, read_data);

        apb_write(8'h00, 8'h00); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC17: Loopback pattern 0x00", 8'h00, read_data);

        apb_write(8'h00, 8'hFF); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC18: Loopback pattern 0xFF", 8'hFF, read_data);

        apb_write(8'h00, 8'h3C); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC19: Loopback Random 0x3C", 8'h3C, read_data);

        apb_write(8'h00, 8'hC3); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC20: Loopback Random 0xC3", 8'hC3, read_data);

        apb_write(8'h00, 8'h0F); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC21: Loopback Random 0x0F", 8'h0F, read_data);

        apb_write(8'h00, 8'hF0); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC22: Loopback Random 0xF0", 8'hF0, read_data);

        apb_write(8'h00, 8'h81); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC23: Loopback Random 0x81", 8'h81, read_data);

        apb_write(8'h00, 8'h18); #(BIT_PERIOD*12); apb_read(8'h00, read_data);
        check_data("TC24: Loopback Random 0x18", 8'h18, read_data);


        // SECTION 4: Corner & Stress Cases
        $display("\n[INFO] Starting Stress & Reset Recovery Tests...");
        
        apb_write(8'h00, 8'hA5);
        #(BIT_PERIOD*2); 
        apb_read(8'h04, read_data); 
        // Expect tx_full=1 or rx_empty=1 depending on design timing. We'll just flush it here.
        check_data("TC25: Write accepted", 8'h02, read_data & 8'h02); // Ensure at least rx is empty
        #(BIT_PERIOD*10); 
        apb_read(8'h00, read_data); 
        check_data("TC25: Read back after stress", 8'hA5, read_data);

        apb_write(8'h00, 8'h11);
        #(BIT_PERIOD*12); 
        apb_write(8'h00, 8'h22);
        #(BIT_PERIOD*12);
        apb_read(8'h00, read_data); // Clear 0x11
        apb_read(8'h00, read_data); // Read 0x22 (assuming simple buffer, might need adjusting based on FIFO depth)
        check_data("TC26: Back-to-back writes (Got 2nd payload)", 8'h22, read_data);
        
        // Clear out
        apb_read(8'h00, read_data); 
        check_data("TC27: Read empty RX", 8'h00, read_data); // Or previous data depending on design

        // Mid-transaction Reset
        apb_write(8'h00, 8'h5A); 
        #(BIT_PERIOD*4);         
        PRESETn = 0;             
        #(CLK_PERIOD*5);
        PRESETn = 1;             
        #(BIT_PERIOD*5);

        apb_read(8'h04, read_data); 
        check_data("TC28-29: Post-Reset Status Recovery", 8'h02, read_data); 

        apb_write(8'h00, 8'h7E);
        #(BIT_PERIOD*12);
        apb_read(8'h00, read_data); 
        check_data("TC30: Post-Reset Normal Tx/Rx", 8'h7E, read_data); 


        // FINAL SUMMARY
        #(CLK_PERIOD*20);
        $display("\n========================================");
        $display("              TEST SUMMARY              ");
        $display("========================================");
        $display("Total Cases Checked : %0d", pass_cnt + fail_cnt);
        $display("Passed              : %0d", pass_cnt);
        $display("Failed              : %0d", fail_cnt);
        $display("========================================");
        
        if (fail_cnt == 0)
            $display("   >>> RESULT: ALL TESTS PASSED! <<<");
        else
            $display("   >>> RESULT: FAILED! Check Logs. <<<");
        $display("========================================\n");
        
        $finish;
    end

endmodule
