`timescale 1ns / 1ps

module CPU_RISC_V_tb;

    // Clock and reset
    logic clk;
    logic rst_n;
    logic [31:0] data_out;

    // Clock generation (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT instantiation
    CPU_RISC_V_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_out(data_out)
    );

    // Test sequence
    initial begin
        $display("========== Test Start ==========");
        
        // Reset sequence
        rst_n = 0;
        #20;
        rst_n = 1;
        #10;
        
        // Add your test cases here
        
        // End simulation
        #1000;
        $display("========== Test Completed ==========");
        $finish;
    end

    // Waveform dump (optional)
    initial begin
        $dumpfile("CPU_RISC_V_tb.vcd");
        $dumpvars(0, CPU_RISC_V_tb);
    end

endmodule
