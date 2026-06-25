import UART_pkg::*;

module Baud_Gen #(
    parameter int BAUD_RATE  = 921600,
    parameter int CLK_FREQ   = 100_000_000,
    parameter int OVERSAMPLE = 16          
) (
    input  logic clk,
    input  logic reset_n,
    output logic BCLK
);

    localparam int OVERSAMPLE_RATE = BAUD_RATE * OVERSAMPLE;
    localparam int DIVISOR         = (CLK_FREQ + (OVERSAMPLE_RATE / 2)) / OVERSAMPLE_RATE;
    
    logic [15:0] counter;
    
    // Sử dụng negedge cho tín hiệu reset_n (Active-Low)
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            BCLK    <= 1'b0;
            counter <= '0;
        end
        else if (counter == 16'(DIVISOR - 1)) begin
            BCLK    <= 1'b1;
            counter <= '0;
        end
        else begin
            BCLK    <= 1'b0;
            counter <= counter + 16'd1;
        end
    end
endmodule
