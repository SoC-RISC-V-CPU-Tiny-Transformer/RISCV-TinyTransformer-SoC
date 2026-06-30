import dma_pkg::*;

module dma_s2mm 
(
    input  logic clk, rst_n,

    input  logic start,
    input  logic [ADDR_WIDTH-1:0] dst_addr,
    input  logic [ADDR_WIDTH-1:0] length, 
    output logic done,

    output logic [ADDR_WIDTH-1:0] awaddr,
    output logic [AXI_LEN_WIDTH-1:0] awlen,
    output logic awvalid,
    input  logic awready,
    
    output logic [DATA_WIDTH-1:0] wdata,
    output logic [KEEP_WIDTH-1:0] wstrb,
    output logic wlast,
    output logic wvalid,
    input  logic wready,
    
    input  logic [1:0] bresp,
    input  logic bvalid,
    output logic bready,

    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic [KEEP_WIDTH-1:0] s_axis_tstrb,
    input  logic [KEEP_WIDTH-1:0] s_axis_tkeep,
    input  logic s_axis_tvalid,
    output logic s_axis_tready,
    input  logic s_axis_tlast
);
    typedef enum logic [1:0] {IDLE, ISSUE_AW, STREAMING_OUT, WAIT_RESP} state_t;
    state_t state, next_state;

    wire [AXI_LEN_WIDTH-1:0] burst_beats = (length == 0) ? 8'h00 : ((length - 1) >> 3);

    localparam FIFO_WIDTH = DATA_WIDTH + 1 + KEEP_WIDTH;
    logic fifo_full, fifo_empty;
    logic fifo_we, fifo_re;
    logic [FIFO_WIDTH-1:0] fifo_wdata;
    logic [FIFO_WIDTH-1:0] fifo_rdata;

    sync_fifo #(
        .WIDTH(FIFO_WIDTH), 
        .DEPTH_L2(FIFO_DEPTH_LOG2)
    ) u_fifo_s2mm (
        .clk(clk), .rst_n(rst_n),
        .wr_en(fifo_we), .wr_data(fifo_wdata), .full(fifo_full),
        .rd_en(fifo_re), .rd_data(fifo_rdata), .empty(fifo_empty)
    );

    assign s_axis_tready = !fifo_full;
    assign fifo_we       = s_axis_tvalid && s_axis_tready;
    assign fifo_wdata    = {s_axis_tkeep, s_axis_tlast, s_axis_tdata}; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always_comb begin
        next_state = state;
        awvalid    = 1'b0;
        bready     = 1'b0;
        done       = 1'b0;

        case (state)
            IDLE:          if (start) next_state = ISSUE_AW;
            ISSUE_AW:      begin
                               awvalid = 1'b1;
                               if (awready) next_state = STREAMING_OUT;
                           end
            STREAMING_OUT: if (wvalid && wready && wlast) next_state = WAIT_RESP;
            WAIT_RESP:     begin
                               bready = 1'b1;
                               if (bvalid) begin
                                   done = 1'b1;
                                   next_state = IDLE;
                               end
                           end
            default:       next_state = IDLE;
        endcase
    end

    assign awaddr = dst_addr;
    assign awlen  = burst_beats;

    assign wvalid = !fifo_empty && (state == STREAMING_OUT);
    
    assign wdata  = fifo_rdata[DATA_WIDTH-1:0];
    assign wlast  = fifo_rdata[DATA_WIDTH];
    assign wstrb  = fifo_rdata[DATA_WIDTH + KEEP_WIDTH : DATA_WIDTH + 1];
    
    assign fifo_re = wvalid && wready;

endmodule
