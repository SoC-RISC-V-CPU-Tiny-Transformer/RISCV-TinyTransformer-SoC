`timescale 1ns / 1ps

module PE_tb();

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;

    logic clk;
    logic rst_n;
    logic valid_in;
    logic clear_acc;
    logic [2:0] shift_amount;
    
    logic signed [DATA_WIDTH-1:0] in_a, in_b;
    logic signed [DATA_WIDTH-1:0] out_a, out_b;
    logic valid_out;
    logic signed [DATA_WIDTH-1:0] out_8bit;

    ProcessingElement #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .clear_acc(clear_acc),
        .shift_amount(shift_amount),
        .in_a(in_a),
        .in_b(in_b),
        .out_a(out_a),
        .out_b(out_b),
        .valid_out(valid_out),
        .out_8bit(out_8bit)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Kịch bản
    initial begin
        rst_n = 0;
        valid_in = 0;
        clear_acc = 0;
        shift_amount = 0;
        in_a = 0; in_b = 0;

        #20 rst_n = 1;
        #10;

        // Bắn dữ liệu Clock 1
        @(posedge clk);
        clear_acc <= 1; valid_in <= 1;
        in_a <= 8'd10; in_b <= 8'd2; // PE sẽ nhân 10x2=20
        
        // Bắn dữ liệu Clock 2
        @(posedge clk);
        clear_acc <= 0;
        in_a <= 8'd5; in_b <= 8'd4; // PE nhân 5x4=20, cộng dồn thành 40
        
        // Ngưng cấp
        @(posedge clk);
        valid_in <= 0;

        repeat(5) @(posedge clk);
        $finish;
    end

endmodule