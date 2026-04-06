`timescale 1ns / 1ps

module Softmax #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 9,
    parameter ARRAY_SIZE = 8,
    parameter MAT_SIZE = 64
) (
    input logic clk,
    input logic rst_n,
    
    input logic start,
    input logic [3:0] q_frac,
    output logic done,
    
    // READ DATA FROM SRAM
    output logic read_req,
    output logic [ADDR_WIDTH-1:0] read_addr,
    input logic signed [DATA_WIDTH-1:0] read_data [ARRAY_SIZE-1:0],

    // SOFTMAX OUTPUT
    output logic write_req,
    output logic [ADDR_WIDTH-1:0] write_addr,
    output logic signed [DATA_WIDTH-1:0] write_data [ARRAY_SIZE-1:0]
);
    localparam NUM_BLOCKS = MAT_SIZE / ARRAY_SIZE;

    // =========================================================
    // LUT FOR 2^F
    // F has 4 bits (0 to 15). 2^(-F/16) Q7 format.
    // =========================================================
    logic [DATA_WIDTH-1:0] exp_lut [0:15];
    initial begin
        exp_lut[0]  = 127; // 2^0 = 1.0 (Q7)
        exp_lut[1]  = 121; // 2^(-1/16) = 0.957
        exp_lut[2]  = 116; // 2^(-2/16) = 0.917
        exp_lut[3]  = 111; // ...
        exp_lut[4]  = 106; 
        exp_lut[5]  = 101; 
        exp_lut[6]  = 97;  
        exp_lut[7]  = 93;  
        exp_lut[8]  = 89;  
        exp_lut[9]  = 85;  
        exp_lut[10] = 81;  
        exp_lut[11] = 78;  
        exp_lut[12] = 74;  
        exp_lut[13] = 71;  
        exp_lut[14] = 68;  
        exp_lut[15] = 65;  // 2^(-15/16) = 0.522
    end

    // PING-PONG BUFFER
    logic signed [DATA_WIDTH-1:0] row_buffer [0:1][0:NUM_BLOCKS-1][ARRAY_SIZE-1:0];
    logic [DATA_WIDTH-1:0] exp_buffer [0:1][0:NUM_BLOCKS-1][ARRAY_SIZE-1:0];

    logic signed [DATA_WIDTH-1:0] row_max [0:1];
    logic [31:0] exp_sum [0:1];

    // =========================================================
    //  GLOBAL COUNTERS
    // =========================================================
    typedef enum logic [1:0] {IDLE, RUNNING, DONE} state_t;
    state_t state;

    logic [$clog2(NUM_BLOCKS):0] cycle_cnt; // count form 0 to NUM_BLOCKS (NUM_BLOCKS+1 cycle for 1 row)
    logic [$clog2(MAT_SIZE):0] pipe_row; // count form 0 to MAT_SIZE+1 (MAT_SIZE row and 2 Pipeline Flushing cycle)

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            state <= IDLE;
            cycle_cnt <= 0;
            pipe_row <= 0;
            done <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if(start) state <= RUNNING;
                    cycle_cnt <= 0;
                    pipe_row <= 0;
                    done <= 0;
                end
                RUNNING: begin
                    if(cycle_cnt == NUM_BLOCKS) begin
                        cycle_cnt <= 0;
                        if(pipe_row == 65) state <= DONE;
                        else pipe_row <= pipe_row + 1;
                    end
                    else cycle_cnt <= cycle_cnt + 1;
                end
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // =========================================================
    // STAGE 1: READ SRAM AND FIND MAX
    // =========================================================
    logic s1_en;
    assign s1_en = (state == RUNNING) && (cycle_cnt < 8) && (pipe_row < 64);

    // Signals from the previous cycle (because of SRAM delay).
    logic prev_en;
    logic [$clog2(NUM_BLOCKS)-1:0] prev_chunk;
    logic [$clog2(MAT_SIZE)-1:0] prev_row;

    always_comb begin
        if(s1_en) begin 
            read_req = 1;
            read_addr = pipe_row[$clog2(MAT_SIZE)-1:0] * NUM_BLOCKS + cycle_cnt[$clog2(NUM_BLOCKS)-1:0];
        end 
        else 
            read_req = 0;
    end

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            prev_en <= 0;
        end
        else begin
            prev_en <= s1_en;
            prev_chunk <= cycle_cnt[$clog2(NUM_BLOCKS)-1:0];
            prev_row <= pipe_row[$clog2(MAT_SIZE)-1:0];
        end
    end

    // Find max of ARRAY_SIZE input data per cycle.
    logic signed [DATA_WIDTH-1:0] cur_max;
    always_comb begin
        cur_max = read_data[0];
        for(int i = 1; i < ARRAY_SIZE; i++) begin
            if(read_data[i] > cur_max) cur_max = read_data[i];
        end
    end
    
    // Write to ping-pong buffer and find max of row.
    always_ff @(posedge clk) begin
        if(prev_en) begin
            row_buffer[prev_row[0]][prev_chunk] <= read_data; // Ping (0): even row, Pong (1): odd row.
            if(prev_chunk == 0) row_max[prev_row[0]] <= cur_max;
            else if(cur_max > row_max[prev_row[0]]) row_max[prev_row[0]] <= cur_max;
        end
    end

    // =========================================================
    // STAGE 2: CALC EXP AND SUM
    // =========================================================
    logic s2_en;
    logic [$clog2(MAT_SIZE)-1:0] s2_row;
    assign s2_row = pipe_row - 1;
    assign s2_en = (state == RUNNING) && (cycle_cnt < 8) && (pipe_row >= 1) && (pipe_row < 65);

    logic [DATA_WIDTH-1:0] exp_vals [0:ARRAY_SIZE-1];
    logic [31:0] temp_sum;
    always_comb begin
        temp_sum = 0;
        for(int i = 0; i < ARRAY_SIZE; i++) begin
            logic [DATA_WIDTH-1:0] abs_diff;
            logic [3:0] int_part;
            logic [DATA_WIDTH-1:0] raw_frac;
            logic [3:0] lut_idx;
            logic [DATA_WIDTH-1:0] lut_val;
            logic [DATA_WIDTH-1:0] exp_val;
            
            abs_diff = row_max[s2_row[0]] - row_buffer[s2_row[0]][cycle_cnt[$clog2(NUM_BLOCKS)-1:0]][i];
            int_part = abs_diff >> q_frac;
            raw_frac = abs_diff & ((1 << q_frac) - 1);
            if(q_frac >= 4)
                lut_idx = raw_frac >> (q_frac - 4);
            else
                lut_idx = raw_frac << (4 - q_frac);
            lut_val = exp_lut[lut_idx];
            exp_val = lut_val >> int_part;
            
            exp_vals[i] = exp_val;
            temp_sum = temp_sum + exp_val;
        end
    end

    always_ff @(posedge clk) begin
        if(s2_en) begin
            for(int i = 0; i < ARRAY_SIZE; i++)
                exp_buffer[s2_row[0]][cycle_cnt[$clog2(NUM_BLOCKS)-1:0]][i] = exp_vals[i];
            
            if(cycle_cnt == 0)
                exp_sum[s2_row[0]] <= temp_sum;
            else
                exp_sum[s2_row[0]] <= exp_sum[s2_row[0]] + temp_sum;
        end
    end

    // =========================================================
    // STAGE 3: DIVIDE AND WRITE TO SRAM
    // =========================================================
    logic s3_en;
    logic [$clog2(MAT_SIZE)-1:0] s3_row;
    assign s3_en = (state == RUNNING) && (cycle_cnt < 8) && (pipe_row >= 2) && (pipe_row < 66);
    assign s3_row = pipe_row - 2;

    always_ff @(posedge clk) begin
        if(!rst_n)  write_req <= 0;
        else begin
            write_req <= s3_en;
            if(s3_en) begin
                write_addr <= s3_row * NUM_BLOCKS + cycle_cnt[$clog2(NUM_BLOCKS)-1:0];
                for(int i = 0; i < ARRAY_SIZE; i++) begin
                    logic [15:0] scaled_exp;
                    logic [15:0] div;
                    scaled_exp = exp_buffer[s3_row[0]][cycle_cnt[$clog2(NUM_BLOCKS)-1:0]][i] << 7; // Pre quantization with Q7 format.
                    div = scaled_exp / exp_sum[s3_row[0]];
                    if (div > 127) 
                        write_data[i] <= 8'd127;
                    else 
                        write_data[i] <= div[7:0];
                end
            end
        end
    end

endmodule