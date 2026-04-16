`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 04/12/2026 06:51:21 PM
// Module Name: Round
// Project Name: Ascon_128
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

module Round 
    import ascon_pkg::*;
(
    input  logic [0:4][63:0] x_in,
    output logic [0:4][63:0] x_out,
    input  logic [7:0] round_const
);
    
    logic [0:4][63:0] s0, s1, s2, s3;
    
    always_comb begin
        s0 = '0;
        s1 = '0;
        s2 = '0;
        s3 = '0;
        x_out = '0;
        
        // add round constant
        s0[0] = x_in[0];
        s0[1] = x_in[1];
        s0[2] = x_in[2] ^ {56'b0, round_const};
        s0[3] = x_in[3];
        s0[4] = x_in[4];

        // substitution pre
        s1[0] = s0[0] ^ s0[4];
        s1[1] = s0[1];
        s1[2] = s0[2] ^ s0[1];
        s1[3] = s0[3];
        s1[4] = s0[4] ^ s0[3];

        // keccak s-box
        s2[0] = s1[0] ^ (~s1[1] & s1[2]);
        s2[1] = s1[1] ^ (~s1[2] & s1[3]);
        s2[2] = s1[2] ^ (~s1[3] & s1[4]);
        s2[3] = s1[3] ^ (~s1[4] & s1[0]);
        s2[4] = s1[4] ^ (~s1[0] & s1[1]);
    
        // post s-box
        s3[1] = s2[1] ^ s2[0];
        s3[0] = s2[0] ^ s2[4];
        s3[2] = ~s2[2];
        s3[3] = s2[3] ^ s2[2];
        s3[4] = s2[4];
        
        // linear diffusion
        x_out[0] = s3[0] ^ ROR(s3[0], 19) ^ ROR(s3[0], 28);
        x_out[1] = s3[1] ^ ROR(s3[1], 61) ^ ROR(s3[1], 39);
        x_out[2] = s3[2] ^ ROR(s3[2],  1) ^ ROR(s3[2],  6);
        x_out[3] = s3[3] ^ ROR(s3[3], 10) ^ ROR(s3[3], 17);
        x_out[4] = s3[4] ^ ROR(s3[4],  7) ^ ROR(s3[4], 41); 
    end

endmodule
