import GPIO_pkg::*;

module APB_Slave
(
    // APB Bus Interface
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
    
    // Internal GPIO Interface
    output logic                  sys_clk,
    output logic                  sys_rst,
    output logic                  gpio_we,
    output logic [ADDR_WIDTH-1:0] gpio_addr,
    output logic [DATA_WIDTH-1:0] gpio_dat_i,
    input  logic [DATA_WIDTH-1:0] gpio_dat_o,
    input  logic                  gpio_inta_o
);

    // Pass-through clock and reset
    assign sys_clk = PCLK;
    assign sys_rst = PRESETn;

    // APB Write Control: Start write when PSEL, PENABLE and PWRITE are all high
    assign gpio_we    = PSEL & PENABLE & PWRITE;
    assign gpio_addr  = PADDR;
    assign gpio_dat_i = PWDATA;

    // APB Read Control: Return data when PSEL high and PWRITE low
    assign PRDATA = (PSEL & !PWRITE) ? gpio_dat_o : '0;
    
    // PREADY always High (GPIO Register done in 1 cycle)
    assign PREADY = 1'b1;
    
    // Pass-through interrupt
    assign IRQ = gpio_inta_o;

endmodule
