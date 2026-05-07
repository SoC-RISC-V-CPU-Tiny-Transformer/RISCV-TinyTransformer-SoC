`timescale 1ns / 1ps

module Ascon_Core_tb;

    import ascon_pkg::*;
    logic clk;
    logic reset_n;
    
    // Stream Interface
    logic        mess_valid;
    logic        mess_pull;
    logic [63:0] message;
    logic        mess_last;
    logic        cipher_push;
    logic        cipher_ready;
    logic [63:0] cipher;
    logic        cipher_last;

    // Control Interface
    logic         start;
    logic [127:0] key;
    logic [127:0] nonce;
    logic [1:0]   mode;
    logic         skip_asso;
    logic [127:0] in_tag;
    logic [127:0] out_tag;
    logic         success_tag;
    logic         done;

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Unit Under Test (UUT)
    Ascon_Core uut (.*);

    initial begin
        // Setup
        reset_n = 0; start = 0; mode = 2'b00; // Encrypt
        key   = 128'h08090a0b0c0d0e0f_0001020304050607; // Little-endian order
        nonce = 128'h08090a0b0c0d0e0f_0001020304050607;
        skip_asso = 1'b0;
        cipher_ready = 1'b1;
        mess_valid = 0; message = 0; mess_last = 0;
        
        #20 reset_n = 1;
        #10 start = 1; // Initialization
        #10 start = 0;

        wait(uut.state == 2); // Chờ chuyển sang ASSO_DATA (State 2)
        $display("[%0t] Initialization Complete. IV used: %h", $time, uut.ASCON_IV);

        // Send Associated Data (AD) ---
        @(negedge clk);
        mess_valid = 1;
        message = 64'h3832314e4f435341;; // 8 byte đầu: "ASCON128"
        mess_last = 0;
        wait(mess_pull); // Handshake chu kỳ 1
        
        @(negedge clk);
        message = 64'h0000000000000001; 
        mess_last = 1;
        wait(mess_pull); // Handshake chu kỳ 2
        
        @(negedge clk)
        mess_valid = 0; mess_last = 0;

        wait(uut.state == 3); // Chờ chuyển sang MESSAGE (State 3)
        $display("[%0t] AD Processing Done. State after DSEP: %h", $time, uut.S[4]);

        // send Plaintext (P) 
        @(negedge clk);
        mess_valid = 1;
        message = 64'h6373616f6c6c6568; // "helloasc"
        wait(mess_pull);
        
        @(negedge clk);
        message = 64'h0000000000000001; //  
        mess_last = 1;
        wait(mess_pull);
        
        @(negedge clk);
        mess_valid = 0;

        // Finalization
        wait(done);
        $display("[%0t] AEAD Process Finished!", $time);
        $display("Generated Tag: %h", out_tag);
        
        #100 $finish;
    end

    // Monitor Cipher Output
    always @(posedge clk) begin
        if (cipher_push && cipher_ready) begin
            $display("[%0t] Output Cipher Chunk: %h", $time, cipher);
        end
    end

endmodule
