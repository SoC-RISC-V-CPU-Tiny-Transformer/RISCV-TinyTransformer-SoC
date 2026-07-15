`timescale 1ns/1ps

package I2C_pkg;
    // F & Timing Parameters 100MHz -> 400kHz I2C
    localparam int DIV_100MHZ       = 125;         
    localparam int START_IND_SETUP  = 70;  
    localparam int START_IND_HOLD   = 60;  
    localparam int DATA_SETUP_TIME  = 2;  
    localparam int DATA_HOLD_TIME   = 3;  
    localparam int STOP_IND_SETUP   = 60;  

    // Address Map (Word aligned) CSR
    localparam logic [11:0] CTRL_REG   = 12'h00; // Bit 0: req_trans, Bit 1: sub_len
    localparam logic [11:0] ADDR_REG   = 12'h04; // [7:0]: addr_w_rw, [23:8]: sub_addr
    localparam logic [11:0] LEN_REG    = 12'h08; // [23:0]: byte_len
    localparam logic [11:0] TX_REG     = 12'h0C; // [7:0]: data_write
    localparam logic [11:0] RX_REG     = 12'h10; // [7:0]: data_read (Read Only)
    localparam logic [11:0] STAT_REG   = 12'h14; // Bit 0: busy, Bit 1: nack, Bit 2: valid_out (Read Only)
endpackage
