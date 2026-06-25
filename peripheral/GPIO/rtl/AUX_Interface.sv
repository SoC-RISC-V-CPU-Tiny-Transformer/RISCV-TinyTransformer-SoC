import GPIO_pkg::*;

module AUX_Interface
(
    input  logic                  sys_clk,
    input  logic                  sys_rst, // Active low (PRESETn)
    input  logic [DATA_WIDTH-1:0] aux_in,
    output logic [DATA_WIDTH-1:0] aux_i
);

    always_ff @(posedge sys_clk or negedge sys_rst) begin
        if (!sys_rst) begin
            aux_i <= '0;
        end else begin
            aux_i <= aux_in;
        end
    end

endmodule
