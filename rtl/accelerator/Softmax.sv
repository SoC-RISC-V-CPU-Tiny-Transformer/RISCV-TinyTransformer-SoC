`timescale 1ns / 1ps

module Softmax_Core #(
    parameter DATA_W     = 8,   // Đầu vào Q3.4, Đầu ra Q0.8
    parameter ARRAY_SIZE = 4,
    parameter ACCUM_W    = 32
) (
    input  logic                      clk,
    input  logic                      rst_n,
    
    // Tín hiệu điều khiển từ SOFTMAX_CTRL (Worker FSM)
    input  logic [1:0]                mode,  // 00: IDLE, 01: PASS1_MAX, 10: PASS2_EXP, 11: PASS3_DIV
    
    // Luồng dữ liệu (Data Stream) đi từ MUX của Datapath vào
    input  logic signed [DATA_W-1:0]  din [ARRAY_SIZE],
    
    // Kết quả đẩy thẳng ra MUX để ghi vào Working Buffers
    output logic [DATA_W-1:0]         dout [ARRAY_SIZE] 
);

    logic [7:0] frac_lut [0:15];
    initial begin
        frac_lut[0]=128; frac_lut[1]=134; frac_lut[2]=139; frac_lut[3]=144;
        frac_lut[4]=150; frac_lut[5]=156; frac_lut[6]=162; frac_lut[7]=169;
        frac_lut[8]=181; frac_lut[9]=188; frac_lut[10]=195; frac_lut[11]=203;
        frac_lut[12]=211; frac_lut[13]=220; frac_lut[14]=229; frac_lut[15]=238;
    end

    logic [15:0] recip_lut [0:255];
    initial begin
        recip_lut[0] = 16'hFFFF;
        for (int i = 1; i < 256; i++) recip_lut[i] = 65536 / i;
    end

    logic signed [DATA_W-1:0] global_max;
    logic [ACCUM_W-1:0]       global_sum;

    // --- LOGIC TÌM MAX (PASS 1) ---
    logic signed [DATA_W-1:0] vec_max;
    always_comb begin
        vec_max = din[0];
        for (int i = 1; i < ARRAY_SIZE; i++) begin
            if (din[i] > vec_max) vec_max = din[i];
        end
    end

    // --- LOGIC TÍNH EXP VÀ SUM (PASS 2) ---
    logic [7:0]         exp_out_comb [ARRAY_SIZE];
    logic [ACCUM_W-1:0] vec_sum_comb;
    
    always_comb begin
        vec_sum_comb = 0;
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            logic signed [DATA_W-1:0] x_sub;
            logic [3:0] frac;
            logic signed [3:0] int_part;
            
            x_sub = din[i] - global_max; // Trừ Max
            frac = x_sub[3:0];           // Lấy 4 bit thập phân
            int_part = x_sub[7:4];       // Lấy 4 bit nguyên
            
            // Tra LUT và dịch bit (Giữ nguyên tinh hoa thuật toán của bạn)
            exp_out_comb[i] = frac_lut[frac] >> (-int_part); 
            vec_sum_comb += exp_out_comb[i]; // Cộng dồn thành tổng Vector
        end
    end

    // --- LOGIC CHIA NGHỊCH ĐẢO (PASS 3) ---
    logic [4:0] msb_pos;
    logic [7:0] sum_idx_comb;
    logic [4:0] shift_out;
    logic [15:0] recip_val;
    logic [7:0] div_out_comb [ARRAY_SIZE];

    always_comb begin
        // Tìm vị trí MSB của global_sum
        msb_pos = 0;
        for (int b = ACCUM_W-1; b >= 0; b--) begin
            if (global_sum[b] && msb_pos == 0) msb_pos = b[4:0];
        end
        
        // Chuẩn bị chỉ số tra LUT Mẫu số
        sum_idx_comb = (msb_pos >= 7) ? global_sum[msb_pos -: 8] : global_sum[7:0];
        recip_val    = recip_lut[sum_idx_comb];
        shift_out    = (msb_pos >= 7) ? (msb_pos + 1) : 8;

        // Nhân nghịch đảo cho cả Vector (din lúc này chứa exp^x do FSM bơm lại từ B1)
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            logic [23:0] product;
            product = din[i] * recip_val; 
            div_out_comb[i] = product >> shift_out; // Ra xác suất cuối cùng
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            global_max <= '1 << (DATA_W-1); // Số âm nhỏ nhất
            global_sum <= '0;
        end else begin
            case (mode)
                2'b00: begin // IDLE: Reset trạng thái chuẩn bị cho chuỗi mới
                    global_max <= '1 << (DATA_W-1);
                    global_sum <= '0;
                end
                
                2'b01: begin // PASS 1: Cập nhật Global Max
                    if (vec_max > global_max) global_max <= vec_max;
                end
                
                2'b10: begin // PASS 2: Cập nhật Global Sum
                    global_sum <= global_sum + vec_sum_comb;
                end
                
                // PASS 3: Không cập nhật gì thêm, chỉ nhả data
            endcase
        end
    end

    // MUX NGÕ RA DỮ LIỆU ĐỂ GHI VÀO BUFFER
    always_comb begin
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            if (mode == 2'b10)      dout[i] = exp_out_comb[i]; // Trả e^x để cất vào B1
            else if (mode == 2'b11) dout[i] = div_out_comb[i]; // Trả Xác suất để cất vào B0
            else                    dout[i] = '0;
        end
    end

endmodule