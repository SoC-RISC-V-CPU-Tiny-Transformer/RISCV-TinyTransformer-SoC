`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 04/12/2026 10:16:58 PM
// Module Name: ascon_pkg
// Project Name: Ascon_128
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


package ascon_pkg;

    localparam DATA_WIDTH = 128;


    function automatic logic [63:0] ROR(
        input logic [63:0] x_in,
        input logic [5:0]  n
    );
        return (x_in >> n) | (x_in << (- n & 63));
    endfunction

    // round constants
    localparam logic [7:0] RC [0:11] = '{
        8'hf0, 8'he1, 8'hd2, 8'hc3,
        8'hb4, 8'ha5, 8'h96, 8'h87,
        8'h78, 8'h69, 8'h5a, 8'h4b
    };


    // CONVERSION BIG -> LITTLE ENDIAN
    function automatic logic [DATA_WIDTH-1:0] CONVERSION (
        input logic [DATA_WIDTH-1:0] data_in
    );
        logic [DATA_WIDTH-1:0] out_data;
        for (int i = 0; i < DATA_WIDTH/8; i++) begin
            out_data[i*8 +: 8] = data_in[( (DATA_WIDTH/8) - 1 - i)*8 +: 8];
        end
        return out_data;
    endfunction 
    

    // PADDING - LITTLE ENDIAN (Padding = 0x01)
    // 128-bit (16 Bytes)
    function automatic logic [DATA_WIDTH-1:0] PAD (
        input logic [DATA_WIDTH-1:0] data_in,
        input logic [DATA_WIDTH/8-1:0]  tkeep
    );
        logic [DATA_WIDTH-1:0] out_data;
        out_data = data_in; 

        for (int i = 0; i < DATA_WIDTH/8; i++) begin
            if (tkeep[i] == 1'b0) begin
                if (i == 0 || tkeep[i-1] == 1'b1) begin
                    out_data[i*8 +: 8] = 8'h01; // Padding Little-Endian
                end else begin
                    out_data[i*8 +: 8] = 8'h00; 
                end
            end
        end
        return out_data;
    endfunction
    


    // NIST LWC Standard IVs 
    localparam logic [63:0] ASCON_128_IV  = 64'h00000800806C0001;
    localparam logic [63:0] ASCON_128A_IV = 64'h00001000808C0001;

endpackage
