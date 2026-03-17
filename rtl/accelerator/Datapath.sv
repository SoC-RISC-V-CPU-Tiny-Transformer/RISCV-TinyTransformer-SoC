`timescale 1ns / 1ps

module Datapath #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter ARRAY_SIZE = 4,
    parameter ADDR_WIDTH = 10,
    parameter ROW_WIDTH = 2
) (
    input logic clk,
    input logic rst_n,

    // --- CÁC TÍN HIỆU ĐIỀU KHIỂN TỪ FSM (Controller) ---
    // 1. Điều khiển input X và residual
    input logic residual_we,
    input logic [ADDR_WIDTH-1:0] residual_waddr,
    input logic [ADDR_WIDTH-1:0] residual_raddr,

    // 2. Điều khiển weight W với DMA (Ping-Pong 2 sram)
    input logic w_a_we, w_b_we,
    input logic [ADDR_WIDTH-1:0] w_a_waddr, w_b_waddr,
    input logic [ADDR_WIDTH-1:0] w_a_raddr, w_b_raddr,

    // 3. Điều khiển workinng buffers
    input logic [3:0] buf_we,
    input logic [ADDR_WIDTH-1:0] buf_waddr [0:3],
    input logic [ADDR_WIDTH-1:0] buf_raddr [0:3],

    // 4. MUX điều khiển input cho MMU
    input logic [2:0] mux_sel_mmu_in_a,
    input logic [2:0] mux_sel_mmu_in_b,

    // 5. Điều khiển MMU và Transpose
    input logic mmu_valid_in, mmu_clear_acc,
    input logic [2:0] mmu_shift_amount,
    input logic [ROW_WIDTH-1:0] mmu_out_row_idx,
    input logic trans_load_en,
    input logic sel_trans_buf,
    input logic [ROW_WIDTH-1:0] trans_row_idx, trans_col_idx,
    input logic mux_sel_buf_wdata, // 0 = Ghi thẳng từ MMU, 1 = Ghi từ Transpose Buffer

    // --- DỮ LIỆU ĐƯỢC TRUYỀN TỪ RAM VÀO THÔNG QUA BUS ---
    input logic [DATA_WIDTH-1:0] ext_wdata [ARRAY_SIZE-1:0],
    output logic mmu_valid_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0]
);
    // --- KHỞI TẠO BỘ NHỚ CHO DỮ LIỆU ĐẦU VÀO X VÀ RESIDUAL ---
    logic signed [DATA_WIDTH-1:0] residual_rdata [ARRAY_SIZE-1:0];
    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_residual (
        .clk(clk),
        .we(residual_we), .waddr(residual_waddr), .wdata(ext_wdata), // Ghi dữ liệu từ ngoài vào sram_input
        .re(1'b1), .raddr(residual_raddr), .rdata(residual_rdata)
    );

    // --- KHỞI TẠO BỘ NHỚ CHO 2 SRAM PING-PONG ---
    logic signed [DATA_WIDTH-1:0] w_a_rdata [ARRAY_SIZE-1:0];
    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_w_a (
        .clk(clk),
        .we(w_a_we), .waddr(w_a_waddr), .wdata(ext_wdata), // Ghi dữ liệu từ ngoài vào
        .re(1'b1), .raddr(w_a_raddr), .rdata(w_a_rdata)
    );

    logic signed [DATA_WIDTH-1:0] w_b_rdata [ARRAY_SIZE-1:0];
    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_w_b (
        .clk(clk),
        .we(w_b_we), .waddr(w_b_waddr), .wdata(ext_wdata), // Ghi dữ liệu từ ngoài vào
        .re(1'b1), .raddr(w_b_raddr), .rdata(w_b_rdata)
    );

    // --- KHỞI TẠO BỘ NHỚ CHO WORKING BUFFERS (B0, B1, B2, B3) ---
    logic signed [DATA_WIDTH-1:0] common_wdata [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] buf_rdata [0:3][ARRAY_SIZE-1:0];
    genvar i;
    generate
        for(i = 0; i < 4; i++) begin: working_buffers
            VectorSRAM #(
            .DATA_WIDTH(DATA_WIDTH),
            .ARRAY_SIZE(ARRAY_SIZE),
            .ADDR_WIDTH(ADDR_WIDTH)
            ) sram_buf (
                .clk(clk),
                .we(buf_we[i]), .waddr(buf_waddr[i]), .wdata(common_wdata),
                .re(1'b1), .raddr(buf_raddr[i]), .rdata(buf_rdata[i])
            );
        end
    endgenerate

    // --- CHỌN LUỒNG DỮ LIỆU ĐẦU VÀO CHO MMU ---
    logic signed [DATA_WIDTH-1:0] mmu_in_a [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] mmu_in_b [ARRAY_SIZE-1:0];
    always_comb begin
        case (mux_sel_mmu_in_a)
            3'd0: mmu_in_a = residual_rdata; // Đọc input gốc
            3'd1: mmu_in_a = buf_rdata[0]; // Đọc B0
            3'd2: mmu_in_a = buf_rdata[1]; // Đọc B1
            3'd3: mmu_in_a = buf_rdata[2]; // Đọc B2
            3'd4: mmu_in_a = buf_rdata[3]; // Đọc B3
            default: for(int j = 0; j < ARRAY_SIZE; j++) mmu_in_a[j] = '0;
        endcase
    end

    always_comb begin
        case (mux_sel_mmu_in_b)
            3'd0: mmu_in_b = w_a_rdata; // Trọng số Bank A
            3'd1: mmu_in_b = w_b_rdata; // Trọng số Bank B
            3'd2: mmu_in_b = buf_rdata[0]; // Đọc B0
            3'd3: mmu_in_b = buf_rdata[1]; // Đọc B1
            3'd4: mmu_in_b = buf_rdata[2]; // Đọc B2
            3'd5: mmu_in_b = buf_rdata[3]; // Đọc B3
            default: for(int j = 0; j < ARRAY_SIZE; j++) mmu_in_b[j] = '0;
        endcase
    end

    // --- LÕI MMU ---
    logic signed [DATA_WIDTH-1:0] mmu_out_matrix [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    MatrixMultUnit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) mmu (
        .clk(clk), .rst_n(rst_n),
        .valid_in(mmu_valid_in), .clear_acc(mmu_clear_acc), .shift_amount(mmu_shift_amount),
        .in_a(mmu_in_a), .in_b(mmu_in_b),
        .out_matrix(mmu_out_matrix), .valid_out(mmu_valid_out)
    );

    // Trích xuất 1 hàng từ MMU
    logic signed [DATA_WIDTH-1:0] mmu_out_row [ARRAY_SIZE-1:0];
    always_comb begin
        for(int k = 0; k < ARRAY_SIZE; k++) begin
            mmu_out_row[k] = mmu_out_matrix[mmu_out_row_idx][k];
        end
    end

    // --- TRANSPOSE BUFFER & GHI RA WORKING BUFFERS ---
    logic signed [DATA_WIDTH-1:0] trans_buf_out_0 [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] trans_buf_out_1 [ARRAY_SIZE-1:0];

    TransposeBuffer #(
        .DATA_WIDTH(DATA_WIDTH), .ARRAY_SIZE(ARRAY_SIZE)
    ) trans_buf_0 (
        .clk(clk), .rst_n(rst_n),
        .trans_load_en(trans_load_en && (sel_trans_buf == 1'b0)), 
        .trans_row_idx(trans_row_idx), .trans_col_idx(trans_col_idx),
        .data_in(mmu_out_row),
        .data_out(trans_buf_out_0)
    );

    TransposeBuffer #(
        .DATA_WIDTH(DATA_WIDTH), .ARRAY_SIZE(ARRAY_SIZE)
    ) trans_buf_1 (
        .clk(clk), .rst_n(rst_n),
        .trans_load_en(trans_load_en && (sel_trans_buf == 1'b1)), 
        .trans_row_idx(trans_row_idx), .trans_col_idx(trans_col_idx),
        .data_in(mmu_out_row),
        .data_out(trans_buf_out_1)
    );

    // MUX quyết định cái gì sẽ được ghi vào 4 Working Buffers
    always_comb begin
        if (mux_sel_buf_wdata) begin
            if(sel_trans_buf == 1'b0) common_wdata = trans_buf_out_1; // Ghi ma trận lật K^T
            else common_wdata = trans_buf_out_0;
        end
        else 
            common_wdata = mmu_out_row;   // Ghi ma trận Q, V, Score bình thường
    end

endmodule
