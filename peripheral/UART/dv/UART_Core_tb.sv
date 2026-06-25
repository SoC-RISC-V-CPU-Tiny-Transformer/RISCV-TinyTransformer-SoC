`timescale 1ns/1ps

import UART_pkg::*;

module UART_Top_tb;

    parameter int CLK_PERIOD = 10; // 100 MHz 

    logic                  UCLK;
    logic                  reset_n; 

    // TX Interface (system -> UART)
    logic [DATA_WIDTH-1:0] W_data;
    logic                  wr_uart;
    logic                  tx_full;

    // RX Interface (UART -> system)
    logic [DATA_WIDTH-1:0] R_data;
    logic                  rd_uart;
    logic                  rx_empty;

    // Physical lines 
    logic                  tx;
    logic                  rx;

    // LOOPBACK
    assign rx = tx;


    UART_Top dut (
        .UCLK     (UCLK),
        .reset_n  (reset_n), 
        .W_data   (W_data),
        .wr_uart  (wr_uart),
        .tx_full  (tx_full),
        .R_data   (R_data),
        .rd_uart  (rd_uart),
        .rx_empty (rx_empty),
        .rx       (rx),
        .tx       (tx)
    );

    // CLOCK GENERATION
    initial begin
        UCLK = 1'b0;
        forever #(CLK_PERIOD / 2) UCLK = ~UCLK;
    end

    // TEST SEQUENCE
    initial begin

        reset_n = 1'b1; // Not reset
        W_data  = '0;
        wr_uart = 1'b0;
        rd_uart = 1'b0;

        // Reset (Active-Low)
        $display("[%0t] Reset...", $time);
        #(CLK_PERIOD * 5);
        reset_n = 1'b0; 
        #(CLK_PERIOD * 5);
        reset_n = 1'b1; 
        $display("[%0t] Reset done.", $time);
        #(CLK_PERIOD * 10);

        // Send 3 byte (0xAA và 0x55) to TX FIFO 
        $display("[%0t] Sending data to TX FIFO...", $time);
        
        @(negedge UCLK);    
        W_data  = 8'hAA;    
        wr_uart = 1;

        @(negedge UCLK);
        W_data  = 8'h55;

        @(negedge UCLK);
        W_data  = 8'hFF;

        @(negedge UCLK);
        wr_uart = 0;        // Stop write
        $display("[%0t] Sended 0xAA, 0x55, and 0xFF.", $time);

        // Data from RX FIFO 
        $display("[%0t] Waiting for data to be transmitted on the serial line...", $time);

        // Wait first byte (0xAA)
        wait(rx_empty == 1'b0);
        @(negedge UCLK);
        
        $display("[%0t] Data read from RX FIFO: 0x%h", $time, R_data);
        
        rd_uart = 1'b1; 
        
        @(negedge UCLK);
        rd_uart = 1'b0; 

        // READ BYTE 2 (0x55)
        wait(rx_empty == 1'b0);
        @(negedge UCLK);
        $display("[%0t] Data read from RX FIFO: 0x%h", $time, R_data);
        rd_uart = 1'b1; 
        
        @(negedge UCLK);
        rd_uart = 1'b0; 

        // READ BYTE 3 (0xFF)
        wait(rx_empty == 1'b0);
        @(negedge UCLK);
        $display("[%0t] Data read from RX FIFO: 0x%h", $time, R_data);
        rd_uart = 1'b1; 
        
        @(negedge UCLK);
        rd_uart = 1'b0;

        // Done
        #(CLK_PERIOD * 100);
        $display("[%0t] SUCCESS TESTBENCH!", $time);
        #100000;
        $finish;
    end

endmodule
