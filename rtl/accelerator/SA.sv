`timescale 1ns / 1ps

module SystolicArray #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter ARRAY_SIZE = 4
) (
    input logic clk,
    input logic rst_n,
    input logic valid_in,
    input logic clear_acc,
    input logic [2:0] shift_amount,

    input logic signed [DATA_WIDTH-1:0] in_a [ARRAY_SIZE-1:0], // Mảng một chiều chứa ARRAY_SIZE giá trị x bơm vào lề trái
    input logic signed [DATA_WIDTH-1:0] in_b [ARRAY_SIZE-1:0], // Mảng một chiều chứa ARRAY_SIZE giá trị w bơm vào lề trái

    output logic [DATA_WIDTH-1:0] out_matrix [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0], // Mảng hai chiều chứa ARRAY_SIZE x ARRAY_SIZE kết quả của các PE
    output logic valid_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0]
);
    // --- Khai báo mạng lưới dây nối dữ liệu ---
    logic signed [DATA_WIDTH-1:0] wire_a [ARRAY_SIZE-1:0][ARRAY_SIZE:0];
    logic signed [DATA_WIDTH-1:0] wire_b [ARRAY_SIZE:0][ARRAY_SIZE-1:0];

    // --- Mạng lưới dây nối tín hiệu điều khiển truyền ngang ---
    logic wire_valid [ARRAY_SIZE-1:0][ARRAY_SIZE:0];
    logic wire_clear [ARRAY_SIZE-1:0][ARRAY_SIZE:0];

    genvar i, j;
    // --- Skewing cho tín hiệu điều khiển ở mép trái ---
    generate
        for(i = 0; i < ARRAY_SIZE; i++) begin: ctrl_skew_dege
            if(i == 0) begin
                assign wire_valid[i][0] = valid_in;
                assign wire_clear[i][0] = clear_acc;
            end
            else begin
                logic valid_shift [i-1:0];
                logic clear_shift [i-1:0];
                always_ff @(posedge clk) begin
                    if(!rst_n) begin
                        for(int k = 0; k < i; k++) begin
                            valid_shift[k] <= 1'b0;
                            clear_shift[k] <= 1'b0;
                        end
                    end
                    else begin
                        valid_shift[0] <= valid_in;
                        clear_shift[0] <= clear_acc;
                        for(int k = 1; k < i; k++) begin
                            valid_shift[k] <= valid_shift[k-1];
                            clear_shift[k] <= clear_shift[k-1];
                        end
                    end
                end

                assign wire_valid[i][0] = valid_shift[i-1];
                assign wire_clear[i][0] = clear_shift[i-1];
            end
        end
    endgenerate

    // --- Nối dữ liệu đầu vào vào rìa mạng lưới ---

    generate
        for(i = 0; i < ARRAY_SIZE; i++) begin: init_edges
            assign wire_a[i][0] = in_a[i];
            assign wire_b[0][i] = in_b[i];
        end
    endgenerate

    // --- Kết nối các PE ---
    generate 
        for(i = 0; i < ARRAY_SIZE; i++) begin: row
            for(j = 0; j < ARRAY_SIZE; j++) begin: col
                ProcessingElement #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe(
                    .clk(clk),
                    .rst_n(rst_n),
                    .valid_in(wire_valid[i][j]),
                    .clear_acc(wire_clear[i][j]),
                    .shift_amount(shift_amount),

                    // Nhận dữ liệu từ PE bên trái và bên trên
                    .in_a(wire_a[i][j]),
                    .in_b(wire_b[i][j]),

                    // Truyền tín hiệu điều khiển sang bên phải
                    .out_valid_ctrl(wire_valid[i][j+1]),
                    .out_clear_ctrl(wire_clear[i][j+1]),

                    // Truyền dữ liệu sang PE bên phải và bên dưới
                    .out_a(wire_a[i][j+1]),
                    .out_b(wire_b[i+1][j]),
                    
                    // Kết quả tích lũy tại PE hiện tại
                    .out_8bit(out_matrix[i][j]),
                    .valid_out(valid_out[i][j])
                );
            end
        end
    endgenerate

endmodule