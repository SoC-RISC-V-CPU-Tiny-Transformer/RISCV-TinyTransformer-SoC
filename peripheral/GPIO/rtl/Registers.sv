import GPIO_pkg::*;

module gpio_registers 
(
    input  logic                  sys_clk,
    input  logic                  sys_rst,
    
    // Internal Bus
    input  logic                  gpio_we,
    input  logic [ADDR_WIDTH-1:0] gpio_addr,
    input  logic [DATA_WIDTH-1:0] gpio_dat_i,
    output logic [DATA_WIDTH-1:0] gpio_dat_o,
    output logic                  gpio_inta_o,
    
    // Pad & Aux connections
    input  logic [DATA_WIDTH-1:0] in_pad_i,
    input  logic [DATA_WIDTH-1:0] aux_i,
    output logic [DATA_WIDTH-1:0] out_pad_o,
    output logic [DATA_WIDTH-1:0] oen_padoe_o,
    input  logic                  gpio_eclk
);

    // Register Instantiation
    logic [DATA_WIDTH-1:0] reg_data_out;
    logic [DATA_WIDTH-1:0] reg_dir;
    logic [DATA_WIDTH-1:0] reg_int_status;
    
    // Synchronizer for input pad signals to avoid metastability
    logic [DATA_WIDTH-1:0] in_pad_sync1, in_pad_sync2;
    always_ff @(posedge sys_clk or negedge sys_rst) begin
        if (!sys_rst) begin
            in_pad_sync1 <= '0;
            in_pad_sync2 <= '0;
        end else begin
            in_pad_sync1 <= in_pad_i;
            in_pad_sync2 <= in_pad_sync1;
        end
    end

    logic [DATA_WIDTH-1:0] int_set_event;
    assign int_set_event = in_pad_sync1 & ~in_pad_sync2; // Detect rising edge on input pads

    // Update Data (Read/Write APB & Interrupt Logic)
    always_ff @(posedge sys_clk or negedge sys_rst) begin
        if (!sys_rst) begin
            reg_data_out   <= '0;
            reg_dir        <= '0;
            reg_int_status <= '0;
        end 
        else begin
            reg_int_status <= reg_int_status | int_set_event;

            if (gpio_we) begin
                case (gpio_addr[3:2]) // 2 highest bits of PADDR[3:0]
                    2'b00: reg_data_out <= gpio_dat_i; // Offset 0x0
                    2'b01: reg_dir      <= gpio_dat_i; // Offset 0x4
                    
                    2'b11: begin // Offset 0xC (W1C - Write 1 to Clear)
                        // If CPU deletes interrupt (gpio_dat_i = 1), new interrupt (int_set_event = 1)
                        reg_int_status <= (reg_int_status | int_set_event) & ~gpio_dat_i;
                    end
                endcase
            end
        end
    end

    // Read Operation
    always_comb begin
        gpio_dat_o = '0;
        case (gpio_addr[3:2])
            2'b00: gpio_dat_o = reg_data_out;
            2'b01: gpio_dat_o = reg_dir;
            2'b10: gpio_dat_o = in_pad_sync2; // Read the synchronized value
            2'b11: gpio_dat_o = reg_int_status;
        endcase
    end

    assign out_pad_o   = reg_data_out;
    assign oen_padoe_o = reg_dir;

    assign gpio_inta_o = |reg_int_status; // Interrupt if any bit is set

endmodule
