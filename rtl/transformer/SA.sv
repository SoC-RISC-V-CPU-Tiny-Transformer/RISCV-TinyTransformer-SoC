`timescale 1ns / 1ps

module SystolicArray #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter ARRAY_SIZE = 8
) (
    input logic clk,
    input logic rst_n,
    
    input logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] vec_in_a,
    input logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] vec_in_b,
    input logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_psum_in,

    input logic valid_in,
    input logic acc_clear,
    input logic ws_mode,
    input logic preload_w,
    input logic update_w,
    input logic [$clog2(ACC_WIDTH)-1:0] shift_amount,

    output logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_psum_out_skewed, // Partual sum output of PE array, skewed to add to FIFO
    output logic [ARRAY_SIZE-1:0] valid_out_skewed, // Valid signal for vec_psum_out_skewed

    output logic signed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][DATA_WIDTH-1:0] out_row_aligned,
    output logic [ARRAY_SIZE-1:0] valid_row_aligned,
    output logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_ws_out_aligned, // Final vector element result of MatMul, aligned to write back to SRAM
    output logic vec_ws_out_valid // Valid signal for vec_ws_out_aligned, only one bit for the whole vector since all elements are valid at the same time
);
    // --- INPUT SKEW BUFFERS ---
    logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] a_skewed;
    logic signed [ARRAY_SIZE-1:0][DATA_WIDTH-1:0] b_skewed;
    logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] psum_skewed;

    logic signed [ARRAY_SIZE-1:0][ACC_WIDTH-1:0] vec_psum_in_delayed;
    always_ff @(posedge clk) begin     
        vec_psum_in_delayed <= vec_psum_in;
    end

    logic [ARRAY_SIZE-1:0] valid_in_skewed ;
    logic [ARRAY_SIZE-1:0] acc_clear_skewed;
    logic [ARRAY_SIZE-1:0] preload_skewed;
    logic [ARRAY_SIZE-1:0] update_skewed;

    genvar i, j;
    generate
        for(i = 0; i < ARRAY_SIZE; i++) begin: skew
            if(i == 0) begin
                assign a_skewed[i] = vec_in_a[i];
                assign b_skewed[i] = vec_in_b[i];
                assign psum_skewed[i] = vec_psum_in_delayed[i];

                assign valid_in_skewed[i] = valid_in;
                assign acc_clear_skewed[i] = acc_clear;
                assign preload_skewed[i] = preload_w;
                assign update_skewed[i] = update_w;
            end
            else begin
                // Tạo shift register độ sâu i
                logic signed [i:1][DATA_WIDTH-1:0] a_delay;
                logic signed [i:1][DATA_WIDTH-1:0] b_delay;
                logic signed [i:1][ACC_WIDTH-1:0] psum_delay;

                logic [i:1] v_delay;
                logic [i:1] c_delay;
                logic [i:1] pre_delay;
                logic [i:1] upd_delay;

                always_ff @(posedge clk) begin
                    if(!rst_n) begin
                        a_delay <= '0;
                        b_delay <= '0;
                        psum_delay <= '0;

                        v_delay <= '0;
                        c_delay <= '0;
                        pre_delay <= '0;
                        upd_delay <= '0;
                    end
                    else begin
                        a_delay[1] <= vec_in_a[i];
                        b_delay[1] <= vec_in_b[i];
                        psum_delay[1] <= vec_psum_in_delayed[i];

                        v_delay[1] <= valid_in;
                        c_delay[1] <= acc_clear;
                        pre_delay[1] <= preload_w;
                        upd_delay[1] <= update_w;

                        for(int k = 2; k <= i; k++) begin
                            a_delay[k] <= a_delay[k-1];
                            b_delay[k] <= b_delay[k-1];
                            psum_delay[k] <= psum_delay[k-1];

                            v_delay[k] <= v_delay[k-1];
                            c_delay[k] <= c_delay[k-1];
                            pre_delay[k] <= pre_delay[k-1];
                            upd_delay[k] <= upd_delay[k-1];
                        end
                    end
                end

                assign a_skewed[i] = a_delay[i];
                assign b_skewed[i] = b_delay[i];
                assign psum_skewed[i] = psum_delay[i];

                assign valid_in_skewed[i] = v_delay[i];
                assign acc_clear_skewed[i] = c_delay[i];
                assign preload_skewed[i] = pre_delay[i];
                assign update_skewed[i] = upd_delay[i];
            end
        end
    endgenerate

    // --- PE Matrix ---
    logic signed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0][DATA_WIDTH-1:0] pe_out_matrix;
    logic [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0] pe_valid_matrix;

    logic signed [ARRAY_SIZE-1:0][ARRAY_SIZE:0][DATA_WIDTH-1:0] a_wire;
    logic signed [ARRAY_SIZE:0][ARRAY_SIZE-1:0][DATA_WIDTH-1:0] b_wire;
    logic signed [ARRAY_SIZE:0][ARRAY_SIZE-1:0][ACC_WIDTH-1:0] psum_wire;

    logic [ARRAY_SIZE-1:0][ARRAY_SIZE:0] v_wire;
    logic [ARRAY_SIZE-1:0][ARRAY_SIZE:0] c_wire;

    generate
        for(i = 0; i < ARRAY_SIZE; i++) begin
            assign a_wire[i][0] = a_skewed[i];
            assign b_wire[0][i] = b_skewed[i];
            assign psum_wire[0][i] = psum_skewed[i];

            assign v_wire[i][0] = valid_in_skewed[i];
            assign c_wire[i][0] = acc_clear_skewed[i];
        end
    endgenerate

    generate
        for(i = 0; i < ARRAY_SIZE; i++) begin: row
            for(j = 0; j < ARRAY_SIZE; j++) begin: col
                PE #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe (
                    .clk(clk), .rst_n(rst_n),
                    .valid_in(v_wire[i][j]), .acc_clear(c_wire[i][j]),
                    .shift_amount(shift_amount),
                    .ws_mode(ws_mode), .preload_w(preload_skewed[j]), .update_w(update_skewed[j]),
                    .in_a(a_wire[i][j]), .in_b(b_wire[i][j]),
                    .psum_in(psum_wire[i][j]),
                    .out_a(a_wire[i][j+1]), .out_b(b_wire[i+1][j]),
                    .psum_out(psum_wire[i+1][j]),
                    .out_valid_ctrl(v_wire[i][j+1]), .out_clear_ctrl(c_wire[i][j+1]),
                    .valid_out(pe_valid_matrix[i][j]), .pe_out(pe_out_matrix[i][j])
                );
            end
        end
    endgenerate

    // --- OUTPUT ALIGNMENT - OS MODE ---
    // Tín hiệu valid_out của cột j bị trễ j chu kỳ so với cột 0
    // Để ghi vào SRAM nguyên 1 hàng, cần làm trễ cột j thêm (ARRAY_SIZE - 1 - j) chu kỳ
    generate
        for(i = 0; i < ARRAY_SIZE; i++) begin: out_row
            for(j = 0; j < ARRAY_SIZE; j++) begin: out_col
                localparam DELAY_CYCLES = ARRAY_SIZE - 1 - j;

                if(DELAY_CYCLES == 0) begin
                    assign out_row_aligned[i][j] = pe_out_matrix[i][j];
                    assign valid_row_aligned[i] = pe_valid_matrix[i][j];
                end
                else begin
                    logic signed [DELAY_CYCLES:1][DATA_WIDTH-1:0] out_delay;

                    always_ff @(posedge clk) begin
                        out_delay[1] <= pe_out_matrix[i][j];
                        
                        for(int k = 2; k <= DELAY_CYCLES; k++) begin
                            out_delay[k] <= out_delay[k-1];
                        end
                    end

                    assign out_row_aligned[i][j] = out_delay[DELAY_CYCLES];
                end
            end
        end
    endgenerate
    
    // --- OUTPUT ALIGNMENT - WS MODE ---
    generate 
        for(j = 0; j < ARRAY_SIZE; j++) begin: out_ws_col
            assign vec_psum_out_skewed[j] = psum_wire[ARRAY_SIZE][j]; // Partial sum output của hàng cuối cùng, skewed để add vào FIFO
            assign valid_out_skewed[j] = pe_valid_matrix[ARRAY_SIZE-1][j]; // Tín hiệu valid ở chế độ ws của PE mỗi khi Mul + Acc xong

            localparam DELAY_CYCLES = ARRAY_SIZE - 1 - j;
            if(DELAY_CYCLES == 0) begin
                assign vec_ws_out_aligned[j] = psum_wire[ARRAY_SIZE][j];
                assign vec_ws_out_valid = pe_valid_matrix[ARRAY_SIZE-1][j];
            end
            else begin
                logic signed [DELAY_CYCLES:1][ACC_WIDTH-1:0] psum_delay;
                
                always_ff @(posedge clk) begin
                    psum_delay[1] <= psum_wire[ARRAY_SIZE][j];

                    for(int k = 2; k <= DELAY_CYCLES; k++) begin
                        psum_delay[k] <= psum_delay[k-1];
                    end
                end

                assign vec_ws_out_aligned[j] = psum_delay[DELAY_CYCLES];
            end
        end
    endgenerate

endmodule