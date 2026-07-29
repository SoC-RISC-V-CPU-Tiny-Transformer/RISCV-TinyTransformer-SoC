//////////////////////////////////////////////////////////////////////////////////
// Engineer: Hung Nguyen
// Create Date: 06/28/2026 06:58:58 PM
// Module Name: AxiLite_Slave
// Project Name: Ascon_128AEAD
//////////////////////////////////////////////////////////////////////////////////

import ascon_pkg::*;

module AxiLite_Slave
(
    input  logic         CLK,
    input  logic         RESETN,

    // AXI-Lite Slave Interface
    input  logic [7:0]   s_axi_awaddr,
    input  logic         s_axi_awvalid,
    output logic         s_axi_awready,
    input  logic [31:0]  s_axi_wdata,
    input  logic [3:0]   s_axi_wstrb,
    input  logic         s_axi_wvalid,
    output logic         s_axi_wready,
    output logic [1:0]   s_axi_bresp,
    output logic         s_axi_bvalid,
    input  logic         s_axi_bready,
    input  logic [7:0]   s_axi_araddr,
    input  logic         s_axi_arvalid,
    output logic         s_axi_arready,
    output logic [31:0]  s_axi_rdata,
    output logic [1:0]   s_axi_rresp,
    output logic         s_axi_rvalid,
    input  logic         s_axi_rready,


    output logic         core_start,
    output logic [1:0]   core_mode,
    output logic         core_skip_asso,
    output logic [127:0] core_key,
    output logic [127:0] core_nonce,
    output logic [127:0] core_in_tag,

    // Receive input (from ASCON Core)
    input  logic [127:0] core_out_tag,
    input  logic         core_success,
    input  logic         core_done
);

    // Little-Endian from CPU
    logic reg_start;
    logic reg_skip_asso;
    logic [1:0] reg_mode;
    logic [127:0] reg_key;
    logic [127:0] reg_nonce;
    logic [127:0] reg_in_tag;

    logic reg_done;
    logic reg_success;

    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_arready = 1'b1;
    assign s_axi_bresp   = 2'b00; 
    assign s_axi_rresp   = 2'b00; 

    // WRITE LOGIC 
    always_ff @(posedge CLK or negedge RESETN) begin
        if (!RESETN) begin
            reg_start     <= 1'b0;
            reg_skip_asso <= 1'b0;
            reg_mode      <= 2'b00;
            reg_key       <= '0;
            reg_nonce     <= '0;
            reg_in_tag    <= '0;
            s_axi_bvalid  <= 1'b0;
            reg_done      <= 1'b0; 
            reg_success   <= 1'b0;
        end else begin
            if (reg_start) begin
                reg_start <= 1'b0; // Auto-clear start
                reg_done  <= 1'b0;
            end

            if (core_done) begin
                reg_done    <= 1'b1;
                reg_success <= core_success;
            end

            if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                case (s_axi_awaddr[7:2])
                    6'h00: begin 
                        reg_start     <= s_axi_wdata[0];
                        reg_skip_asso <= s_axi_wdata[1];
                        reg_mode      <= s_axi_wdata[3:2];
                    end
                    6'h04: reg_key[31:0]   <= s_axi_wdata;
                    6'h05: reg_key[63:32]  <= s_axi_wdata;
                    6'h06: reg_key[95:64]  <= s_axi_wdata;
                    6'h07: reg_key[127:96] <= s_axi_wdata;
                    6'h08: reg_nonce[31:0]   <= s_axi_wdata;
                    6'h09: reg_nonce[63:32]  <= s_axi_wdata;
                    6'h0A: reg_nonce[95:64]  <= s_axi_wdata;
                    6'h0B: reg_nonce[127:96] <= s_axi_wdata;
                    6'h0C: reg_in_tag[31:0]   <= s_axi_wdata;
                    6'h0D: reg_in_tag[63:32]  <= s_axi_wdata;
                    6'h0E: reg_in_tag[95:64]  <= s_axi_wdata;
                    6'h0F: reg_in_tag[127:96] <= s_axi_wdata;
                    default: ;
                endcase
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ENDIANNESS CONVERSION 
    assign core_start     = reg_start;
    assign core_mode      = reg_mode;
    assign core_skip_asso = reg_skip_asso;
    
    assign core_key    = { reg_key[127:64], reg_key[63:0] };
    assign core_nonce  = { reg_nonce[127:64], reg_nonce[63:0] };
    assign core_in_tag = { reg_in_tag[127:64], reg_in_tag[63:0] };

    // ASCON return Big Endian -> Little Endian 
    logic [127:0] reg_out_tag_le; 
    assign reg_out_tag_le = { core_out_tag[127:64], core_out_tag[63:0]};

    // READ LOGIC
    always_ff @(posedge CLK or negedge RESETN) begin
        if (!RESETN) begin
            s_axi_rdata  <= '0;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (s_axi_arvalid && s_axi_arready && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                case (s_axi_araddr[7:2])
                    6'h00: s_axi_rdata <= {28'd0, reg_mode, reg_skip_asso, 1'b0}; 
                    6'h01: s_axi_rdata <= {30'd0, reg_success, reg_done};
                    6'h10: s_axi_rdata <= reg_out_tag_le[31:0];
                    6'h11: s_axi_rdata <= reg_out_tag_le[63:32];
                    6'h12: s_axi_rdata <= reg_out_tag_le[95:64];
                    6'h13: s_axi_rdata <= reg_out_tag_le[127:96];
                    default: s_axi_rdata <= '0;
                endcase
            end else if (s_axi_rready && s_axi_rvalid) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule

