`timescale 1ns / 1ps

module LayerNorm_Core #(
    parameter DATA_W     = 8,
    parameter ARRAY_SIZE = 4,
    parameter EMBED_DIM  = 64, // Số phần tử của 1 vector (Dùng để tính phép chia)
    parameter ACCUM_W    = 32
) (
    input  logic                      clk,
    input  logic                      rst_n,
    
    // Tín hiệu điều khiển từ LN_CTRL (Worker FSM)
    input  logic [1:0]                mode,  // 00: IDLE, 01: PASS1_SUM, 10: PASS2_VAR, 11: PASS3_NORM
    
    // Đầu vào từ Working Buffers (B0 hoặc Residual)
    input  logic signed [DATA_W-1:0]  din [ARRAY_SIZE],
    
    // Tham số Affine (Gamma, Beta) - Có thể fix cứng hoặc load từ SRAM Weight
    input  logic signed [DATA_W-1:0]  gamma,
    input  logic signed [DATA_W-1:0]  beta,
    
    // Đầu ra đẩy vào Working Buffers
    output logic signed [DATA_W-1:0]  dout [ARRAY_SIZE]
);
    // Tính số bit cần dịch cho phép chia (Chia 64 = Dịch phải 6 bit)
    localparam SHIFT_DIV = $clog2(EMBED_DIM);

    // Bảng này tính sẵn 1/sqrt(variance + epsilon) trong Python rồi nạp vào
    logic [15:0] inv_sqrt_lut [0:255];
    initial begin
        // Khởi tạo mẫu (Thực tế bạn sẽ xuất file .hex từ Python để nạp vào đây)
        inv_sqrt_lut[0] = 16'h7FFF; // Giá trị max để tránh chia cho 0
        for (int i = 1; i < 256; i++) begin
            // Giả lập giá trị nghịch đảo căn bậc 2 (Fixed-point)
            inv_sqrt_lut[i] = 32768 / $sqrt(i); 
        end
    end

    logic signed [ACCUM_W-1:0] global_sum;
    logic [ACCUM_W-1:0]        global_var_sum; // Phương sai luôn dương
    
    // Các giá trị phái sinh (Dùng combinational để tính luôn từ global)
    logic signed [DATA_W-1:0]  mean;
    logic [DATA_W-1:0]         variance;
    logic [15:0]               inv_stddev;

    assign mean       = global_sum >>> SHIFT_DIV;       // Chia N
    assign variance   = global_var_sum >>> SHIFT_DIV;   // Chia N
    assign inv_stddev = inv_sqrt_lut[variance[7:0]];    // Tra bảng LUT

    logic signed [ACCUM_W-1:0] vec_sum_comb;
    logic [ACCUM_W-1:0]        vec_var_comb;
    logic signed [DATA_W-1:0]  norm_out_comb [ARRAY_SIZE];

    always_comb begin
        vec_sum_comb = 0;
        vec_var_comb = 0;

        for (int i = 0; i < ARRAY_SIZE; i++) begin
            logic signed [DATA_W:0]   diff;
            logic signed [ACCUM_W-1:0] sqr;
            logic signed [23:0]        scaled;
            
            // 1. Phục vụ PASS 1: Tính tổng
            vec_sum_comb += din[i];
            
            // 2. Phục vụ PASS 2: Tính tổng bình phương khoảng cách
            diff = din[i] - mean;
            sqr  = diff * diff;
            vec_var_comb += sqr;

            // 3. Phục vụ PASS 3: Chuẩn hóa y = (x - mean) * inv_stddev * gamma + beta
            scaled = (diff * $signed({1'b0, inv_stddev[7:0]})) >>> 8; // Nhân stddev và dịch bit
            norm_out_comb[i] = (scaled[7:0] * gamma) + beta;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            global_sum     <= '0;
            global_var_sum <= '0;
        end else begin
            case (mode)
                2'b00: begin // IDLE: Reset chuẩn bị cho chuỗi mới
                    global_sum     <= '0;
                    global_var_sum <= '0;
                end
                2'b01: begin // PASS 1: Cộng dồn Sum
                    global_sum <= global_sum + vec_sum_comb;
                end
                2'b10: begin // PASS 2: Cộng dồn Variance
                    global_var_sum <= global_var_sum + vec_var_comb;
                end
                // PASS 3: Giữ nguyên trạng thái, chỉ truyền dữ liệu
            endcase
        end
    end

    always_comb begin
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            if (mode == 2'b11) dout[i] = norm_out_comb[i]; // Chỉ nhả dữ liệu hợp lệ ở Pass 3
            else               dout[i] = '0;
        end
    end

endmodule