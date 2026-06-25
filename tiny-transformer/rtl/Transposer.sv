`timescale 1ns / 1ps

module Transposer #(
    parameter DATA_WIDTH = 8,
    parameter ARRAY_SIZE = 8,
    parameter MAT_SIZE = 64
) (
    input logic clk,
    input logic rst_n,

    input logic valid_in,
    input logic [$clog2(ARRAY_SIZE)-1:0] in_row_idx,
    input logic signed [DATA_WIDTH-1:0] in_row_data [ARRAY_SIZE-1:0],

    // Block coordinates coming in and coming out
    input logic [$clog2(MAT_SIZE/ARRAY_SIZE)-1:0] in_br, in_bc,
    output logic [$clog2(MAT_SIZE/ARRAY_SIZE)-1:0] out_br, out_bc,

    output logic valid_out,
    output logic [$clog2(ARRAY_SIZE)-1:0] out_col_idx,
    output logic signed [DATA_WIDTH-1:0] out_col_data [ARRAY_SIZE-1:0]
);
    logic ping_pong_sel;
    // ping-pong buffers
    logic signed [DATA_WIDTH-1:0] ping_buf [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] pong_buf [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];

    // Block cooridnates register
    logic [$clog2(MAT_SIZE/ARRAY_SIZE)-1:0] ping_br, ping_bc;
    logic [$clog2(MAT_SIZE/ARRAY_SIZE)-1:0] pong_br, pong_bc;

    // Write rows to buffer
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            ping_pong_sel <= 1'b0;
        end
        else begin
            if(valid_in) begin
                if(ping_pong_sel == 1'b0) begin 
                    ping_buf[in_row_idx] <= in_row_data;

                    if(in_row_idx == 0) begin
                        ping_br <= in_br;
                        ping_bc <= in_bc;
                    end
                end
                else begin
                    pong_buf[in_row_idx] <= in_row_data;

                    if(in_row_idx == 0) begin
                        pong_br <= in_br;
                        pong_bc <= in_bc;
                    end
                end
                
                if(in_row_idx == ARRAY_SIZE-1)
                    ping_pong_sel <= ~ping_pong_sel;
            end
        end
    end

    // Read columns out from buffer
    logic [$clog2(ARRAY_SIZE)-1:0] read_idx;
    logic reading;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            read_idx <= '0;
            reading <= 1'b0;
        end
        else begin
            if(valid_in && in_row_idx == ARRAY_SIZE-1) begin
                read_idx <= '0;
                reading <= 1'b1;
            end
            else if(reading) begin
                read_idx <= read_idx + 1;
                if(read_idx == ARRAY_SIZE-1) 
                    reading <= 1'b0;
            end
        end
    end

    // Output routing
    always_comb begin
        valid_out = reading;
        out_col_idx = read_idx;

        for(int i = 0; i < ARRAY_SIZE; i++) begin
            if(ping_pong_sel == 1'b0)
                out_col_data[i] = pong_buf[i][read_idx];
            else 
                out_col_data[i] = ping_buf[i][read_idx];
        end

        if(ping_pong_sel == 1'b0) begin
            out_br = pong_br;
            out_bc = pong_bc;
        end
        else begin
            out_br = ping_br;
            out_bc = ping_bc;
        end
    end

endmodule