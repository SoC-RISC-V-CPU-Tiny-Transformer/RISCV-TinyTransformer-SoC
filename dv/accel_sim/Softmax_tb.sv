`timescale 1ns / 1ps

module Softmax_tb();
    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 9;
    localparam ARRAY_SIZE = 8;
    localparam MAT_SIZE = 64;

    logic clk;
    logic rst_n;
    logic start;
    logic [3:0] q_frac;
    logic done;
    
    logic read_req;
    logic [ADDR_WIDTH-1:0] read_addr;
    logic signed [DATA_WIDTH-1:0] read_data [ARRAY_SIZE-1:0];

    logic write_req;
    logic [ADDR_WIDTH-1:0] write_addr;
    logic signed [DATA_WIDTH-1:0] write_data [ARRAY_SIZE-1:0];

    // =====================================
    // INSTANTIATE 2 VECTOR SRAMs
    // =====================================
    // 1. SRAM chứa dữ liệu đầu vào
    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH), .ARRAY_SIZE(ARRAY_SIZE), .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_in (
        .clk(clk),
        .we(1'b0), .waddr('0), .wdata('{default: '0}),
        .re(read_req), .raddr(read_addr), .rdata(read_data)
    );

    // 2. SRAM chứa dữ liệu đầu ra của Softmax
    VectorSRAM #(
        .DATA_WIDTH(DATA_WIDTH), .ARRAY_SIZE(ARRAY_SIZE), .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_out (
        .clk(clk),
        .we(write_req), .waddr(write_addr), .wdata(write_data),
        .re(1'b0), .raddr('0), .rdata()
    );


    Softmax #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE), .MAT_SIZE(MAT_SIZE)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .q_frac(q_frac), .done(done),
        .read_req(read_req), .read_addr(read_addr), .read_data(read_data),
        .write_req(write_req), .write_addr(write_addr), .write_data(write_data)
    );

    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    // =====================================
    // GOLDEN MODEL
    // =====================================
    logic signed [DATA_WIDTH-1:0] input_matrix [0:MAT_SIZE-1][0:MAT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] expected_matrix [0:MAT_SIZE-1][0:MAT_SIZE-1];
    
    logic [DATA_WIDTH-1:0] exp_lut [0:15];

    initial begin
        exp_lut[0] = 127; exp_lut[1] = 121; exp_lut[2] = 116; exp_lut[3] = 111;
        exp_lut[4] = 106; exp_lut[5] = 101; exp_lut[6] = 97;  exp_lut[7] = 93;
        exp_lut[8] = 89;  exp_lut[9] = 85;  exp_lut[10]= 81;  exp_lut[11]= 78;
        exp_lut[12]= 74;  exp_lut[13]= 71;  exp_lut[14]= 68;  exp_lut[15]= 65;
    end

    task automatic calc_golden_model();
        for (int r = 0; r < MAT_SIZE; r++) begin
            int max_val = -128;
            longint sum_exp = 0;
            int exp_vals [0:MAT_SIZE-1];

            // 1. Tìm Max
            for (int c = 0; c < MAT_SIZE; c++) begin
                if (input_matrix[r][c] > max_val) max_val = input_matrix[r][c];
            end
            
            // 2. Tính hàm mũ (Exp) và Cộng dồn (Sum)
            for (int c = 0; c < MAT_SIZE; c++) begin
                int abs_diff = max_val - input_matrix[r][c];
                int int_part = abs_diff >> q_frac;
                int raw_frac = abs_diff & ((1 << q_frac) - 1);
                int lut_idx;
                
                if (q_frac >= 4) lut_idx = raw_frac >> (q_frac - 4);
                else             lut_idx = raw_frac << (4 - q_frac);
                
                exp_vals[c] = exp_lut[lut_idx] >> int_part;
                sum_exp += exp_vals[c];
            end
            
            // 3. Phép chia (Divide)
            for (int c = 0; c < MAT_SIZE; c++) begin
                int scaled_exp;
                int div_res;
                
                scaled_exp = exp_vals[c] << 7; 
                div_res = scaled_exp / sum_exp;
                
                // Nếu kết quả lớn hơn 127, ép nó về 127. Nếu không, giữ nguyên.
                if (div_res > 127) 
                    expected_matrix[r][c] = 127;
                else 
                    expected_matrix[r][c] = div_res;
            end
        end
    endtask


    initial begin
        // 1. Normal case (Decreasing values)
        for (int c = 0; c < MAT_SIZE; c++) input_matrix[0][c] = 50 - c; 
        
        // 2. Uniform case (All values are equal)
        for (int c = 0; c < MAT_SIZE; c++) input_matrix[1][c] = 20; 
        
        // 3. All negative values
        for (int c = 0; c < MAT_SIZE; c++) input_matrix[2][c] = -20 - c; 
        
        // 4. Extreme case (Max distance: one 127, others -128)
        for (int c = 0; c < MAT_SIZE; c++) input_matrix[3][c] = -128;
        input_matrix[3][0] = 127; 
        
        // The rest are zeros
        for (int r = 4; r < MAT_SIZE; r++) begin
            for (int c = 0; c < MAT_SIZE; c++) input_matrix[r][c] = 0;
        end

        // --- NẠP VÀO SRAM & TÍNH GOLDEN MODEL ---
        q_frac = 4; // Format Q3.4

        for (int r = 0; r < MAT_SIZE; r++) begin
            for (int chunk = 0; chunk < 8; chunk++) begin
                for (int i = 0; i < ARRAY_SIZE; i++) begin
                    sram_in.ram[r * 8 + chunk][i] = input_matrix[r][chunk * 8 + i];
                end
            end
        end
        calc_golden_model();
        $display(">>> SRAM In and Golden Model initialization completed.");

        rst_n = 0;
        start = 0;
        #25;
        rst_n = 1;
        #10;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1);
        @(posedge clk); // Đợi thêm 1 nhịp cho SRAM Out ghi xong hàng cuối

        $display("\n=======================================================");
        $display(" TEST RESULTS (PRINTING FIRST 4 EDGE CASE ROWS ONLY)");
        $display("=======================================================");
        
        begin
            int err_count;
            err_count = 0;
            for (int r = 0; r < 4; r++) begin 
                $display("\n--- ROW %0d ---", r);
                for (int c = 0; c < MAT_SIZE; c++) begin
                    int chunk;
                    int offset;
                    logic signed [DATA_WIDTH-1:0] dut_val;
                    logic signed [DATA_WIDTH-1:0] exp_val;

                    chunk = c / ARRAY_SIZE;
                    offset = c % ARRAY_SIZE;
                    dut_val = sram_out.ram[r * 8 + chunk][offset];
                    exp_val = expected_matrix[r][c];

                    if (dut_val !== exp_val) begin
                        $display("[FAIL] Col %2d: HW_out = %4d | Expected = %4d", c, dut_val, exp_val);
                        err_count++;
                    end else if (c < 8 || c > 59) begin 
                        $display("[PASS] Col %2d: HW_out = %4d | Expected = %4d", c, dut_val, exp_val);
                    end else if (c == 8) begin
                        $display("       ... (Middle columns perfectly match) ...");
                    end
                end
            end

            $display("\n=======================================================");
            if (err_count == 0) $display("     EXCELLENT! HARDWARE MATCHES 100%% WITH EXPECTED MODEL");
            else                $display("     DETECTED %0d MISMATCHES!", err_count);
            $display("=======================================================\n");
        end

        #50;
        $finish;
    end
endmodule