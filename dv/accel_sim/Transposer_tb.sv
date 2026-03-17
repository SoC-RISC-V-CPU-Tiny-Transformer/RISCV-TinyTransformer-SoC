`timescale 1ns/1ps

module Transposer_tb();

    parameter DATA_WIDTH = 8;
    parameter ARRAY_SIZE = 4;

    logic                                  clk;
    logic                                  rst_n;
    logic                                  load_en;
    logic [$clog2(ARRAY_SIZE)-1:0]         row_idx;
    logic [$clog2(ARRAY_SIZE)-1:0]         col_idx;
    
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] data_in;
    logic [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] data_out;

    // Instantiate DUT
    TransposeBuffer #(
        .DATA_WIDTH(DATA_WIDTH), 
        .ARRAY_SIZE(ARRAY_SIZE)
    ) dut (
        .clk(clk), 
        .rst_n(rst_n),
        .load_en(load_en), 
        .row_idx(row_idx), 
        .col_idx(col_idx),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Clock (Cycle 10ns -> 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    initial begin
        rst_n   = 0;
        load_en = 0;
        row_idx = 0;
        col_idx = 0;
        data_in = '0;

        // Reset inactive
        #15;
        rst_n = 1;
        #10;

        $display("==============================");
        $display("============ START ===========");
        $display("==============================");
        @(posedge clk);
        load_en = 1; row_idx = 0;
        data_in[0] = 8'd1; data_in[1] = 8'd2; data_in[2] = 8'd3; data_in[3] = 8'd4;
        $display("ROW 0: %3d  %3d  %3d  %3d", data_in[0], data_in[1], data_in[2], data_in[3]);

        @(posedge clk);
        row_idx = 1;
        data_in[0] = 8'd5; data_in[1] = 8'd6; data_in[2] = 8'd7; data_in[3] = 8'd8;
        $display("ROW 1: %3d  %3d  %3d  %3d", data_in[0], data_in[1], data_in[2], data_in[3]);

        @(posedge clk);
        row_idx = 2;
        data_in[0] = 8'd9; data_in[1] = 8'd10; data_in[2] = 8'd11; data_in[3] = 8'd12;
        $display("ROW 2: %3d  %3d  %3d  %3d", data_in[0], data_in[1], data_in[2], data_in[3]);

        @(posedge clk);
        row_idx = 3;
        data_in[0] = 8'd13; data_in[1] = 8'd14; data_in[2] = 8'd15; data_in[3] = 8'd16;
        $display("ROW 3: %3d  %3d  %3d  %3d", data_in[0], data_in[1], data_in[2], data_in[3]);

        // Stop write
        @(posedge clk);
        load_en = 0;

        $display("\n==============================");
        $display("=== OUTOUT TRANSPOSED DATA ===");
        $display("==============================");

        for (int i = 0; i < ARRAY_SIZE; i++) begin
            @(posedge clk);
            col_idx = i;
            
            // Wait (#1) 
            #1; 
            $display("Column  %0d: %3d  %3d  %3d  %3d", col_idx, data_out[0], data_out[1], data_out[2], data_out[3]);
        end

        #20;
        $display("\n==============================");
        $display("============ DONE ============");
        $display("==============================");
        $finish;
    end

endmodule