`timescale 1ns / 1ps

module SkewBuffer #(
    parameter DATA_WIDTH = 8,
    parameter ARRAY_SIZE = 4
) (
    input logic clk,
    input logic rst_n,

    input logic signed [DATA_WIDTH-1:0] data_in [ARRAY_SIZE-1:0],

    output logic signed [DATA_WIDTH-1:0] data_out [ARRAY_SIZE-1:0]
);
    genvar i;
    generate
        for(i = 0; i < ARRAY_SIZE; i++) begin: lane
            if(i == 0) 
                assign data_out[i] = data_in[i];
            else begin
                logic signed [DATA_WIDTH-1:0] shift_reg [i-1:0];
                
                always_ff @(posedge clk) begin
                    if(!rst_n) begin
                        for(int k = 0; k < i; k++) begin 
                            shift_reg[k] <= '0;
                        end

                    end
                    else begin
                        shift_reg[0] <= data_in[i];
                        
                        for(int k = 1; k < i; k++) begin
                            shift_reg[k] <= shift_reg[k-1];
                        end
                    end
                end

                assign data_out[i] = shift_reg[i-1];
            end
        end         
    endgenerate

endmodule