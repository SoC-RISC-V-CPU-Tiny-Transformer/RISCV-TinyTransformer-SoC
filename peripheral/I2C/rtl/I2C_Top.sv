`timescale 1ns/1ps

module I2C_Top (
    input  logic clk,       // 100MHz System Clock
    input  logic rst_n,     // Active Low Reset
    
    // bus APB
    APB.slave apb,       
    
    inout  wire  scl_pad,
    inout  wire  sda_pad
);

    // CSR & Core FSM wires
    logic [7:0]  addr_w_rw;
    logic [15:0] sub_addr;
    logic        sub_len;
    logic [23:0] byte_len;
    logic [7:0]  data_write;
    logic        req_trans;
    
    logic [7:0]  data_read;
    logic        valid_out;
    logic        busy;
    logic        nack;
    logic        req_data_chunk; // For interupt or extended FIFO 
    // Instantiate APB CSR Module
    I2C_CSR u_apb_csr (
        .clk            (clk),
        .rst_n          (rst_n),
        .apb            (apb),
        .o_addr_w_rw    (addr_w_rw),
        .o_sub_addr     (sub_addr),
        .o_sub_len      (sub_len),
        .o_byte_len     (byte_len),
        .o_data_write   (data_write),
        .o_req_trans    (req_trans),
        .i_data_read    (data_read),
        .i_valid_out    (valid_out),
        .i_busy         (busy),
        .i_nack         (nack)
    );

    // Instantiate I2C Core FSM
    I2C_Core u_i2c_core (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_addr_w_rw    (addr_w_rw),
        .i_sub_addr     (sub_addr),
        .i_sub_len      (sub_len),
        .i_byte_len     (byte_len),
        .i_data_write   (data_write),
        .req_trans      (req_trans),
        .data_out       (data_read),
        .valid_out      (valid_out),
        .req_data_chunk (req_data_chunk), 
        .busy           (busy),
        .nack           (nack),
        .scl_o          (scl_pad),
        .sda_o          (sda_pad)
    );

endmodule
