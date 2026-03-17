`timescale 1ns / 1ps

module MMU_CTRL #(
    parameter ADDR_WIDTH = 10,
    parameter ROW_WIDTH  = 2,
    parameter MAX_ADDR = 16
)(
    input  logic clk,
    input  logic rst_n,

    // --- 1. GIAO TIẾP VỚI MASTER FSM (HOẶC TESTBENCH) ---
    input  logic       start,
    input  logic [2:0] task_id,
    output logic       done,

    // --- 2. GIAO TIẾP VỚI DMA (Ping-Pong) ---
    output logic dma_req_w_a,
    output logic dma_req_w_b,
    input  logic dma_ack_a,
    input  logic dma_ack_b,

    // --- 3. ĐIỀU KHIỂN DATAPATH ---
    input logic mmu_valid_out,
    output logic [2:0] mux_sel_mmu_in_a,
    output logic [2:0] mux_sel_mmu_in_b,
    output logic [3:0] buf_we,
    output logic mux_sel_buf_wdata,
    output logic trans_load_en,
    output logic mmu_valid_in,
    output logic mmu_clear_acc,
    output logic sel_trans_buf,
    
    // Các bộ đếm địa chỉ (Sinh ra để quét qua SRAM)
    output logic [ADDR_WIDTH-1:0] residual_raddr,
    output logic [ADDR_WIDTH-1:0] w_a_raddr,
    output logic [ADDR_WIDTH-1:0] w_b_raddr,
    output logic [ADDR_WIDTH-1:0] buf_waddr [0:3],
    output logic [ROW_WIDTH-1:0]  mmu_out_row_idx
);
    localparam TASK_QKV     = 3'd0;
    localparam TASK_SCORE   = 3'd1;
    localparam TASK_CONTEXT = 3'd2;

    typedef enum logic [3:0] {
        S_IDLE, 
        S_WAIT_WQ, 
        S_CALC_Q, 
        S_CALC_K_TRANS, 
        S_CALC_V, 
        S_DONE
    } state_t;
    
    state_t state;
    logic [2:0] current_task;

    logic [ADDR_WIDTH-1:0] read_count; // Đếm số lượng data đã load vào mmu
    logic [ADDR_WIDTH-1:0] write_count; // Đếm số lượng data đã đẩy vào sram
    logic task_done; // Cờ báo đã tính xong 1 ma trận
    
    logic [ROW_WIDTH-1:0] trans_row_idx, trans_col_idx;
    logic is_draining_transpose;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done  <= 1'b0;
            current_task <= 3'd0;
            dma_req_w_a <= 1'b0;
            dma_req_w_b <= 1'b0;
            mux_sel_mmu_in_a <= 3'd0;
            mux_sel_mmu_in_b <= 3'd0;
            buf_we <= 4'b0000;
            mux_sel_buf_wdata <= 1'b0;
            trans_load_en <= 1'b0;
            mmu_valid_in <= 1'b0;
            mmu_clear_acc <= 1'b0;
            
            read_count <= '0;
            write_count <= '0;
            task_done <= 1'b0;

            trans_row_idx <= '0;
            trans_col_idx <= '0;
            is_draining_transpose <= 1'b0;
            sel_trans_buf <= 1'b0;
            
            residual_raddr <= '0; w_a_raddr <= '0; w_b_raddr <= '0;
            buf_waddr[0] <= '0; buf_waddr[1] <= '0; buf_waddr[2] <= '0; buf_waddr[3] <= '0;
            mmu_out_row_idx <= '0;
        end else begin
            // Mặc định xóa cờ pulse
            buf_we <= 4'b0000; 
            trans_load_en <= 1'b0;
            done <= 1'b0;
            mmu_clear_acc <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        current_task <= task_id;
                        if (task_id == TASK_QKV) begin
                            state <= S_WAIT_WQ;
                            dma_req_w_a <= 1'b1; // Khởi động Ping-Pong
                        end
                        // Thêm if (task_id == TASK_SCORE) nhảy sang nhánh khác ở đây
                    end
                end

                S_WAIT_WQ: begin
                    if (dma_ack_a) begin
                        dma_req_w_a <= 1'b0;
                        state <= S_CALC_Q;
                        mmu_clear_acc    <= 1'b1;
                        mux_sel_mmu_in_a <= 3'd0; // X lấy từ sram_residual (0) (chỉ dùng khi chưa có Layernorm)
                        mux_sel_mmu_in_b <= 3'd0; // W_q lấy từ Bank A (0)
                        dma_req_w_b <= 1'b1;

                        read_count <= '0;
                        write_count <= '0;
                        residual_raddr <= '0;
                        w_a_raddr <= '0;
                    end
                end

                S_CALC_Q: begin
                    // Đọc data vào mmu
                    if(read_count < MAX_ADDR) begin
                        mmu_valid_in <= 1'b1;
                        residual_raddr <= read_count; // input/residual
                        w_a_raddr <= read_count; // Wq
                        read_count <= read_count + 1;
                    end
                    else begin
                        mmu_valid_in <= 1'b0;
                    end

                    // Ghi data     từ mmu vào buffer 1
                    if(mmu_valid_out) begin
                        buf_we[1] <= 1'b1; // Ghi vào buffer 1 vì buffer 0 đã chứa x_norm
                        buf_waddr[1] <= write_count;
                        write_count <= write_count + 1;
                        if(write_count == MAX_ADDR - 1) task_done <= 1'b1;
                    end

                    // Chuyển trạng thái
                    if(task_done && dma_ack_b) begin
                        task_done <= 1'b0;
                        dma_req_w_b <= 1'b0;
                        state <= S_CALC_K_TRANS;
                        mmu_clear_acc    <= 1'b1;

                        read_count <= '0;
                        write_count <= '0;
                        residual_raddr <= '0;
                        w_b_raddr <= '0;

                        trans_row_idx <= '0;
                        trans_col_idx <= '0;
                        is_draining_transpose <= 1'b0;
                        sel_trans_buf <= 1'b0;
                        
                        mux_sel_mmu_in_b <= 3'd1; // mmu lấy dữ liệu từ Bank B - nơi đang chứa Wk
                        mux_sel_buf_wdata <= 1'b1; // Chọn đường đi qua transpose
                        dma_req_w_a <= 1'b1; // DMA nạp Wv vào Bank A
                    end
                end

                S_CALC_K_TRANS: begin
                    // LOGIC ĐỌC DATA VÀO MMU
                    if(read_count < MAX_ADDR) begin
                        mmu_valid_in <= 1'b1;
                        residual_raddr <= read_count; // input/residual
                        w_b_raddr <= read_count; // Wk
                        read_count <= read_count + 1;
                    end
                    else begin
                        mmu_valid_in <= 1'b0;
                    end

                    // LOGIC GHI DATA VÀO BUFFER SAU KHI TRANSPOSE
                    // Lấy data từ transpose buffer ghi vào sram           
                    if(is_draining_transpose) begin   
                        buf_we[2] <= 1'b1; // Ghi vào buffer 2 vì buffer 0 đã chứa x_norm, buffer 1 chứa Q
                        buf_waddr[2] <= write_count;
                        write_count <= write_count + 1;

                        trans_col_idx <= trans_col_idx + 1;
                        if(trans_col_idx == 2'd3) is_draining_transpose <= 1'b0;

                        if(write_count == MAX_ADDR - 1) task_done <= 1'b1;
                    end

                    // Nạp data từ mmu vào transpose buffer (ping-pong)
                    if(mmu_valid_out) begin
                        trans_load_en <= 1'b1;
                        trans_row_idx <= trans_row_idx + 1;

                        if(trans_row_idx == 2'd3) begin
                            sel_trans_buf <= ~sel_trans_buf;
                            is_draining_transpose <= 1'b1;
                        end 
                    end

                    // ĐIỀU KIỆN CHUYỂN TRẠNG THÁI
                    if(task_done && dma_ack_a) begin
                        task_done <= 1'b0;
                        dma_req_w_a <= 1'b0;
                        state <= S_CALC_V;
                        mmu_clear_acc    <= 1'b1;

                        read_count <= '0;
                        write_count <= '0;
                        residual_raddr <= '0;
                        w_a_raddr <= '0;

                        trans_row_idx <= '0;
                        trans_col_idx <= '0;
                        is_draining_transpose <= 1'b0;
                        sel_trans_buf <= 1'b0;

                        mux_sel_mmu_in_b <= 3'd0; // mmu lấy dữ liệu từ Bank A - nơi đang chứa Wv
                        mux_sel_buf_wdata <= 1'b0;
                    end
                end

                S_CALC_V: begin
                    // LOGIC ĐỌC
                    if (read_count < MAX_ADDR) begin
                        mmu_valid_in <= 1'b1;
                        residual_raddr <= read_count;
                        w_a_raddr <= read_count; // Quét W_v
                        read_count <= read_count + 1;
                    end
                    else begin
                        mmu_valid_in <= 1'b0;
                    end

                    // LOGIC GHI
                    if (mmu_valid_out) begin
                        buf_we[3] <= 1'b1;
                        buf_waddr[3] <= write_count;
                        write_count <= write_count + 1;
                        
                        if (write_count == MAX_ADDR - 1) begin
                            state <= S_DONE;
                        end
                    end
                end

                S_DONE: begin
                    done  <= 1'b1; 
                    state <= S_IDLE; 
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule