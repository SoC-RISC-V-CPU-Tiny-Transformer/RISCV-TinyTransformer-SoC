`timescale 1ns/1ps

module MAC_tb();

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;

    logic clk;
    logic rst_n;
    logic signed [DATA_WIDTH-1:0] in_a, in_b;
    logic valid_in;
    logic acc_clear;
    logic [$clog2(ACC_WIDTH)-1:0] shift_amount;

    logic signed [DATA_WIDTH-1:0] mac_out;
    logic valid_out;

    MAC #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .* // Tự động nối các port cùng tên
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        in_a = 0; in_b = 0;
        valid_in = 0; acc_clear = 0;
        shift_amount = 0; 
        
        @(negedge clk);
        @(negedge clk);
        rst_n = 1;

        $display("--- TEST CASE 1: Normal MAC ---");
        @(negedge clk);
        in_a = 10; in_b = 2; valid_in = 1; acc_clear = 1; shift_amount = 0;

        @(negedge clk);
        in_a = -5; in_b = 3; valid_in = 1; acc_clear = 0;

        @(negedge clk);
        in_a = 100; in_b = 2; valid_in = 0; 

        @(negedge clk);
        in_a = 0; in_b = 0; valid_in = 0; acc_clear = 1;
        
        @(negedge clk);
        acc_clear = 0;

        $display("--- TEST CASE 2: Shift and Saturation ---");
        @(negedge clk);
        in_a = 100; in_b = 10; valid_in = 1; acc_clear = 1; shift_amount = 3;
        
        @(negedge clk);
        in_a = 0; in_b = 0; valid_in = 0; acc_clear = 1; 

        @(negedge clk);
        acc_clear = 0;

        repeat(3) @(negedge clk);

        $display("--- TEST COMPLETED ---");
        $finish;
    end

    always_ff @(posedge clk) begin
        if (valid_out) begin
            $display("[Time: %0t] Output Validated: mac_out = %d", $time, mac_out);
        end
    end

endmodule