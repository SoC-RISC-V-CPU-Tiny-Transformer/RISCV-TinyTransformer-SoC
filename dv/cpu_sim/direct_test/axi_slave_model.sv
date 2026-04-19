// -----------------------------------------------------------------------------
// Copyright (c) 2026 NGUYEN TO QUOC VIET
// Ho Chi Minh City University of Technology (HCMUT-VNU)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit Processor
// Module       : axi_slave_model
// Description  : Behavioral AXI4 Slave Memory Model
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-13
// Version      : 1.0
// -----------------------------------------------------------------------------

module axi_slave_model
    import cache_pkg::*;
    import axi_pkg::*;
#(
    parameter int MEM_SIZE      = 65536, //memory size, 64KB
    parameter int READ_LATENCY  = 15,    
    parameter int WRITE_LATENCY = 10,    
    parameter bit VERBOSE       = 1'b1   //print transaction log to console
)(
    //system
    input logic clk, rst_n,

    //AXI4 slave - read addr channel
    input  logic                    s_axi_arvalid,
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [7:0]              s_axi_arlen,
    input  logic [2:0]              s_axi_arsize,
    input  logic [1:0]              s_axi_arburst,

    output logic                    s_axi_arready,

    //AXI4 slave - read data channel
    output logic                    s_axi_rvalid,
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rlast,

    input  logic                    s_axi_rready,

    //AXI4 slave - write addr channel
    input  logic                    s_axi_awvalid,
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [7:0]              s_axi_awlen,
    input  logic [2:0]              s_axi_awsize,
    input  logic [1:0]              s_axi_awburst,

    output logic                    s_axi_awready,

    //AXI4 slave - write data channel
    input  logic                    s_axi_wvalid,
    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [STRB_WIDTH-1:0]   s_axi_wstrb,
    input  logic                    s_axi_wlast,

    output logic                    s_axi_wready,

    //AXI4 slave - write response channel
    output logic                    s_axi_bvalid,
    output logic [1:0]              s_axi_bresp,

    input  logic                    s_axi_bready
);
    //memory, little-endian
    logic [7:0] mem [0:MEM_SIZE-1];

    //READ PATH 
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_WAIT,    //DDR3 access latency (CAS + tRCD + controller + AXI overhead)
        RD_DATA
    } rd_state_t;

    rd_state_t rd_state, rd_next_state;

    logic [ADDR_WIDTH-1:0]  rd_addr_base;   
    logic [ADDR_WIDTH-1:0]  rd_addr_start;  //cwf
    logic [7:0]             rd_beat_total;  
    logic [7:0]             rd_beat_cnt;    //current beat index
    logic [4:0]             rd_lat_cnt;     //latency counter 

    //WRAP burst address: base | ((start + beat*4) & 0xF)
    //wrap boundary = (arlen+1)*4 = 16 bytes -> mask = 0xF
    logic [ADDR_WIDTH-1:0] rd_cur_addr;
    assign rd_cur_addr = rd_addr_base | ((rd_addr_start + (32'(rd_beat_cnt) << 2)) & 32'hF);

    //read next state fsm
    always_comb begin
        rd_next_state = rd_state;

        case (rd_state)
            RD_IDLE: begin
                if (s_axi_arvalid)
                    rd_next_state = (READ_LATENCY == 0) ? RD_DATA : RD_WAIT;
            end

            RD_WAIT: begin
                if (rd_lat_cnt == 5'(READ_LATENCY - 1))
                    rd_next_state = RD_DATA;
            end

            RD_DATA: begin
                if (s_axi_rvalid && s_axi_rready && s_axi_rlast)
                    rd_next_state = RD_IDLE;
            end
        endcase
    end

    //read register fsm
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state        <= RD_IDLE;
            rd_addr_base    <= '0;
            rd_addr_start   <= '0;
            rd_beat_total   <= '0;
            rd_beat_cnt     <= '0;
            rd_lat_cnt      <= '0;
        end else begin
            rd_state <= rd_next_state;

            case (rd_state)
                RD_IDLE: begin
                    if (s_axi_arvalid) begin
                        rd_addr_start   <= s_axi_araddr;
                        rd_addr_base    <= s_axi_araddr & ~32'hF;   //16-byte align
                        rd_beat_total   <= s_axi_arlen;
                        rd_beat_cnt     <= '0;
                        rd_lat_cnt      <= '0;
                        if (VERBOSE)
                            $display("[MEM][RD ] addr=0x%08h  len=%0d  burst=%02b  @%0t",
                                     s_axi_araddr, s_axi_arlen, s_axi_arburst, $time);
                    end
                end

                RD_WAIT: begin
                    rd_lat_cnt <= rd_lat_cnt + 1'b1;
                end

                RD_DATA: begin
                    if (s_axi_rready)
                        rd_beat_cnt <= rd_beat_cnt + 1'b1;
                end
            endcase
        end
    end

    //read output fsm
    always_comb begin
        s_axi_arready   = (rd_state == RD_IDLE);
        s_axi_rvalid    = (rd_state == RD_DATA);
        s_axi_rresp     = AXI_RESP_OKAY;
        s_axi_rlast     = (rd_state == RD_DATA) && (rd_beat_cnt == rd_beat_total);

        //little-endian word assembly from byte array
        s_axi_rdata     = {mem[rd_cur_addr+3], mem[rd_cur_addr+2], mem[rd_cur_addr+1], mem[rd_cur_addr+0]};
    end

    //WRITE PATH
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA,
        WR_WAIT,    //DDR3 write commit latency (tWR + controller overhead)
        WR_RESP
    } wr_state_t;

    wr_state_t wr_state, wr_next_state;

    logic [ADDR_WIDTH-1:0]  wr_addr_lat;
    logic [4:0]             wr_lat_cnt; //latency counter (supports up to 31 cycles)

    //write next state fsm
    always_comb begin
        wr_next_state = wr_state;

        case (wr_state)
            WR_IDLE: begin
                if (s_axi_awvalid)
                    wr_next_state = WR_DATA;
            end

            WR_DATA: begin
                if (s_axi_wvalid && s_axi_wlast)
                    wr_next_state = (WRITE_LATENCY == 0) ? WR_RESP : WR_WAIT;
            end

            WR_WAIT: begin
                if (wr_lat_cnt == 5'(WRITE_LATENCY - 1))
                    wr_next_state = WR_RESP;
            end

            WR_RESP: begin
                if (s_axi_bready)
                    wr_next_state = WR_IDLE;
            end
        endcase
    end

    //write register fsm
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state    <= WR_IDLE;
            wr_addr_lat <= '0;
            wr_lat_cnt  <= '0;
        end else begin
            wr_state <= wr_next_state;

            case (wr_state)
                WR_IDLE: begin
                    if (s_axi_awvalid) begin
                        wr_addr_lat <= s_axi_awaddr;

                        if (VERBOSE)
                            $display("[MEM][WR ] addr=0x%08h  @%0t",
                                     s_axi_awaddr, $time);
                    end
                end

                WR_DATA: begin
                    if (s_axi_wvalid) begin
                        //apply byte-enable, commit to backing store
                        for (int b = 0; b < STRB_WIDTH; b++) begin
                            if (s_axi_wstrb[b])
                                mem[wr_addr_lat + b] <= s_axi_wdata[b*8 +: 8];
                        end
                        if (s_axi_wlast)
                            wr_lat_cnt <= '0;
                    end
                end

                WR_WAIT: begin
                    wr_lat_cnt <= wr_lat_cnt + 1'b1;
                end

                WR_RESP: ;

            endcase
        end
    end

    //write output fsm
    assign s_axi_awready = (wr_state == WR_IDLE);
    assign s_axi_wready  = (wr_state == WR_DATA);
    assign s_axi_bvalid  = (wr_state == WR_RESP);
    assign s_axi_bresp   = AXI_RESP_OKAY;
 
    //MEMORY UTILS 

    //preload from file hex 
    task automatic preload_from_file(input string filepath);
        $readmemh(filepath, mem);

        if (VERBOSE)
            $display("[MEM] preloaded from \"%s\"", filepath);
    endtask

    //ghi 1 word (little-endian) truc tiep vao backing store
    task automatic write_word(input logic [ADDR_WIDTH-1:0] addr,
                               input logic [DATA_WIDTH-1:0] data);
        mem[addr+0] = data[7:0];
        mem[addr+1] = data[15:8];
        mem[addr+2] = data[23:16];
        mem[addr+3] = data[31:24];
    endtask

    //doc 1 word (little-endian) tu backing store de verify trong testbench
    function automatic logic [DATA_WIDTH-1:0] read_word(
        input logic [ADDR_WIDTH-1:0] addr);
        return {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr+0]};
    endfunction
endmodule
