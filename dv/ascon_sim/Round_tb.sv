`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 04/12/2026 08:35:40 PM
// Module Name: Round_tb
// Project Name: Ascon_128
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module Round_tb;

    task automatic check(input string msg, input logic cond);
        if (cond) begin
            $display("[PASS] %s", msg);
        end
        else begin
            $display("[FAIL] %s", msg);
        end
    endtask;
    
    logic [0:4][63:0] x_in;
    logic [0:4][63:0] x_out; 
    logic [7:0] round_const;
    
    Round r0(x_in, x_out, round_const);
    
    initial begin
        round_const = 8'hf0;
        x_in  = '{default:64'h0};
        #10;
        
        $display("\n── TC1: all zero ──");
        check("TC1: all zero", (x_out[0] == 64'h001e0f00000000f0 && 
                                x_out[1] == 64'h00000001e0000770 &&
                                x_out[2] == 64'h3fffffffffffff74 &&
                                x_out[3] == 64'h3c780000000000f0 &&
                                x_out[4] == 64'h0000000000000000 ));
        #10;    
             
        // ====================================================================
        $display("\n── TC2: single bit ──");
        round_const = 8'hf0;
        x_in[0] = 64'h1;
        x_in[1] = 64'h0;
        x_in[2] = 64'h0;
        x_in[3] = 64'h0;
        x_in[4] = 64'h0;
        #10;
        check("TC2: single bit", (x_out[0] == 64'h001e2f10000000f1 && 
                                  x_out[1] == 64'h00000001e2000779 &&
                                  x_out[2] == 64'h3fffffffffffff74 &&
                                  x_out[3] == 64'h3c388000000000f1 &&
                                  x_out[4] == 64'h0000000000000000 ));                                
        #10;
        
        // ====================================================================
        $display("\n── TC3: pattern ──");
        round_const = 8'he1;
        x_in[0] = 64'hAAAAAAAAAAAAAAAA;
        x_in[1] = 64'h5555555555555555;
        x_in[2] = 64'hAAAAAAAAAAAAAAAA;
        x_in[3] = 64'h5555555555555555;
        x_in[4] = 64'hAAAAAAAAAAAAAAAA;
        #10;
        check("TC3: attern", (x_out[0] == 64'h00140a00000000a0 && 
                              x_out[1] == 64'hfffffffe3dfff816 &&
                              x_out[2] == 64'h51555555555555c7 &&
                              x_out[3] == 64'h38308000000000e1 &&
                              x_out[4] == 64'haaaaaaaaaaaaaaaa ));  

        #10;    

        // ====================================================================
        $display("\n── TC4: incremental ──");
        round_const = 8'hd2;
        x_in[0] = 64'h0000000000000000;
        x_in[1] = 64'h1111111111111111;
        x_in[2] = 64'h2222222222222222;
        x_in[3] = 64'h3333333333333333;
        x_in[4] = 64'h4444444444444444;
        #10;
        check("TC4: incremental", (x_out[0] == 64'h00184c20000000c2 && 
                                   x_out[1] == 64'h2222222382222472 &&
                                   x_out[2] == 64'ha6eeeeeeeeeeee56 &&
                                   x_out[3] == 64'h439e7777777777a5 &&
                                   x_out[4] == 64'h9999999999999999 ));  
        #10;      
        
        // ====================================================================  
        $display("\n── TC5: random ──");  
        round_const = 8'hc3;
        x_in[0] = 64'h0123456789ABCDEF;
        x_in[1] = 64'hFEDCBA9876543210;
        x_in[2] = 64'h0F0F0F0F0F0F0F0F;
        x_in[3] = 64'hF0F0F0F0F0F0F0F0;
        x_in[4] = 64'hAAAAAAAA55555555;
        #10;
        check("TC5: random", (x_out[0] == 64'h83dff92a8e0a109c && 
                              x_out[1] == 64'h9380936db7a2b154 &&
                              x_out[2] == 64'h9e25f952487fa3a9 &&
                              x_out[3] == 64'hce5b95861bb5877d &&
                              x_out[4] == 64'h6151841dc02dcb8f ));     
        $finish;    
    end
    
endmodule
