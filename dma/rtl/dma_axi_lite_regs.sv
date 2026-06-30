import dma_pkg::*;

module dma_axi_lite_regs 
(
    input  logic clk, rst_n,

    // AXI-Lite Write Interface 
    input  logic [AXI_LITE_ADDR_WIDTH-1:0] awaddr,
    input  logic awvalid,
    output logic awready,
    input  logic [AXI_LITE_DATA_WIDTH-1:0] wdata,
    input  logic wvalid,
    output logic wready,
    output logic [1:0] bresp,
    output logic bvalid,
    input  logic bready,

    // AXI-Lite Read Interface 
    input  logic [AXI_LITE_ADDR_WIDTH-1:0] araddr,
    input  logic arvalid,
    output logic arready,
    output logic [AXI_LITE_DATA_WIDTH-1:0] rdata,
    output logic [1:0] rresp,
    output logic rvalid,
    input  logic rready,

    // Output config DMA Core
    output logic [ADDR_WIDTH-1:0] mm2s_src_addr,
    output logic [ADDR_WIDTH-1:0] mm2s_length,
    output logic                  mm2s_start,
    input  logic                  mm2s_done,

    output logic [ADDR_WIDTH-1:0] s2mm_dst_addr,
    output logic [ADDR_WIDTH-1:0] s2mm_length,
    output logic                  s2mm_start,
    input  logic                  s2mm_done
);
    logic [AXI_LITE_DATA_WIDTH-1:0] slv_reg0; // Start & Status
    logic [AXI_LITE_DATA_WIDTH-1:0] slv_reg1; // MM2S Src
    logic [AXI_LITE_DATA_WIDTH-1:0] slv_reg2; // MM2S Len
    logic [AXI_LITE_DATA_WIDTH-1:0] slv_reg3; // S2MM Dst
    logic [AXI_LITE_DATA_WIDTH-1:0] slv_reg4; // S2MM Len

    assign awready = 1'b1;
    assign wready  = 1'b1;
    assign bresp   = 2'b00;

    assign arready = 1'b1;
    assign rresp   = 2'b00;

    // Write Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slv_reg0 <= '0;
            slv_reg1 <= '0; slv_reg2 <= '0;
            slv_reg3 <= '0; slv_reg4 <= '0; 
            bvalid   <= 1'b0;
        end else begin
            if (awvalid && wvalid && !bvalid) begin
                bvalid <= 1'b1;
                case (awaddr[AXI_LITE_ADDR_WIDTH-1:2])
                    3'h0: slv_reg0 <= wdata;
                    3'h1: slv_reg1 <= wdata;
                    3'h2: slv_reg2 <= wdata;
                    3'h3: slv_reg3 <= wdata;
                    3'h4: slv_reg4 <= wdata;
                    default: ; 
                endcase
            end else if (bready && bvalid) begin
                bvalid <= 1'b0;
            end

            // Clear start bit (Self-clearing)
            if (slv_reg0[0]) slv_reg0[0] <= 1'b0;
            if (slv_reg0[1]) slv_reg0[1] <= 1'b0;
            
            // Update state done into reg0 (Read-only status)
            slv_reg0[4] <= mm2s_done;
            slv_reg0[5] <= s2mm_done;
        end
    end

    // Read Logic 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid <= 1'b0;
            rdata  <= '0;
        end else begin
            if (arvalid && arready && !rvalid) begin
                rvalid <= 1'b1;
                case (araddr[AXI_LITE_ADDR_WIDTH-1:2])
                    3'h0: rdata <= slv_reg0;
                    3'h1: rdata <= slv_reg1;
                    3'h2: rdata <= slv_reg2;
                    3'h3: rdata <= slv_reg3;
                    3'h4: rdata <= slv_reg4;
                    default: rdata <= '0;
                endcase
            end else if (rready && rvalid) begin
                rvalid <= 1'b0;
            end
        end
    end

    assign mm2s_start    = slv_reg0[0];
    assign s2mm_start    = slv_reg0[1];
    assign mm2s_src_addr = slv_reg1[ADDR_WIDTH-1:0];
    assign mm2s_length   = slv_reg2[ADDR_WIDTH-1:0];
    assign s2mm_dst_addr = slv_reg3[ADDR_WIDTH-1:0];
    assign s2mm_length   = slv_reg4[ADDR_WIDTH-1:0];

endmodule
