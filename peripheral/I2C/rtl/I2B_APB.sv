`timescale 1ns/1ps

interface APB #(parameter ADDR_WIDTH = 12, DATA_WIDTH = 32);
    logic                    psel;
    logic                    penable;
    logic                    pwrite;
    logic [ADDR_WIDTH-1:0]   paddr;
    logic [DATA_WIDTH-1:0]   pwdata;
    logic [DATA_WIDTH-1:0]   prdata;
    logic                    pready;
    logic                    pslverr;

    modport slave (
        input  psel, penable, pwrite, paddr, pwdata,
        output prdata, pready, pslverr
    );
    
    modport master (
        output psel, penable, pwrite, paddr, pwdata,
        input  prdata, pready, pslverr
    );
endinterface
