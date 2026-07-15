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
    output logic [7:0]  o_data_write,
    output logic        o_req_trans,
    
    input  logic [7:0]  i_data_read,
    input  logic        i_valid_out,
    input  logic        i_busy,
    input  logic        i_nack
);

    logic write_en, read_en;
    assign write_en = apb.psel & apb.penable & apb.pwrite;
    assign read_en  = apb.psel & apb.penable & ~apb.pwrite;
    
    assign apb.pready  = 1'b1; 
    assign apb.pslverr = 1'b0;

    // Write Registers 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_req_trans  <= 1'b0;
            o_sub_len    <= 1'b0;
            o_addr_w_rw  <= 8'h0;
            o_sub_addr   <= 16'h0;
            o_byte_len   <= 24'h0;
            o_data_write <= 8'h0;
        end else begin
            // Auto clear req_trans when Core starts processing (busy = 1)
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
                    LEN_REG: o_byte_len   <= apb.pwdata[23:0];
                    TX_REG:  o_data_write <= apb.pwdata[7:0];
                    default: ;
                endcase
            end
        end
    end

    // Read Registers
    always_comb begin
        apb.prdata = 32'h0;
        if (read_en) begin
            case (apb.paddr)
                CTRL_REG: apb.prdata = {30'h0, o_sub_len, o_req_trans};
                ADDR_REG: apb.prdata = {8'h0, o_sub_addr, o_addr_w_rw};
                LEN_REG:  apb.prdata = {8'h0, o_byte_len};
                TX_REG:   apb.prdata = {24'h0, o_data_write};
                RX_REG:   apb.prdata = {24'h0, i_data_read};
                STAT_REG: apb.prdata = {29'h0, i_valid_out, i_nack, i_busy};
                default:  apb.prdata = 32'h0;
            endcase
        end
    end
endmodule
