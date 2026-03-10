`timescale 1ns / 1ps

module MAC_tb();

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;

    // Khai báo các tín hiệu kết nối với module MAC
    logic                         clk;
    logic                         rst_n;
    logic                         valid_in;
    logic                         clear_acc;
    logic [2:0]                   shift_amount;
    logic signed [DATA_WIDTH-1:0] in_a;
    logic signed [DATA_WIDTH-1:0] in_b;
    
    logic                         valid_out;
    logic signed [DATA_WIDTH-1:0] out_8bit;

    // Khởi tạo thực thể (Instantiate) khối MAC cần test
    MAC #(
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
        .valid_out(valid_out),
        .out_8bit(out_8bit)
    );

    // Tạo xung nhịp Clock (Chu kỳ 10ns -> Tần số 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // Kịch bản kiểm thử
    initial begin
        rst_n = 0;
        valid_in = 0;
        clear_acc = 0;
        shift_amount = 3'd0;
        in_a = 0;
        in_b = 0;

        // Chờ 20ns rồi tắt Reset
        #20;
        rst_n = 1;
        #10;

        $display("========== BAT DAU MO PHONG ==========");

        // ---------------------------------------------------------
        // KỊCH BẢN 1: Cộng dồn 3 phép nhân liên tiếp
        // ---------------------------------------------------------
        $display("[Time: %0t] Kich ban 1: Cong don binh thuong", $time);
        
        // Nhịp Clock 1: Bắn dữ liệu đầu tiên và cờ Clear
        @(posedge clk);
        clear_acc = 1;      // Báo hiệu bắt đầu 1 mảng mới
        valid_in = 1;
        shift_amount = 3'd0; // Chưa dịch bit vội
        in_a = 8'd10; in_b = 8'd2; // Tích = 20

        // Nhịp Clock 2: Bắn dữ liệu thứ 2, tắt cờ Clear
        @(posedge clk);
        clear_acc = 0;
        in_a = 8'd5; in_b = 8'd4;  // Tích = 20 (Cộng dồn kì vọng: 20 + 20 = 40)

        // Nhịp Clock 3: Bắn dữ liệu thứ 3
        @(posedge clk);
        in_a = 8'd10; in_b = 8'd10; // Tích = 100 (Cộng dồn kì vọng: 40 + 100 = 140)

        // Nhịp Clock 4: Ngưng cấp dữ liệu
        @(posedge clk);
        valid_in = 0;

        // Chờ pipeline xử lý xong
        repeat(4) @(posedge clk);

        // ---------------------------------------------------------
        // KỊCH BẢN 2: Kiểm tra lỗi Edge Case (Clear lúc rảnh rỗi)
        // ---------------------------------------------------------
        $display("\n[Time: %0t] Kich ban 2: Clear luc valid_in = 0", $time);
        @(posedge clk);
        clear_acc = 1;      // Bật clear
        valid_in = 0;       // NHƯNG KHÔNG CÓ DỮ LIỆU
        in_a = 8'hFF; in_b = 8'hFF; // Bơm rác vào đường truyền

        @(posedge clk);
        clear_acc = 0;

        repeat(3) @(posedge clk);

        // ---------------------------------------------------------
        // KỊCH BẢN 3: Kiểm tra dịch bit động (Dynamic Shift) và Cắt xén (Saturation)
        // ---------------------------------------------------------
        $display("\n[Time: %0t] Kich ban 3: Dich bit va Saturation", $time);
        @(posedge clk);
        clear_acc = 1;
        valid_in = 1;
        shift_amount = 3'd2; // Dịch phải 2 bit (tức là chia cho 4)
        in_a = 8'd64; in_b = 8'd2; // Tích = 128. Sau khi dịch 2 bit kì vọng = 32.
        
        @(posedge clk);
        clear_acc = 0;
        valid_in = 0;

        // Chờ xem kết quả trạm cuối
        repeat(5) @(posedge clk);

        $display("========== KET THUC MO PHONG ==========");
        $finish;
    end

    // Giám sát kết quả đầu ra (Monitor)
    always @(posedge clk) begin
        if (valid_out) begin
            $display("-> [Ket qua tai %0t] valid_out = 1 | out_8bit = %d", $time, out_8bit);
        end
    end

endmodule
