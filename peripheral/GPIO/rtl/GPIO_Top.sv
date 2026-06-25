import GPIO_pkg::*;

module GPIO_Top 
(
    // APB Host Interface
    input  logic                  PCLK,
    input  logic                  PRESETn,
    input  logic                  PSEL,
    input  logic                  PENABLE,
    input  logic                  PWRITE,
    input  logic [ADDR_WIDTH-1:0] PADDR,
    input  logic [DATA_WIDTH-1:0] PWDATA,
    output logic [DATA_WIDTH-1:0] PRDATA,
    output logic                  PREADY,
    output logic                  IRQ,
    
    // AUX & Pads Interface
    input  logic [DATA_WIDTH-1:0] aux_in,
    input  logic                  ext_clk_pad_i,
    inout  wire  [DATA_WIDTH-1:0] io_pad
);

    // Internal Wires
    logic                  sys_clk;
    logic                  sys_rst;
    logic                  gpio_we;
    logic [ADDR_WIDTH-1:0] gpio_addr;
    logic [DATA_WIDTH-1:0] gpio_dat_i;
    logic [DATA_WIDTH-1:0] gpio_dat_o;
    logic                  gpio_inta_o;
    
    logic [DATA_WIDTH-1:0] out_pad_o;
    logic [DATA_WIDTH-1:0] oen_padoe_o;
    logic [DATA_WIDTH-1:0] in_pad_i;
    logic [DATA_WIDTH-1:0] aux_i;

    // APB Slave Interface
    APB_Slave u_apb_intf 
    (
        .PCLK       (PCLK),
        .PRESETn    (PRESETn),
        .PSEL       (PSEL),
        .PENABLE    (PENABLE),
        .PWRITE     (PWRITE),
        .PADDR      (PADDR),
        .PWDATA     (PWDATA),
        .PRDATA     (PRDATA),
        .PREADY     (PREADY),
        .IRQ        (IRQ),
        .sys_clk    (sys_clk),
        .sys_rst    (sys_rst),
        .gpio_we    (gpio_we),
        .gpio_addr  (gpio_addr),
        .gpio_dat_i (gpio_dat_i),
        .gpio_dat_o (gpio_dat_o),
        .gpio_inta_o(gpio_inta_o)
    );

    AUX_Interface u_aux_intf 
    (
        .sys_clk (sys_clk),
        .sys_rst (sys_rst),
        .aux_in  (aux_in),
        .aux_i   (aux_i)
    );

    Registers u_gpio_regs 
    (
        .sys_clk     (sys_clk),
        .sys_rst     (sys_rst),
        .gpio_we     (gpio_we),
        .gpio_addr   (gpio_addr),
        .gpio_dat_i  (gpio_dat_i),
        .gpio_dat_o  (gpio_dat_o),
        .gpio_inta_o (gpio_inta_o),
        .in_pad_i    (in_pad_i),
        .aux_i       (aux_i),
        .out_pad_o   (out_pad_o),
        .oen_padoe_o (oen_padoe_o),
        .gpio_eclk   (ext_clk_pad_i)
    );

    IO_Interface u_io_intf 
    (
        .out_pad_o   (out_pad_o),
        .oen_padoe_o (oen_padoe_o),
        .in_pad_i    (in_pad_i),
        .io_pad      (io_pad)
    );

endmodule
