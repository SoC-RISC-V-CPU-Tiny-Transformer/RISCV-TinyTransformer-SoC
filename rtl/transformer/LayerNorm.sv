`timescale 1ns / 1ps

module LayerNorm #(
    parameter DATA_WIDTH = 8,
    parameter ARRAY_SIZE = 8,
    parameter MAT_SIZE = 64,
    parameter ADDR_WIDTH = 9
) (
    input logic clk,
    input logic rst_n,

    input logic start,
    input logic [3:0] ln_q_frac,
    
    // SRAM_0 (X input)
    output logic [ADDR_WIDTH-1:0] sram_0_raddr,
    input logic signed [DATA_WIDTH-1:0] sram_0_rdata [ARRAY_SIZE-1:0],
    
    // SRAM_1 (Gamma input)
    output logic [ADDR_WIDTH-1:0] sram_1_raddr,
    input logic signed [DATA_WIDTH-1:0] sram_1_rdata [ARRAY_SIZE-1:0],
    
    // SRAM_2 (Beta input)
    output logic [ADDR_WIDTH-1:0] sram_2_raddr,
    input logic signed [DATA_WIDTH-1:0] sram_2_rdata [ARRAY_SIZE-1:0],
    
    // Output SRAM (To MHA_OUT backup alias SRAM_3 or external)
    output logic write_en,
    output logic [ADDR_WIDTH-1:0] write_addr,
    output logic signed [DATA_WIDTH-1:0] write_data [ARRAY_SIZE-1:0],

    output logic done
);
    localparam TOTAL_COLS = MAT_SIZE / ARRAY_SIZE;

    typedef enum logic [2:0] {
        IDLE,
        CALC_MEAN,
        CALC_VAR,
        CALC_ISQRT,
        CALC_NORM,
        DONE_STATE
    } state_t;

    state_t state;
    
    logic [$clog2(MAT_SIZE):0] row_idx;
    logic [$clog2(TOTAL_COLS)+1:0] col_idx;

    assign sram_0_raddr = row_idx * TOTAL_COLS + ((col_idx < TOTAL_COLS) ? col_idx : 0);
    assign sram_1_raddr = (col_idx < TOTAL_COLS) ? col_idx : 0;
    assign sram_2_raddr = (col_idx < TOTAL_COLS) ? col_idx : 0;

    logic signed [31:0] sum_acc; 
    logic signed [31:0] mean_val;
    logic [31:0] var_acc;
    logic [31:0] var_val;
    logic [10:0] isqrt_val; 
    
    logic [3:0] isqrt_step;
    logic [10:0] test_y;
    
    assign test_y = isqrt_val | (11'b1 << isqrt_step);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            row_idx <= 0;
            col_idx <= 0;
            done <= 0;
            write_en <= 0;
        end else begin
            write_en <= 0; 
            
            case (state)
                IDLE: begin
                    done <= 0;
                    row_idx <= 0;
                    if (start) begin
                        state <= CALC_MEAN;
                        col_idx <= 0;
                        sum_acc <= 0;
                    end
                end

                CALC_MEAN: begin
                    if (col_idx > 0) begin
                        logic signed [31:0] col_sum;
                        col_sum = 0;
                        for (int i=0; i<ARRAY_SIZE; i++) begin
                            col_sum += sram_0_rdata[i];
                        end
                        sum_acc <= sum_acc + col_sum;
                        
                        if (col_idx == TOTAL_COLS) begin
                            state <= CALC_VAR;
                            col_idx <= 0;
                            var_acc <= 0;
                            // Shift right 6 bits implies div 64
                            mean_val <= (sum_acc + col_sum) >>> 6;
                        end else begin
                            col_idx <= col_idx + 1;
                        end
                    end else begin
                        col_idx <= col_idx + 1;
                    end
                end

                CALC_VAR: begin
                    if (col_idx > 0) begin
                        logic [31:0] col_var;
                        col_var = 0;
                        for (int i=0; i<ARRAY_SIZE; i++) begin
                            logic signed [15:0] diff;
                            diff = sram_0_rdata[i] - mean_val;
                            col_var += (diff * diff);
                        end
                        var_acc <= var_acc + col_var;
                        
                        if (col_idx == TOTAL_COLS) begin
                            state <= CALC_ISQRT;
                            isqrt_step <= 10;
                            isqrt_val <= 0;
                            var_val <= (var_acc + col_var) >> 6;
                        end else begin
                            col_idx <= col_idx + 1;
                        end
                    end else begin
                        col_idx <= col_idx + 1;
                    end
                end

                CALC_ISQRT: begin
                    // Binary Search for y = 1024 / sqrt(var_val)
                    if (var_val == 0) begin
                        isqrt_val <= 11'd1024;
                        state <= CALC_NORM;
                        col_idx <= 0;
                    end else begin
                        logic [21:0] y_sq;
                        logic [53:0] y_mult;
                        y_sq = test_y * test_y;
                        y_mult = y_sq * var_val;
                        
                        if (y_mult <= 54'd1048576) begin // 2^20
                            isqrt_val <= test_y;
                        end
                        
                        if (isqrt_step == 0) begin
                            state <= CALC_NORM;
                            col_idx <= 0;
                        end else begin
                            isqrt_step <= isqrt_step - 1;
                        end
                    end
                end

                CALC_NORM: begin
                    if (col_idx > 0) begin
                        write_en <= 1;
                        write_addr <= row_idx * TOTAL_COLS + (col_idx - 1);
                        
                        for (int i=0; i<ARRAY_SIZE; i++) begin
                            logic signed [15:0] diff;
                            logic signed [27:0] norm_x;
                            logic signed [35:0] scaled_x;
                            
                            diff = sram_0_rdata[i] - mean_val;
                            norm_x = (diff * $signed({1'b0, isqrt_val})) >>> 10;
                            scaled_x = (norm_x * sram_1_rdata[i]) >>> ln_q_frac;
                            scaled_x = scaled_x + sram_2_rdata[i];
                            
                            if (scaled_x > 127) write_data[i] <= 8'd127;
                            else if (scaled_x < -128) write_data[i] <= -8'd128;
                            else write_data[i] <= scaled_x[7:0];
                        end

                        if (col_idx == TOTAL_COLS) begin
                            if (row_idx == MAT_SIZE - 1) begin
                                state <= DONE_STATE;
                            end else begin
                                state <= CALC_MEAN;
                                row_idx <= row_idx + 1;
                                col_idx <= 0;
                                sum_acc <= 0;
                            end
                        end else begin
                            col_idx <= col_idx + 1;
                        end
                    end else begin
                        col_idx <= col_idx + 1;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end
endmodule
