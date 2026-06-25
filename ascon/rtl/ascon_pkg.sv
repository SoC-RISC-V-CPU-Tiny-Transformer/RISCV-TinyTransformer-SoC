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

    // NIST LWC Standard IVs 
    localparam logic [63:0] ASCON_IV  = 64'h00001000808c0001;
    localparam ASCON_A = 12; // init and final rounds
    localparam ASCON_B = 8;  // intermediate rounds
    localparam RATE_CHUNKS = 2; 

    function automatic logic [63:0] ROR(
        input logic [63:0] x_in,
        input logic [5:0]  n
    );
        return (x_in >> n) | (x_in << (- n & 63));
    endfunction

    typedef enum logic [2:0] { IDLE, INIT, ASSO_DATA, MESSAGE, TAG } state_t;

    // round constants
    localparam logic [7:0] RC [0:11] = '{
        8'hf0, 8'he1, 8'hd2, 8'hc3,
        8'hb4, 8'ha5, 8'h96, 8'h87,
        8'h78, 8'h69, 8'h5a, 8'h4b
    };


    // CONVERSION LITTLE ENDIAN -> BIG ENDIAN
    function automatic logic [63:0] CONVERSION (
        input logic [63:0] data_in
    );
        logic [63:0] out_data;
        integer i;

        for (i = 0; i < 8; i = i + 1) begin
            out_data[63 - i*8 -: 8] = data_in[i*8 +: 8];
        end
        return out_data;
    endfunction 
    
endpackage
