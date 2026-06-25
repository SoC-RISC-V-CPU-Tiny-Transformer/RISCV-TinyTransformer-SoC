import GPIO_pkg::*;

module IO_Interface 
(
    input  logic [DATA_WIDTH-1:0] out_pad_o,
    input  logic [DATA_WIDTH-1:0] oen_padoe_o,
    output logic [DATA_WIDTH-1:0] in_pad_i,
    inout  wire  [DATA_WIDTH-1:0] io_pad
);

    // Output driver: When oen_padoe_o = 1, pad drives out_pad_o
    // When oen_padoe_o = 0, pad is in high-impedance state (acts as input)
    genvar i;
    generate
        for (i = 0; i < DATA_WIDTH; i++) begin : io_buffer
            assign io_pad[i] = oen_padoe_o[i] ? out_pad_o[i] : 1'bz;
        end
    endgenerate

    // Input receiver: Always reads the current value on the pin
    assign in_pad_i = io_pad;

endmodule
