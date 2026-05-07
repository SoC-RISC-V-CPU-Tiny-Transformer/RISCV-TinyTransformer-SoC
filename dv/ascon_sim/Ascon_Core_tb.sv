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
    logic [127:0] in_tag = 128'hb79bb3b7b59a7d21536cc1e027aaa4a9;
    logic [127:0] out_tag;
    logic         success_tag;
    logic         done;

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Unit Under Test (UUT)
    Ascon_Core uut (.*);

    // TASK: Giả lập cơ chế Handshake chuẩn AXI-Stream
    task send_data(input logic [63:0] data, input logic last);
    begin
        @(negedge clk);
        mess_valid = 1;
        message = data;
        mess_last = last;
        
        @(posedge clk);
        while (!mess_pull) begin
            @(posedge clk); 
        end
    end
    endtask

    initial begin
        // Setup
        reset_n = 0; start = 0; mode = 2'b01; // Decrypt
        key   = 128'h08090a0b0c0d0e0f_0001020304050607; 
        nonce = 128'h08090a0b0c0d0e0f_0001020304050607;
        skip_asso = 1'b0;
        cipher_ready = 1'b1;
        mess_valid = 0; message = 0; mess_last = 0;
        
        #20 reset_n = 1;
        #10 start = 1; // Initialization
        #10 start = 0;

        
        // Send Associated Data (AD) 
        send_data(64'h3832314e4f435341, 0); // "ASCON128"
        send_data(64'h0000000000000001, 1); // Padding
        
        @(negedge clk);
        mess_valid = 0; mess_last = 0; 

        // Send Plaintext 
        // send_data(64'h6373616f6c6c6568, 0); // "helloasc"
        // send_data(64'h0000000000000001, 1); // Padding
        send_data(64'h766d747b615aafb2, 1); 
        send_data(64'hd670720afc483196, 1); // Padding
        @(negedge clk);
        mess_valid = 0; mess_last = 0; 

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
