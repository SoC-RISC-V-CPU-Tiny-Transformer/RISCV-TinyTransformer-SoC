import UART_pkg::*;

module async_fifo #(
    parameter int ADDR_WIDTH = 4  
)(
    // Write Domain
    input  logic                  wclk,
    input  logic                  wreset_n, 
    input  logic                  winc,   // Write Enable
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic                  wfull,

    // Read Domain
    input  logic                  rclk,
    input  logic                  rreset_n, 
    input  logic                  rinc,   // Read Enable
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  rempty
);
    localparam int FIFO_DEPTH = 1 << ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    initial begin
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            mem[i] = '0;
        end
    end

    logic [ADDR_WIDTH:0] wptr_bin, wptr_gray, wptr_gray_next;
    logic [ADDR_WIDTH:0] rptr_bin, rptr_gray, rptr_gray_next;

    // Synchronizers
    logic [ADDR_WIDTH:0] wq1_rptr, wq2_rptr; // synchronize rptr to wclk
    logic [ADDR_WIDTH:0] rq1_wptr, rq2_wptr; // synchronize wptr to rclk

    // temp signals for empty/full logic
    logic rempty_val, wfull_val;

    // DUAL-PORT RAM
    always_ff @(posedge wclk) begin
        if (winc && !wfull) begin
            mem[wptr_bin[ADDR_WIDTH-1:0]] <= wdata;
        end
    end

    assign rdata = mem[rptr_bin[ADDR_WIDTH-1:0]];
    
    // Move Gray write pointer to Read Clock domain
    always_ff @(posedge rclk or negedge rreset_n) begin
        if (!rreset_n) begin
            {rq2_wptr, rq1_wptr} <= '0;
        end else begin
            {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr_gray};
        end
    end

    // Move Gray read pointer to Write Clock domain
    always_ff @(posedge wclk or negedge wreset_n) begin
        if (!wreset_n) begin
            {wq2_rptr, wq1_rptr} <= '0;
        end else begin
            {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr_gray};
        end
    end

    // READ PTR & EMPTY LOGIC
    // Next pointer (Binary -> Gray)
    logic [ADDR_WIDTH:0] rptr_bin_next;
    assign rptr_bin_next  = rptr_bin + (rinc & ~rempty);
    assign rptr_gray_next = (rptr_bin_next >> 1) ^ rptr_bin_next;

    always_ff @(posedge rclk or negedge rreset_n) begin
        if (!rreset_n) begin
            rptr_bin  <= '0;
            rptr_gray <= '0;
        end else begin
            rptr_bin  <= rptr_bin_next;
            rptr_gray <= rptr_gray_next;
        end
    end

    assign rempty_val = (rptr_gray_next == rq2_wptr);

    always_ff @(posedge rclk or negedge rreset_n) begin
        if (!rreset_n) rempty <= 1'b1; 
        else        rempty <= rempty_val;
    end

    // WRITE PTR & FULL LOGIC
    // Next pointer (Binary -> Gray)
    logic [ADDR_WIDTH:0] wptr_bin_next;
    assign wptr_bin_next  = wptr_bin + (winc & ~wfull);
    assign wptr_gray_next = (wptr_bin_next >> 1) ^ wptr_bin_next;

    always_ff @(posedge wclk or negedge wreset_n) begin
        if (!wreset_n) begin
            wptr_bin  <= '0;
            wptr_gray <= '0;
        end else begin
            wptr_bin  <= wptr_bin_next;
            wptr_gray <= wptr_gray_next;
        end
    end

    assign wfull_val = (wptr_gray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], 
                                            wq2_rptr[ADDR_WIDTH-2:0]});

    always_ff @(posedge wclk or negedge wreset_n) begin
        if (!wreset_n) wfull <= 1'b0;
        else        wfull <= wfull_val;
    end

endmodule
