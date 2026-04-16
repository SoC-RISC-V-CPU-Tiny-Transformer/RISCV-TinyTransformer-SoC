`timescale 1ns / 1ps

module MatMul #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter ARRAY_SIZE = 8,
    parameter MAT_SIZE = 64,
    parameter ADDR_WIDTH = 9,
    parameter NUM_HEADS = 2
) (
    input logic clk,
    input logic rst_n,

    // --- Điều khiển từ FSM ---
    input logic start,
    input logic transpose_mode,
    input logic [$clog2(ACC_WIDTH)-1:0] shift_amount,
    input logic multi_head,
    input logic [$clog2(NUM_HEADS)-1:0] head_idx,
    input logic is_calc_z,
    output logic done,

    // --- Giao tiếp với SRAM để đọc input ---
    output logic read_req_a,
    output logic [ADDR_WIDTH-1:0] read_addr_a,
    input logic signed [DATA_WIDTH-1:0] read_data_a [ARRAY_SIZE-1:0],

    output logic read_req_b,
    output logic [ADDR_WIDTH-1:0] read_addr_b,
    input logic signed [DATA_WIDTH-1:0] read_data_b [ARRAY_SIZE-1:0],

    // --- Kết quả nối ra datapath ---
    output logic valid_out,
    output logic [$clog2(ARRAY_SIZE)-1:0] out_row_idx,
    output logic signed [DATA_WIDTH-1:0] out_data [ARRAY_SIZE-1:0],
    output logic [$clog2(ARRAY_SIZE)-1:0] out_br,
    output logic [$clog2(ARRAY_SIZE)-1:0] out_bc
);
    localparam NUM_BLOCKS = MAT_SIZE / ARRAY_SIZE;

    logic [$clog2(MAT_SIZE)-1:0] k_start, k_end;
    logic [$clog2(NUM_BLOCKS)-1:0] bc_start, bc_end;
    logic [$clog2(MAT_SIZE)+1:0] total_blocks;

    always_comb begin
        if(multi_head && !is_calc_z) begin
            k_start = head_idx * MAT_SIZE / NUM_HEADS;
            k_end = k_start + MAT_SIZE / NUM_HEADS - 1; 
        end
        else begin
            k_start = 0;
            k_end = MAT_SIZE - 1;
        end

        if(is_calc_z) begin
            bc_start = head_idx * NUM_BLOCKS / NUM_HEADS;
            bc_end = bc_start + NUM_BLOCKS / NUM_HEADS - 1;
        end
        else begin
            bc_start = 0;
            bc_end = NUM_BLOCKS - 1;
        end
    end

    assign total_blocks = NUM_BLOCKS * (bc_end - bc_start + 1);

    // =========================================================
    // FSM READ INPUT FROM SRAM
    // =========================================================
    typedef enum logic [1:0] {IDLE, FEED, FLUSH, WAIT_DONE} state_t;
    state_t state, next_state;

    logic [$clog2(MAT_SIZE)-1:0] k_idx;
    logic [$clog2(MAT_SIZE):0] blocks_fed;
    logic [$clog2(ARRAY_SIZE)-1:0] br, bc;
    logic valid_req, clear_req;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            state <= IDLE;
            k_idx <= 0; blocks_fed <= 0;
            br <= 0; bc <= 0;
        end
        else begin
            state <= next_state;

            case(state) 
                IDLE: begin
                    k_idx <= k_start; blocks_fed <= 0;
                    br <= 0; bc <= bc_start;
                end
                FEED: k_idx <= k_idx + 1;

                FLUSH: begin
                    k_idx <= k_start;
                    blocks_fed <= blocks_fed + 1;
                    if(transpose_mode) begin
                        if(br == NUM_BLOCKS - 1) begin
                            br <= 0;
                            bc <= bc + 1;
                        end
                        else 
                            br <= br + 1;
                    end
                    else begin
                        if(bc == bc_end) begin
                            br <= br + 1;
                            bc <= bc_start;
                        end
                        else
                            bc <= bc + 1;
                    end
                end
            endcase
        end
    end

    always_comb begin
        next_state = state;
        read_req_a = 0; read_req_b = 0;
        read_addr_a = 0; read_addr_b = 0;
        valid_req = 0; clear_req = 0;
        case(state)
            IDLE: if(start) next_state = FEED;

            FEED: begin
                read_req_a = 1; read_req_b = 1; valid_req = 1;
                read_addr_a = k_idx * ARRAY_SIZE + br;
                read_addr_b = k_idx * ARRAY_SIZE + bc;
                
                if(k_idx == k_end) next_state = FLUSH; 
            end

            FLUSH: begin
                clear_req = 1;
                if(blocks_fed == total_blocks - 1)
                    next_state = WAIT_DONE;
                else
                    next_state = FEED;
            end

            WAIT_DONE: if(done) next_state = IDLE;
        endcase
    end

    // =========================================================
    // SYSTOLIC ARRAY
    // =========================================================
    logic valid_in, acc_clear;
    logic signed [DATA_WIDTH-1:0] out_row_aligned [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic valid_row_aligned [ARRAY_SIZE-1:0];

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            valid_in <= 0;
            acc_clear <= 0;
        end
        else begin
            valid_in <= valid_req;
            acc_clear <= clear_req;
        end
    end

    SystolicArray #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) SA_core (
        .clk(clk), .rst_n(rst_n),
        .vec_in_a(read_data_a), .vec_in_b(read_data_b),
        .valid_in(valid_in), .acc_clear(acc_clear),
        .shift_amount(shift_amount),
        .out_row_aligned(out_row_aligned), .valid_row_aligned(valid_row_aligned)
    );

    // =========================================================
    //  OUTPUT PROCESSING
    // =========================================================
    always_ff @(posedge clk) begin
        if(!rst_n || state == IDLE) begin
            out_br <= 0; out_bc <= bc_start;
        end
        else begin
            if(valid_row_aligned[ARRAY_SIZE-1]) begin
                if (transpose_mode) begin
                    if(out_br == NUM_BLOCKS - 1) begin
                        out_bc <= out_bc + 1;
                        out_br <= 0;
                    end
                    else 
                        out_br <= out_br + 1;
                end
                else begin
                    if(out_bc == bc_end) begin
                        out_bc <= bc_start;
                        out_br <= out_br + 1;
                    end 
                    else out_bc <= out_bc + 1;
                end
            end
        end
    end

    always_comb begin
        valid_out = 0;
        out_row_idx = 0;
        out_data = '{default: '0};
        for(int i = 0; i < ARRAY_SIZE; i++) begin
            if(valid_row_aligned[i]) begin
                valid_out = 1;
                out_row_idx = i[2:0];
                out_data = out_row_aligned[i];
            end
        end
    end

    // =========================================================
    // DONE SIGNAL
    // =========================================================
    logic [ADDR_WIDTH:0] out_counter;

    always_ff @(posedge clk) begin
        if (state == IDLE) begin
            out_counter <= 0;
        end else if (valid_out) begin
            out_counter <= out_counter + 1;
        end
    end

    assign done = valid_out && (out_counter == (total_blocks * ARRAY_SIZE - 1));

endmodule