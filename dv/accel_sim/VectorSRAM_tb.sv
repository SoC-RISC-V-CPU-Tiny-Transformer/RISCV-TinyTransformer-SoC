`timescale 1ns / 1ps

module VectorSRAM_tb();

    localparam DATA_WIDTH = 8;
    localparam ARRAY_SIZE = 4;
    localparam ADDR_WIDTH = 10;

    logic clk;
    logic we;
    logic [ADDR_WIDTH-1:0] waddr;
    logic signed [DATA_WIDTH-1:0] wdata [ARRAY_SIZE-1:0];

    logic re;
    logic [ADDR_WIDTH-1:0] raddr;
    logic signed [DATA_WIDTH-1:0] rdata [ARRAY_SIZE-1:0];

    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .re(re),
        .raddr(raddr),
        .rdata(rdata)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- Kịch bản Test ---
    initial begin
        we = 0;
        re = 0;
        waddr = 0;
        raddr = 0;
        for(int i=0; i<ARRAY_SIZE; i++) wdata[i] = 0;

        $display("--- Bat dau Test VectorSRAM ---");
        #20;

        // --- TEST 1: Ghi du lieu vao dia chi 10 ---
        @(posedge clk);
        we = 1;
        waddr = 10'd10;
        wdata = '{0: 8'd11, 1: 8'd22, 2: 8'd33, 3: 8'd44}; // Nap vector test
        @(posedge clk);
        we = 0;
        $display("[Time %t] Da ghi vao dia chi 10: {11, 22, 33, 44}", $time);

        // --- TEST 2: Doc du lieu tu dia chi 10 ---
        @(posedge clk);
        re = 1;
        raddr = 10'd10;
        @(posedge clk);
        #1; // Doi mot chut de du lieu ra on dinh
        $display("[Time %t] Doc tu dia chi 10: {%d, %d, %d, %d}", 
                 $time, rdata[0], rdata[1], rdata[2], rdata[3]);
        
        // Kiem tra ket qua
        if (rdata[0] == 8'd11 && rdata[3] == 8'd44) 
            $display("=> TEST 2: THANH CONG");
        else 
            $display("=> TEST 2: THAT BAI!");

        // --- TEST 3: Kiem tra Write-First (Ghi va Doc cung luc tai dia chi 50) ---
        @(posedge clk);
        we = 1;
        re = 1;
        waddr = 10'd50;
        raddr = 10'd50;
        wdata = '{0: 8'd10, 1: 8'd20, 2: 8'd30, 3: 8'd40};
        
        @(posedge clk);
        #1;
        $display("[Time %t] Write-First Test tai dia chi 50: {%d, %d, %d, %d}", 
                 $time, rdata[0], rdata[1], rdata[2], rdata[3]);
        
        if (rdata[0] == 8'd10) 
            $display("=> TEST 3 (Write-First): THANH CONG (Lay duoc du lieu moi)");
        else 
            $display("=> TEST 3 (Write-First): THAT BAI (Bi lay du lieu cu)");

        we = 0;
        re = 0;

        #50;
        $display("--- Ket thuc Test ---");
        $finish;
    end

endmodule