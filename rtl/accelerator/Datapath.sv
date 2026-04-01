`timescale 1ns / 1ps

module Datapath #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter ARRAY_SIZE = 8,
    parameter MAT_SIZE = 64,
    parameter ADDR_WIDTH = 9,
    parameter NUM_HEADS = 2
) (
    input logic clk,
    input logic rst_n,

    input logic start_matmul,
    input logic transpose_mode,
    input logic [$clog2(ACC_WIDTH)-1:0] shift_amount,
    input logic multi_head,

    // MUX ĐẦU VÀO: 0=SRAM_X, 1=SRAM_0, 2=SRAM_1, 3=SRAM_2, 4=SRAM_3
    input logic [2:0] sel_in_a, sel_in_b,
    
    // DEMUX ĐẦU RA
    input logic we_sram_x, we_sram_0, we_sram_1, we_sram_2, we_sram_3,

    output logic stage_done
);
    localparam NUM_BLOCKS = MAT_SIZE / ARRAY_SIZE;

    // ==========================================
    // CHOOSE IN_A AND IN_B FROM SRAM
    // ==========================================
    logic signed [DATA_WIDTH-1:0] rdata_x [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] rdata_0 [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] rdata_1 [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] rdata_2 [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] rdata_3 [ARRAY_SIZE-1:0];

    logic signed [DATA_WIDTH-1:0] matmul_in_a [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] matmul_in_b [ARRAY_SIZE-1:0];

    always_comb begin
        case(sel_in_a) 
            3'd0: matmul_in_a = rdata_x;
            3'd1: matmul_in_a = rdata_0;
            3'd2: matmul_in_a = rdata_1;
            3'd3: matmul_in_a = rdata_2;
            3'd4: matmul_in_a = rdata_3;
            default: matmul_in_a = '{default: '0};
        endcase

        case(sel_in_b) 
            3'd0: matmul_in_b = rdata_x;
            3'd1: matmul_in_b = rdata_0;
            3'd2: matmul_in_b = rdata_1;
            3'd3: matmul_in_b = rdata_2;
            3'd4: matmul_in_b = rdata_3;
            default: matmul_in_b = '{default: '0};
        endcase
    end

    // ==========================================
    // MATRIX MULTIPLIER
    // ==========================================
    logic read_req_a, read_req_b;
    logic [ADDR_WIDTH-1:0] read_addr_a, read_addr_b;

    logic matmul_valid_out;
    logic [$clog2(ARRAY_SIZE)-1:0] matmul_out_row_idx;
    logic signed [DATA_WIDTH-1:0] matmul_out_data [ARRAY_SIZE-1:0];
    logic [$clog2(ARRAY_SIZE)-1:0] matmul_out_br, matmul_out_bc;

    MatMul #(
        .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE), .MAT_SIZE(MAT_SIZE), .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_HEADS(NUM_HEADS)
    ) matmul_core (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_matmul),
        .transpose_mode(transpose_mode),
        .shift_amount(shift_amount),
        .multi_head(multi_head),
        .done(),
        .read_req_a(read_req_a), .read_addr_a(read_addr_a), .read_data_a(matmul_in_a),
        .read_req_b(read_req_b), .read_addr_b(read_addr_b), .read_data_b(matmul_in_b),
        .valid_out(matmul_valid_out),
        .out_row_idx(matmul_out_row_idx),
        .out_data(matmul_out_data),
        .out_br(matmul_out_br),
        .out_bc(matmul_out_bc)
    );

    // ==========================================
    // SRAM READ ENABLE SIGNAL
    // ==========================================
    logic re_sram_x, re_sram_0, re_sram_1, re_sram_2, re_sram_3;
    logic [ADDR_WIDTH-1:0] raddr_x, raddr_0, raddr_1, raddr_2, raddr_3;

    always_comb begin
        re_sram_x = 0; re_sram_0 = 0; re_sram_1 = 0; re_sram_2 = 0; re_sram_3 = 0;
        raddr_x = '0; raddr_0 = '0; raddr_1 = '0; raddr_2 = '0; raddr_3 = '0;

        if(read_req_a) begin
            case(sel_in_a)
                3'd0: begin
                    re_sram_x = 1;
                    raddr_x = read_addr_a;
                end
                3'd1: begin
                    re_sram_0 = 1;
                    raddr_0 = read_addr_a;
                end
                3'd2: begin
                    re_sram_1 = 1;
                    raddr_1 = read_addr_a;
                end
                3'd3: begin
                    re_sram_2 = 1;
                    raddr_2 = read_addr_a;
                end
                3'd4: begin
                    re_sram_3 = 1;
                    raddr_3 = read_addr_a;
                end
            endcase
        end

        if(read_req_b) begin
            case(sel_in_b)
                3'd0: begin
                    re_sram_x = 1;
                    raddr_x = read_addr_b;
                end
                3'd1: begin
                    re_sram_0 = 1;
                    raddr_0 = read_addr_b;
                end
                3'd2: begin
                    re_sram_1 = 1;
                    raddr_1 = read_addr_b;
                end
                3'd3: begin
                    re_sram_2 = 1;
                    raddr_2 = read_addr_b;
                end
                3'd4: begin
                    re_sram_3 = 1;
                    raddr_3 = read_addr_b;
                end
            endcase
        end
    end

    // ==========================================
    // TRANSPOSER
    // ==========================================
    logic [$clog2(ARRAY_SIZE)-1:0] trans_out_br, trans_out_bc;
    logic trans_valid_out;
    logic [$clog2(ARRAY_SIZE)-1:0] trans_col_idx;
    logic signed [DATA_WIDTH-1:0] trans_col_data [ARRAY_SIZE-1:0];

    Transposer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .MAT_SIZE(MAT_SIZE)
    ) transposer_core (
        .clk(clk), .rst_n(rst_n),
        .valid_in(matmul_valid_out), .in_row_idx(matmul_out_row_idx), .in_row_data(matmul_out_data),
        .in_br(matmul_out_br), .in_bc(matmul_out_bc),
        .out_br(trans_out_br), .out_bc(trans_out_bc),
        .valid_out(trans_valid_out), .out_col_idx(trans_col_idx), .out_col_data(trans_col_data)
    );

    // ==========================================
    // SRAM WRITE ENABLE SIGNAL
    // ==========================================
    logic write_valid;
    logic [ADDR_WIDTH-1:0] waddr;
    logic signed [DATA_WIDTH-1:0] wdata [ARRAY_SIZE-1:0];
    always_comb begin
        if(transpose_mode) begin
            write_valid = trans_valid_out;
            waddr = (trans_out_bc * ARRAY_SIZE + trans_col_idx) * NUM_BLOCKS + trans_out_br;
            wdata = trans_col_data;
        end
        else begin
            write_valid = matmul_valid_out;
            waddr = (matmul_out_br * ARRAY_SIZE + matmul_out_row_idx) * NUM_BLOCKS + matmul_out_bc;
            wdata = matmul_out_data;
        end
    end

    // ==========================================
    // STAGE DONE
    // ==========================================
    logic [ADDR_WIDTH:0] write_counter;
    always_ff @(posedge clk) begin
        if(start_matmul)
            write_counter <= 0;
        else if(write_valid)
            write_counter <= write_counter + 1;
    end

    assign stage_done = write_valid && (write_counter == (MAT_SIZE * ARRAY_SIZE - 1));

    // ==========================================
    // INSTANTIATION SRAM
    // ==========================================
    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_x (
        .clk(clk),
        .we(write_valid && we_sram_x), .waddr(waddr), .wdata(wdata),
        .re(re_sram_x), .raddr(raddr_x), .rdata(rdata_x)
    );

    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_0 (
        .clk(clk),
        .we(write_valid && we_sram_0), .waddr(waddr), .wdata(wdata),
        .re(re_sram_0), .raddr(raddr_0), .rdata(rdata_0)
    );

    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_1 (
        .clk(clk),
        .we(write_valid && we_sram_1), .waddr(waddr), .wdata(wdata),
        .re(re_sram_1), .raddr(raddr_1), .rdata(rdata_1)
    );

        VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_2 (
        .clk(clk),
        .we(write_valid && we_sram_2), .waddr(waddr), .wdata(wdata),
        .re(re_sram_2), .raddr(raddr_2), .rdata(rdata_2)
    );

        VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_3 (
        .clk(clk),
        .we(write_valid && we_sram_3), .waddr(waddr), .wdata(wdata),
        .re(re_sram_3), .raddr(raddr_3), .rdata(rdata_3)
    );

endmodule