`timescale 1ns / 1ps

module Ascon_Core_tb();

    logic         clk;
    logic         rst_n;

    // CPU Control
    logic         start;
    logic         variant_128a;
    logic         has_ad;
    logic         has_msg;
    logic         decrypt_mode;
    logic [127:0] key;
    logic [127:0] nonce;
    logic         done;

    // DMA Data In
    logic [127:0] cipher_in;
    logic [15:0]  t_keep;
    logic         data_valid;
    logic         data_last;
    logic         data_ready;

    // Output Data
    logic [127:0] cipher_out;
    logic [127:0] tag_out;
    logic         msg_valid;
    logic         tag_valid;

    // Clock (10ns -> 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Ascon_Core
    Ascon_Core dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .variant_128a   (variant_128a),
        .has_ad         (has_ad),
        .has_msg        (has_msg),
        .decrypt_mode   (decrypt_mode),
        .key            (key),
        .nonce          (nonce),
        .done           (done),
        .cipher_in      (cipher_in),
        .t_keep         (t_keep),
        .data_valid     (data_valid),
        .data_last      (data_last),
        .data_ready     (data_ready),
        .cipher_out     (cipher_out),
        .tag_out        (tag_out),
        .msg_valid      (msg_valid),
        .tag_valid      (tag_valid)
    );

    // MONITOR

    always @(posedge clk) begin
        if (msg_valid) begin
            // Message (Ciphertext)
            $display("[$time ns] CIPHERTEXT OUT: %h", cipher_out);
        end
        if (tag_valid) begin
            $display("[$time ns] TAG OUT: %h", tag_out);
        end
        if (done) begin
            $display("[$time ns] --- ENCRYPTION COMPLETE ---");
            $finish; 
        end
    end

    // TEST SEQUENCE
    initial begin

        rst_n        = 0;
        start        = 0;
        data_valid   = 0;
        data_last    = 0;
        cipher_in      = 128'h0;

        variant_128a = 1;       // ASCON-128a
        decrypt_mode = 0;       // encryption
        has_ad       = 1;       
        has_msg      = 1;       
        key          = 128'h0;  
        nonce        = 128'h0;  

        #22 rst_n = 1;         
        
        @(negedge clk);
        $display("[$time ns] --- STARTING ASCON-128a ENCRYPTION ---");
        start = 1;
        @(negedge clk); 
        start = 0;

        // PHASE 1: SEND ASSOCIATED DATA (AD)
        wait(data_ready == 1); // Wait FSM signals ready to receive data
        @(negedge clk);        
        
        $display("[$time ns] DMA: Loading AD...");
        cipher_in    = 128'h4141414141414141_4141414141414141; 
        t_keep       = 16'hFFFF; 
        data_valid = 1;
        data_last  = 1; 

        @(negedge clk);        
        data_valid = 0; 
        data_last  = 0;

        // PHASE 2: SEND PLAINTEXT (MSG)
        wait(data_ready == 1); 
        @(negedge clk);       
        
        $display("[$time ns] DMA: Loading MSG...");
        cipher_in    = 128'h48454C4C4F48454C_4C4F48454C4C4F48; 
        t_keep       = 16'hFFFF; 
        data_valid = 1;
        data_last  = 1;
        
        @(negedge clk);
        data_valid = 0;
        data_last  = 0;

    end

endmodule
