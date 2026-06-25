module RX import UART_pkg::*;
(
    input  logic                  BCLK,
    input  logic                  reset_n,
    input  logic                  rx,
    input  logic                  rx_write, 
    output logic [DATA_WIDTH-1:0] rx_dout,
    output logic                  rx_done_tk
);

    localparam int DATA_BITS = $clog2(DATA_WIDTH);

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

    // FSM (Sequential)
    always_ff @(posedge BCLK or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic (Combinational)
    always_comb begin
        next_state = current_state; 

        case (current_state)
            IDLE: begin
                if (rx == 1'b0) next_state = START;
            end
            START: begin
                // Count enough clock cycles to sample at the middle of the Start bit (16/2 - 1 = 7)
                if (tk_counter == (OVERSAMPLE/2) - 1) next_state = DATA;
            end
            DATA: begin
                // Count enough clock cycles AND enough data bits
                if (tk_counter == OVERSAMPLE - 1 && data_bits_counter == DATA_WIDTH - 1)
                    next_state = STOP;
            end
            STOP: begin
                // Count enough clock cycles for Stop bit
                if (tk_counter == OVERSAMPLE - 1) next_state = IDLE;
            end
        endcase
    end

    // DATAPATH (Sequential)
    always_ff @(posedge BCLK or negedge reset_n) begin
        if (!reset_n) begin
            tk_counter        <= '0;
            data_bits_counter <= '0;
            shift_reg         <= '0;
            rx_done_tk        <= 1'b0;
            rx_dout           <= '0;
        end else begin
            // Default values for outputs and counters
            rx_done_tk <= 1'b0; 

            case (current_state) 
                IDLE: begin
                    tk_counter        <= '0;
                    data_bits_counter <= '0;
                end

                START: begin
                    if (tk_counter == (OVERSAMPLE/2) - 1) begin
                        tk_counter <= '0; 
                    end else begin
                        tk_counter <= tk_counter + 1'b1;
                    end
                end

                DATA: begin
                    if (tk_counter == OVERSAMPLE - 1) begin
                        tk_counter        <= '0;
                        data_bits_counter <= data_bits_counter + 1'b1;
                        
                        // UART send LSB first, so the new bit (rx) is inserted into the MSB, and the old bits are shifted right
                        shift_reg <= {rx, shift_reg[DATA_WIDTH-1:1]};
                    end else begin
                        tk_counter <= tk_counter + 1'b1;
                    end
                end

                STOP: begin
                    if (tk_counter == OVERSAMPLE - 1) begin
                        tk_counter <= '0;
                        rx_done_tk <= 1'b1; // Done
                        
                        // Update data output 
                        if (rx_write) rx_dout <= '0;
                        else          rx_dout <= shift_reg;
                    end else begin
                        tk_counter <= tk_counter + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
