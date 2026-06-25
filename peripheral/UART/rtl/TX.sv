import UART_pkg::*;

module TX 
(
    input  logic                  BCLK,
    input  logic                  reset_n,
    input  logic                  tx_start,
    input  logic [DATA_WIDTH-1:0] tx_din,
    output logic                  tx_done_tk,
    output logic                  tx
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t current_state, next_state;

    logic [DATA_WIDTH-1:0] shift_reg;
    logic [3:0]            tk_counter;
    logic [DATA_BITS-1:0]  data_bits_counter;

    // FSM Sequential
    always_ff @(posedge BCLK or negedge reset_n) begin
        if (!reset_n) current_state <= IDLE;
        else       current_state <= next_state;
    end

    // Next state logic (Combinational)
    always_comb begin
        next_state = current_state; 

        case (current_state)
            IDLE: begin
                if (tx_start) next_state = START;
            end
            START: begin
                // 16 beats for Start Bit
                if (tk_counter == OVERSAMPLE - 1) next_state = DATA;
            end
            DATA: begin
                // 16 beats AND 8 data bits
                if (tk_counter == OVERSAMPLE - 1 && data_bits_counter == DATA_WIDTH - 1)
                    next_state = STOP;
            end
            STOP: begin
                // 16 beats for Stop Bit
                if (tk_counter == OVERSAMPLE - 1) next_state = IDLE;
            end
        endcase
    end

    // DATAPATH & OUTPUT (Sequential)
    always_ff @(posedge BCLK or negedge reset_n) begin
        if (!reset_n) begin
            tx                <= 1'b1; // Default idle state for UART is HIGH
            tx_done_tk        <= 1'b0;
            tk_counter        <= '0;
            data_bits_counter <= '0;
            shift_reg         <= '0;
        end else begin

            tx_done_tk <= 1'b0;

            case (current_state)
                IDLE: begin
                    tx                <= 1'b1; 
                    tk_counter        <= '0;
                    data_bits_counter <= '0;

                    if (tx_start) begin
                        shift_reg <= tx_din;
                        tx_done_tk <= 1'b1;
                    end
                end

                START: begin
                    tx <= 1'b0; // Start Bit: LOW

                    if (tk_counter == OVERSAMPLE - 1) begin
                        tk_counter <= '0; // Reset counter for DATA
                    end else begin
                        tk_counter <= tk_counter + 1'b1;
                    end
                end

                DATA: begin
                    tx <= shift_reg[0]; // Output LSB 
                    
                    if (tk_counter == OVERSAMPLE - 1) begin
                        tk_counter        <= '0;
                        data_bits_counter <= data_bits_counter + 1'b1;

                        shift_reg <= {1'b0, shift_reg[DATA_WIDTH-1:1]};
                    end else begin
                        tk_counter <= tk_counter + 1'b1;
                    end
                end

                STOP: begin
                    tx <= 1'b1; // Stop Bit: HIGH
                    
                    if (tk_counter == OVERSAMPLE - 1) begin
                        tk_counter <= '0;
                        // tx_done_tk <= 1'b1; // Done 1 frame
                    end else begin
                        tk_counter <= tk_counter + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
