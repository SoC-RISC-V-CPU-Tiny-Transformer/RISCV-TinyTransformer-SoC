`timescale 1ns / 1ps

module ProcessingElement #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
) (
    input  logic                         clk,
    input  logic                         rst_n,
    
    input  logic                         valid_in,
    input  logic                         clear_acc,
    input  logic [2:0]                   shift_amount,
    
    // --- DỮ LIỆU NHẬN VÀO (Từ hàng xóm phía Trên và Bên Trái) ---
    input  logic signed [DATA_WIDTH-1:0] in_a, // Dữ liệu X chảy từ Trái sang
    input  logic signed [DATA_WIDTH-1:0] in_b, // Truyền số W chảy từ Trên xuống
    
    // --- DỮ LIỆU TRUYỀN ĐI (Cho hàng xóm phía Dưới và Bên Phải) ---
    output logic signed [DATA_WIDTH-1:0] out_a, // Truyền X sang Phải
    output logic signed [DATA_WIDTH-1:0] out_b, // Truyền W xuống Dưới

    // --- TRUYỀN TÍN HIỆU ĐIỀU KHIỂN ---
    output logic out_valid_ctrl,
    output logic out_clear_ctrl,

    // --- KẾT QUẢ TÍNH TOÁN CỦA RIÊNG PE NÀY ---
    output logic                         valid_out,
    output logic signed [DATA_WIDTH-1:0] out_8bit
);
    // --- Initiate khối MAC ---
    MultAndAcc #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mac_inst (
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

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            out_a <= '0;
            out_b <= '0;
            out_valid_ctrl <= 1'b0;
            out_clear_ctrl <= 1'b0;
        end else begin
            // Bất kể MAC làm gì, hễ có Clock là PE copy dữ liệu đầu vào 
            // đẩy ra cửa đầu ra để chuẩn bị cho hàng xóm ở chu kỳ sau.
            out_a <= in_a;
            out_b <= in_b;
            out_valid_ctrl <= valid_in;
            out_clear_ctrl <= clear_acc;
        end
    end

endmodule