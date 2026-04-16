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

    // MHA controll
    input logic multi_head,
    input logic [$clog2(NUM_HEADS)-1:0] head_idx,
    input logic start_softmax,
    input logic [3:0] sfm_q_frac,
    input logic start_transpose,
    input logic is_calc_z,

    input logic [2:0] sel_in_a, sel_in_b, // MUX ĐẦU VÀO: 0=SRAM_X, 1=SRAM_0, 2=SRAM_1, 3=SRAM_2, 4=SRAM_3, 5=SRAM_4
    input logic we_sram_x, we_sram_0, we_sram_1, we_sram_2, we_sram_3, we_sram_4, // DEMUX ĐẦU RA

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
    logic signed [DATA_WIDTH-1:0] rdata_4 [ARRAY_SIZE-1:0];

    logic signed [DATA_WIDTH-1:0] matmul_in_a [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] matmul_in_b [ARRAY_SIZE-1:0];

    always_comb begin
        case(sel_in_a) 
            3'd0: matmul_in_a = rdata_x;
            3'd1: matmul_in_a = rdata_0;
            3'd2: matmul_in_a = rdata_1;
            3'd3: matmul_in_a = rdata_2;
            3'd4: matmul_in_a = rdata_3;
            3'd5: matmul_in_a = rdata_4;
            default: matmul_in_a = '{default: '0};
        endcase

        case(sel_in_b) 
            3'd0: matmul_in_b = rdata_x;
            3'd1: matmul_in_b = rdata_0;
            3'd2: matmul_in_b = rdata_1;
            3'd3: matmul_in_b = rdata_2;
            3'd4: matmul_in_b = rdata_3;
            3'd5: matmul_in_b = rdata_4;
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
        .head_idx(head_idx),
        .is_calc_z(is_calc_z),
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
    // SOFTMAX
    // ==========================================
    logic sfm_read_req, sfm_write_req;
    logic [ADDR_WIDTH-1:0] sfm_read_addr, sfm_write_addr;
    logic signed [DATA_WIDTH-1:0] sfm_write_data [ARRAY_SIZE-1:0];
    //logic sfm_done;

    Softmax #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .MAT_SIZE(MAT_SIZE)
    ) softmax_core (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_softmax),
        .q_frac(sfm_q_frac),
        .done(),
        .read_req(sfm_read_req), .read_addr(sfm_read_addr), .read_data(rdata_1),
        .write_req(sfm_write_req), .write_addr(sfm_write_addr), .write_data(sfm_write_data)
    );

    // ==========================================
    // TRANSPOSER
    // ==========================================

    // FSM controll standalone transposer.
    logic tr_running;
    logic tr_valid_in;
    logic [$clog2(MAT_SIZE*MAT_SIZE/ARRAY_SIZE)-1:0] tr_counter;
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            tr_running <= 0;
            tr_counter <= 0;
        end
        else if(start_transpose) begin
            tr_running <= 1;
            tr_counter <= 0; 
        end
        else if(tr_valid_in) begin
            tr_counter <= tr_counter + 1;
            if(tr_counter == MAT_SIZE * ARRAY_SIZE - 1)
                tr_running <= 0;
        end
    end
    
    // Calculate Transposer signal.
    logic [$clog2(ARRAY_SIZE)-1:0] tr_row_idx;
    logic [$clog2(NUM_BLOCKS)-1:0] tr_br, tr_bc;
    logic tr_read_req;
    logic [ADDR_WIDTH-1:0] tr_read_addr;
    always_comb begin
        tr_row_idx = tr_counter % ARRAY_SIZE;
        tr_br = (tr_counter / ARRAY_SIZE) % NUM_BLOCKS;
        tr_bc = tr_counter / (NUM_BLOCKS * ARRAY_SIZE);
        tr_read_req = tr_running;
        tr_read_addr = (tr_br * ARRAY_SIZE + tr_row_idx) * NUM_BLOCKS + tr_bc;
    end
    
    // DELAY signal to wait SRAM reading.
    logic [$clog2(ARRAY_SIZE)-1:0] tr_row_idx_d;
    logic [$clog2(NUM_BLOCKS)-1:0] tr_br_d, tr_bc_d;
    always @(posedge clk) begin
        if(!rst_n) tr_valid_in <= 0;
        else tr_valid_in <= tr_running;

        tr_row_idx_d <= tr_row_idx;
        tr_br_d <= tr_br;
        tr_bc_d <= tr_bc;
    end
    
    // Transposer MUX
    logic tr_mux_valid_in;
    logic [$clog2(ARRAY_SIZE)-1:0] tr_mux_in_row_idx;
    logic signed [DATA_WIDTH-1:0] tr_mux_in_row_data [ARRAY_SIZE-1:0];
    logic [$clog2(NUM_BLOCKS)-1:0] tr_mux_in_br, tr_mux_in_bc;
    always_comb begin
        tr_mux_valid_in = tr_valid_in ? 1'b1 : (transpose_mode ? matmul_valid_out : 1'b0);
        tr_mux_in_row_idx = tr_valid_in ? tr_row_idx_d : matmul_out_row_idx;
        tr_mux_in_row_data = tr_valid_in ? rdata_2 : matmul_out_data;
        tr_mux_in_br = tr_valid_in ? tr_br_d : matmul_out_br;
        tr_mux_in_bc = tr_valid_in ? tr_bc_d : matmul_out_bc;
    end

    // Transposer output
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
        .valid_in(tr_mux_valid_in), .in_row_idx(tr_mux_in_row_idx), .in_row_data(tr_mux_in_row_data),
        .in_br(tr_mux_in_br), .in_bc(tr_mux_in_bc),
        .out_br(trans_out_br), .out_bc(trans_out_bc),
        .valid_out(trans_valid_out), .out_col_idx(trans_col_idx), .out_col_data(trans_col_data)
    );

    // ==========================================
    // SRAM READ ENABLE SIGNAL
    // ==========================================
    logic re_sram_x, re_sram_0, re_sram_1, re_sram_2, re_sram_3, re_sram_4;
    logic [ADDR_WIDTH-1:0] raddr_x, raddr_0, raddr_1, raddr_2, raddr_3, raddr_4;

    always_comb begin
        re_sram_x = 0; re_sram_0 = 0; re_sram_1 = 0; re_sram_2 = 0; re_sram_3 = 0; re_sram_4 = 0;
        raddr_x = '0; raddr_0 = '0; raddr_1 = '0; raddr_2 = '0; raddr_3 = '0; raddr_4 = '0;

        if(read_req_a) begin
            case(sel_in_a)
                3'd0: begin re_sram_x = 1; raddr_x = read_addr_a; end
                3'd1: begin re_sram_0 = 1; raddr_0 = read_addr_a; end
                3'd2: begin re_sram_1 = 1; raddr_1 = read_addr_a; end
                3'd3: begin re_sram_2 = 1; raddr_2 = read_addr_a; end
                3'd4: begin re_sram_3 = 1; raddr_3 = read_addr_a; end
                3'd5: begin re_sram_4 = 1; raddr_4 = read_addr_a; end
            endcase
        end

        if(read_req_b) begin
            case(sel_in_b)
                3'd0: begin re_sram_x = 1; raddr_x = read_addr_b; end
                3'd1: begin re_sram_0 = 1; raddr_0 = read_addr_b; end
                3'd2: begin re_sram_1 = 1; raddr_1 = read_addr_b; end
                3'd3: begin re_sram_2 = 1; raddr_2 = read_addr_b; end
                3'd4: begin re_sram_3 = 1; raddr_3 = read_addr_b; end
                3'd5: begin re_sram_4 = 1; raddr_4 = read_addr_b; end
            endcase
        end

        if(sfm_read_req) begin
            re_sram_1 = 1;
            raddr_1 = sfm_read_addr;
        end

        if(tr_read_req) begin
            re_sram_2 = 1;
            raddr_2 = tr_read_addr;
        end
    end

    // ==========================================
    // SRAM WRITE ENABLE SIGNAL
    // ==========================================
    logic write_valid;
    logic [ADDR_WIDTH-1:0] waddr;
    logic signed [DATA_WIDTH-1:0] wdata [ARRAY_SIZE-1:0];
    logic cus_we_sram_1, cus_we_sram_2;

    always_comb begin
        cus_we_sram_1 = we_sram_1;
        cus_we_sram_2 = we_sram_2;
        //cus_we_sram_1 = we_sram_1 | (!transpose_mode & trans_valid_out);
       // cus_we_sram_2 = we_sram_2 | sfm_write_req;

        if(sfm_write_req) begin
            write_valid = 1;
            waddr = sfm_write_addr;
            wdata = sfm_write_data;
            cus_we_sram_2 = 1;
        end
        else if(transpose_mode || trans_valid_out) begin
            write_valid = trans_valid_out;
            waddr = (trans_out_bc * ARRAY_SIZE + trans_col_idx) * NUM_BLOCKS + trans_out_br;
            wdata = trans_col_data;
            if(!transpose_mode) cus_we_sram_1 = 1; // Force SRAM_1 write if this is a standalone Transpose Relay output
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
        if(start_matmul || start_transpose || start_softmax)
            write_counter <= 0;
        else if(write_valid)
            write_counter <= write_counter + 1;
    end

    logic [ADDR_WIDTH:0] target_write_count;
    assign target_write_count = is_calc_z ? ((MAT_SIZE * ARRAY_SIZE) / NUM_HEADS - 1) : (MAT_SIZE * ARRAY_SIZE - 1);
    assign stage_done = write_valid && (write_counter == target_write_count);

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
        .we(write_valid && cus_we_sram_1), .waddr(waddr), .wdata(wdata),
        .re(re_sram_1), .raddr(raddr_1), .rdata(rdata_1)
    );

    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_2 (
        .clk(clk),
        .we(write_valid && cus_we_sram_2), .waddr(waddr), .wdata(wdata),
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

    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_4 (
        .clk(clk),
        .we(write_valid && we_sram_4), .waddr(waddr), .wdata(wdata),
        .re(re_sram_4), .raddr(raddr_4), .rdata(rdata_4)
    );

endmodule