`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 04/13/2026
// Module Name: Permutation_tb
// Project Name: Ascon_128
// Description: Testbench for Round-based Ascon Permutation (p12, p8 and p6)
//////////////////////////////////////////////////////////////////////////////////

module Permutation_tb;

    // Check task 
    task automatic check(input string msg, input logic cond);
        if (cond) begin
            $display("[PASS] %s", msg);
        end
        else begin
            $display("[FAIL] %s", msg);
        end
    endtask;

    logic clk;
    logic rst_n;
    logic start;
    logic [3:0] rounds; //  12, 8, 6
    logic [0:4][63:0] data_in;
    
    logic [0:4][63:0] data_out;
    logic done;

    Permutation uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .num_rounds(rounds),
        .x_in(data_in),
        .x_out(data_out),
        .done(done)
    );

    // 100MHz
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        start = 0;
        rounds = 0;
        data_in = '{default:64'h0};

        // Reset 
        #20;
        rst_n = 1;
        #10;
        
        // ====================================================================
        $display("\n── TC1: Permutation 12 rounds (p12) - All Zero ──");
        data_in = '{default:64'h0};
        rounds = 12;
                
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait FSM done 
        wait(done == 1'b1);
        @(posedge clk); // wait 1 clock
        
        check("TC1: p12 all zero", (
            data_out[0] == 64'h78ea7ae5cfebb108 && 
            data_out[1] == 64'h9b9bfb8513b560f7 && 
            data_out[2] == 64'h6937f83e03d11a50 && 
            data_out[3] == 64'h3fe53f36f2c1178c && 
            data_out[4] == 64'h045d648e4def12c9
        ));


        // ====================================================================
        #30;
        $display("\n── TC2: Permutation 6 rounds (p6) - Custom Data ──");
        data_in[0] = 64'h0123456789ABCDEF;
        data_in[1] = 64'hFEDCBA9876543210;
        data_in[2] = 64'h0F0F0F0F0F0F0F0F;
        data_in[3] = 64'hF0F0F0F0F0F0F0F0;
        data_in[4] = 64'hAAAAAAAA55555555;
        rounds  = 6;

        // Start FSM
        @(posedge clk);
        start <= 1;
        @(posedge clk);
        start <= 0;

        // Wait FSM
        wait(done == 1'b1);
        @(posedge clk);
        
        check("TC2: p6 custom data", (
            data_out[0] == 64'h4493ad8599091b99 && 
            data_out[1] == 64'h49553bdcbd4728d7 && 
            data_out[2] == 64'h908012e460fbdb36 && 
            data_out[3] == 64'h651707b848a572e3 && 
            data_out[4] == 64'h2976d2e74ece679e
        ));

        // ====================================================================
        #30;
        $display("\n── TC3: Permutation 8 rounds (p8) ── Custom Data");
        data_in[0] = 64'h0000000000000000;
        data_in[1] = 64'h1111111111111111;
        data_in[2] = 64'h2222222222222222;
        data_in[3] = 64'h3333333333333333;
        data_in[4] = 64'h4444444444444444;
        rounds  = 8;
        
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1'b1);
        @(posedge clk);
        
        check("TC3: p8 custom data", (
            data_out[0] == 64'h529f187a67a009fa && 
            data_out[1] == 64'h7102c1700118db19 && 
            data_out[2] == 64'habdc3943a9ae321d && 
            data_out[3] == 64'h65af90baad91853c && 
            data_out[4] == 64'he8c57c42523e020e
        ));

        #50;
        $finish;
    end

endmodule