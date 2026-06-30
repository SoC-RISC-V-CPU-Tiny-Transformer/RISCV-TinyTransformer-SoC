import dma_pkg::*;

module dma_mm2s 
(
    input  logic clk, rst_n,

    input  logic start,
    input  logic [ADDR_WIDTH-1:0] src_addr,
    input  logic [ADDR_WIDTH-1:0] length, 
    output logic done,

    output logic [ADDR_WIDTH-1:0] araddr,
    output logic [AXI_LEN_WIDTH-1:0] arlen, 
    output logic arvalid,
    input  logic arready,
    input  logic [DATA_WIDTH-1:0] rdata,
    input  logic rlast,
    input  logic rvalid,
    output logic rready,

    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic [KEEP_WIDTH-1:0] m_axis_tstrb,
    output logic [KEEP_WIDTH-1:0] m_axis_tkeep,
    output logic m_axis_tvalid,
    input  logic m_axis_tready,
    output logic m_axis_tlast
);
    typedef enum logic [1:0] {IDLE, ISSUE_AR, STREAMING_IN, DONE_ST} state_t;
    state_t state, next_state;

    wire [AXI_LEN_WIDTH-1:0] burst_beats = (length == 0) ? 8'h00 : ((length - 1) >> 3); 

    localparam FIFO_WIDTH = DATA_WIDTH + 1;
    logic fifo_full, fifo_empty;
    logic fifo_we, fifo_re;
    logic [FIFO_WIDTH-1:0] fifo_wdata;
    logic [FIFO_WIDTH-1:0] fifo_rdata;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always_comb begin
        next_state = state;
        arvalid    = 1'b0;
        done       = 1'b0;

        case (state)
            IDLE:         if (start) next_state = ISSUE_AR;
            ISSUE_AR:     begin
                              arvalid = 1'b1;
                              if (arready) next_state = STREAMING_IN;
                          end
            STREAMING_IN: if (rvalid && rready && rlast) next_state = DONE_ST;
            DONE_ST:      begin
                              done = 1'b1;
                              next_state = IDLE;
                          end
            default:      next_state = IDLE;
        endcase
    end

    assign araddr = src_addr;
    assign arlen  = burst_beats;

    assign rready     = (state == STREAMING_IN) && !fifo_full;
    assign fifo_we    = rvalid && rready;
    assign fifo_wdata = {rlast, rdata}; 

    assign m_axis_tvalid = !fifo_empty;
    assign m_axis_tdata  = fifo_rdata[DATA_WIDTH-1:0];
    assign m_axis_tlast  = fifo_rdata[DATA_WIDTH];
    assign fifo_re       = m_axis_tvalid && m_axis_tready;
    
    assign m_axis_tstrb  = {KEEP_WIDTH{1'b1}};
    assign m_axis_tkeep  = {KEEP_WIDTH{1'b1}};

    sync_fifo #(
        .WIDTH(FIFO_WIDTH), 
        .DEPTH_L2(FIFO_DEPTH_LOG2)
    ) u_fifo_mm2s (
        .clk(clk), .rst_n(rst_n),
        .wr_en(fifo_we), .wr_data(fifo_wdata), .full(fifo_full),
        .rd_en(fifo_re), .rd_data(fifo_rdata), .empty(fifo_empty)
    );
endmodule
