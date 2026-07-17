`timescale 1ns/1ps

import I2C_pkg::*;

module I2C_CSR  
(
    input  logic        clk,
    input  logic        rst_n,
    APB.slave           apb,
    
    // I2C Core
    output logic [7:0]  o_addr_w_rw,
    output logic [15:0] o_sub_addr,
    output logic        o_sub_len,
    output logic [23:0] o_byte_len,
    
    output logic [7:0]  o_data_write,  // Read from TX FIFO
    output logic        o_req_trans,
    
    input  logic [7:0]  i_data_read,   // Push into RX FIFO
    input  logic        i_valid_out,   // Valid signal from Core (Write enable for RX FIFO)
    input  logic        i_busy,
    input  logic        i_nack,
    input  logic        i_req_data_chunk // Valid signal from Core requesting more bytes
);

    logic write_en, read_en;
    assign write_en = apb.psel & apb.penable & apb.pwrite;
    assign read_en  = apb.psel & apb.penable & ~apb.pwrite;
    
    assign apb.pready  = 1'b1; 
    assign apb.pslverr = 1'b0;

    logic        tx_fifo_wr_en, tx_fifo_rd_en;
    logic        tx_fifo_full,  tx_fifo_empty;
    logic [7:0]  tx_fifo_rd_data;

    logic        rx_fifo_wr_en, rx_fifo_rd_en;
    logic        rx_fifo_full,  rx_fifo_empty;
    logic [7:0]  rx_fifo_rd_data;

    Sync_FIFO #(.DATA_WIDTH(8), .DEPTH(16)) u_tx_fifo (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (tx_fifo_wr_en),
        .wr_data  (apb.pwdata[7:0]), // CPU write data into FIFO
        .full     (tx_fifo_full),
        .rd_en    (tx_fifo_rd_en),
        .rd_data  (tx_fifo_rd_data),
        .empty    (tx_fifo_empty)
    );

    // RX FIFO
    Sync_FIFO #(.DATA_WIDTH(8), .DEPTH(16)) u_rx_fifo (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (rx_fifo_wr_en),
        .wr_data  (i_data_read),     // Core pushes received data into FIFO
        .full     (rx_fifo_full),
        .rd_en    (rx_fifo_rd_en),
        .rd_data  (rx_fifo_rd_data),
        .empty    (rx_fifo_empty)
    );

    // APB (CPU) 
    assign tx_fifo_wr_en = (write_en && (apb.paddr == TX_REG));
    assign rx_fifo_rd_en = (read_en && (apb.paddr == RX_REG) && !apb.penable); 
    assign o_data_write = tx_fifo_rd_data;
    
    logic start_trans_pulse;
    assign start_trans_pulse = (write_en && (apb.paddr == CTRL_REG) && apb.pwdata[0] && !i_busy);
    
    assign tx_fifo_rd_en = i_req_data_chunk | start_trans_pulse;

    // Core push data: when Core valid_out is high, push data into RX FIFO
    assign rx_fifo_wr_en = i_valid_out;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_req_trans  <= 1'b0;
            o_sub_len    <= 1'b0;
            o_addr_w_rw  <= 8'h0;
            o_sub_addr   <= 16'h0;
            o_byte_len   <= 24'h0;
        end else begin
            if (o_req_trans && i_busy) begin
                o_req_trans <= 1'b0; 
            end

            if (write_en) begin
                case (apb.paddr)
                    CTRL_REG: begin
                        o_req_trans <= apb.pwdata[0];
                        o_sub_len   <= apb.pwdata[1];
                    end
                    ADDR_REG: begin
                        o_addr_w_rw <= apb.pwdata[7:0];
                        o_sub_addr  <= apb.pwdata[23:8];
                    end
                    LEN_REG: o_byte_len <= apb.pwdata[23:0];
                    default: ;
                endcase
            end
        end
    end

    // READ Registers
    always_comb begin
        apb.prdata = 32'h0;
        if (read_en) begin
            case (apb.paddr)
                CTRL_REG: apb.prdata = {30'h0, o_sub_len, o_req_trans};
                ADDR_REG: apb.prdata = {8'h0, o_sub_addr, o_addr_w_rw};
                LEN_REG:  apb.prdata = {8'h0, o_byte_len};
                RX_REG:   apb.prdata = {24'h0, rx_fifo_rd_data}; // Read data from RX FIFO
                // STAT_REG:
                STAT_REG: apb.prdata = {24'h0, 
                                        1'b0, rx_fifo_empty, rx_fifo_full, 
                                        1'b0, tx_fifo_empty, tx_fifo_full, 
                                        i_nack, i_busy}; 
                                        // Bit [1]: busy, [2]: nack
                                        // [3]: tx_full, [4]: tx_empty
                                        // [6]: rx_full, [7]: rx_empty
                default:  apb.prdata = 32'h0;
            endcase
        end
    end
endmodule
