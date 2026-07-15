`timescale 1ns/1ps

import I2C_pkg::*; 

module I2C_Core 
(
    input  logic        clk,            // System clock (100MHz)
    input  logic        rst_n,          
    
    // CSR
    input  logic [7:0]  i_addr_w_rw,    
    input  logic [15:0] i_sub_addr,     
    input  logic        i_sub_len,      
    input  logic [23:0] i_byte_len,     
    input  logic [7:0]  i_data_write,   
    input  logic        req_trans,      
    
    output logic [7:0]  data_out,
    output logic        valid_out,
    output logic        req_data_chunk, 
    output logic        busy,           
    output logic        nack,           
    
    // I2C Physical Lines
    inout  wire         scl_o,          
    inout  wire         sda_o           
);

    typedef enum logic [3:0] {
        IDLE        = 4'd0,
        START       = 4'd1,
        RESTART     = 4'd2,
        SLAVE_ADDR  = 4'd3,
        SUB_ADDR    = 4'd4,
        READ        = 4'd5,
        WRITE       = 4'd6,
        GRAB_DATA   = 4'd7,
        ACK_NACK_RX = 4'd8,
        ACK_NACK_TX = 4'd9,
        STOP        = 4'hA,
        RELEASE_BUS = 4'hB
    } state_t;

    state_t state, next_state;

    // Các tín hiệu nội bộ
    logic        reg_sda_o;
    logic [7:0]  addr;
    logic        rw;
    logic [15:0] sub_addr;
    logic        sub_len;
    logic [23:0] byte_len;
    logic        en_scl;
    logic        byte_sent;
    logic [23:0] num_byte_sent;
    logic [2:0]  cntr;
    logic [7:0]  byte_sr;
    logic        read_sub_addr_sent_flag;
    logic [7:0]  data_to_write;
    logic [7:0]  data_in_sr;

    // Clock generation
    logic        clk_i2c;
    logic [15:0] clk_i2c_cntr;

    // Sampling
    logic [1:0]  sda_curr;    
    logic        sda_prev;
    logic        scl_prev, scl_curr;          

    logic        ack_in_prog;      
    logic        ack_nack;
    logic        en_end_indicator;
    logic        grab_next_data;
    logic        scl_is_high;
    logic        scl_is_low;

    // 400KHz Clock Generation
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            clk_i2c_cntr <= 16'b0;
            clk_i2c      <= 1'b1;
        end else if(!en_scl) begin
            clk_i2c_cntr <= 16'b0;
            clk_i2c      <= 1'b1;
        end else begin
            clk_i2c_cntr <= clk_i2c_cntr + 1'b1;
            if(clk_i2c_cntr == DIV_100MHZ-1) begin
                clk_i2c <= !clk_i2c;
                clk_i2c_cntr <= 16'b0;
            end
        end
    end

    // Main FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_out <= 8'h0;
            valid_out <= 1'b0;
            req_data_chunk <= 1'b0;
            busy <= 1'b0;
            nack <= 1'b0;
            addr <= 8'h0;
            rw <= 1'b0;
            sub_addr <= 16'h0;
            sub_len <= 1'b0;
            byte_len <= 24'h0;
            en_scl <= 1'b0;
            byte_sent <= 1'b0;
            num_byte_sent <= 24'h0;
            cntr <= 3'h0;
            byte_sr <= 8'h0;
            read_sub_addr_sent_flag <= 1'b0;
            data_to_write <= 8'h0;
            data_in_sr <= 8'h0;
            ack_nack <= 1'b0;
            ack_in_prog <= 1'b0;
            en_end_indicator <= 1'b0;
            scl_is_high <= 1'b0;
            scl_is_low <= 1'b0;
            grab_next_data <= 1'b0;
            reg_sda_o <= 1'b1;
            state <= IDLE;
            next_state <= IDLE;
        end else begin
            valid_out <= 1'b0;
            req_data_chunk <= 1'b0;
            case(state)
                IDLE: begin
                    if(req_trans & !busy) begin
                        busy <= 1'b1;
                        state <= START;
                        next_state <= SLAVE_ADDR;
                        addr <= i_addr_w_rw;
                        rw <= i_addr_w_rw[0];
                        sub_addr <= i_sub_len ? i_sub_addr : {i_sub_addr[7:0], 8'b0};
                        sub_len <= i_sub_len;
                        data_to_write <= i_data_write;
                        byte_len <= i_byte_len;
                        en_scl <= 1'b1;
                        reg_sda_o <= 1'b1;
                        nack <= 1'b0;  
                        read_sub_addr_sent_flag <= 1'b0;
                        num_byte_sent <= 24'h0;
                        byte_sent <= 1'b0;
                    end
                end
                
                START: begin
                    if(scl_prev & scl_curr & clk_i2c_cntr == START_IND_SETUP) begin
                        reg_sda_o <= 1'b0;
                        byte_sr <= {addr[7:1], 1'b0};
                        state <= SLAVE_ADDR;
                    end
                end
                
                RESTART: begin
                    if(!scl_curr & scl_prev) reg_sda_o <= 1'b1;
                    if(!scl_prev & scl_curr) scl_is_high <= 1'b1;
                    if(scl_is_high) begin
                        if(clk_i2c_cntr == START_IND_SETUP) begin
                            scl_is_high <= 1'b0;
                            reg_sda_o <= 1'b0;
                            state <= SLAVE_ADDR;
                            byte_sr <= addr;
                        end
                    end
                end
                
                SLAVE_ADDR: begin
                    if(byte_sent & cntr[0]) begin
                        byte_sent <= 1'b0;
                        next_state <= read_sub_addr_sent_flag ? READ : SUB_ADDR;
                        byte_sr <= sub_addr[15:8];
                        state <= ACK_NACK_RX;
                        reg_sda_o <= 1'bz;
                        cntr <= 3'h0;
                    end else begin
                        if(!scl_curr & scl_prev) scl_is_low <= 1'b1;
                        if(scl_is_low) begin
                            if(clk_i2c_cntr == DATA_HOLD_TIME) begin
                                {byte_sent, cntr} <= {byte_sent, cntr} + 1'b1;
                                reg_sda_o <= byte_sr[7];
                                byte_sr <= {byte_sr[6:0], 1'b0};
                                scl_is_low <= 1'b0;
                            end
                        end
                    end
                end
                
                SUB_ADDR: begin
                    if(byte_sent & cntr[0]) begin
                        if(sub_len) begin
                            state <= ACK_NACK_RX;
                            next_state <= SUB_ADDR;
                            sub_len <= 1'b0;
                            byte_sr <= sub_addr[7:0];
                        end else begin
                            next_state <= rw ? RESTART : WRITE;
                            byte_sr <= rw ? byte_sr : data_to_write;
                            read_sub_addr_sent_flag <= 1'b1;
                        end
                        cntr <= 3'h0;
                        byte_sent <= 1'b0;
                        state <= ACK_NACK_RX;
                        reg_sda_o <= 1'bz;
                    end else begin
                        if(!scl_curr & scl_prev) scl_is_low <= 1'b1;
                        if(scl_is_low) begin
                            if(clk_i2c_cntr == DATA_HOLD_TIME) begin
                                scl_is_low <= 1'b0;
                                {byte_sent, cntr} <= {byte_sent, cntr} + 1'b1;
                                reg_sda_o <=  byte_sr[7];
                                byte_sr <= {byte_sr[6:0], 1'b0};
                            end
                        end
                    end
                end
                
                READ: begin
                    if(byte_sent) begin
                        byte_sent <= 1'b0;
                        data_out  <= data_in_sr;
                        valid_out <= 1'b1;
                        state <= ACK_NACK_TX;
                        next_state <= (num_byte_sent == byte_len-1) ? STOP : READ;
                        ack_nack <= (num_byte_sent == byte_len-1);
                        num_byte_sent <= num_byte_sent + 1'b1;
                        ack_in_prog <= 1'b1;
                    end else begin
                        if(!scl_prev & scl_curr) scl_is_high <= 1'b1;
                        if(scl_is_high) begin
                            if(clk_i2c_cntr == START_IND_SETUP) begin
                                valid_out <= 1'b0;
                                {byte_sent, cntr} <= cntr + 1'b1;
                                data_in_sr <= {data_in_sr[6:0], sda_prev};
                                scl_is_high <= 1'b0;
                            end
                        end
                    end
                end
                
                WRITE: begin
                    if(byte_sent & cntr[0]) begin
                        cntr <= 3'h0;
                        byte_sent <= 1'b0;
                        state <= ACK_NACK_RX;
                        reg_sda_o <= 1'bz;
                        next_state <= (num_byte_sent == byte_len-1) ? STOP : GRAB_DATA;
                        num_byte_sent <= num_byte_sent + 1'b1;
                        grab_next_data <= 1'b1;
                    end else begin
                        if(!scl_curr & scl_prev) scl_is_low <= 1'b1;
                        if(scl_is_low) begin
                            if(clk_i2c_cntr == DATA_HOLD_TIME) begin
                                {byte_sent, cntr} <= {byte_sent, cntr} + 1'b1;
                                reg_sda_o <= byte_sr[7];
                                byte_sr <= {byte_sr[6:0], 1'b0};
                                scl_is_low <= 1'b0;
                            end
                        end
                    end
                end
                
                GRAB_DATA: begin
                    if(grab_next_data) begin
                        req_data_chunk <= 1'b1;
                        grab_next_data <= 1'b0;
                    end else begin
                        state <= WRITE;
                        byte_sr <= i_data_write;
                    end
                end
                
                ACK_NACK_RX: begin
                    if(!scl_prev & scl_curr) scl_is_high <= 1'b1;
                    if(scl_is_high) begin
                        if(clk_i2c_cntr == START_IND_SETUP) begin
                            if(!sda_prev) begin 
                                state <= next_state;
                            end else begin 
                                nack <= 1'b1;
                                busy <= 1'b0;
                                reg_sda_o <= 1'bz;
                                en_scl <= 1'b0;
                                state <= IDLE;
                            end  
                            scl_is_high <= 1'b0;
                        end
                    end
                end
                
                ACK_NACK_TX: begin
                    if(!scl_curr & scl_prev) scl_is_low <= 1'b1;
                    if(scl_is_low) begin
                        if(clk_i2c_cntr == DATA_HOLD_TIME) begin
                            if(ack_in_prog) begin 
                                reg_sda_o <= ack_nack;
                                ack_in_prog <= 1'b0;
                            end else begin
                                reg_sda_o <= (next_state == STOP) ? 1'b0 : 1'bz;
                                en_end_indicator <= (next_state == STOP) ? 1'b1 : en_end_indicator;
                                state <= next_state;
                            end
                            scl_is_low <= 1'b0;
                        end
                    end
                end
                
                STOP: begin 
                    if(!scl_curr & scl_prev & !rw) begin
                        reg_sda_o <= 1'b0;
                        en_end_indicator <= 1'b1;
                    end
                    if(scl_curr & scl_prev & en_end_indicator) begin
                        scl_is_high <= 1'b1;
                        en_end_indicator <= 1'b0;
                    end
                    if(scl_is_high) begin
                        if(clk_i2c_cntr == STOP_IND_SETUP) begin
                            reg_sda_o <= 1'b1;
                            state <= RELEASE_BUS;
                            scl_is_high <= 1'b0;
                        end
                    end
                end
                
                RELEASE_BUS: begin
                    if(clk_i2c_cntr == DIV_100MHZ-3) begin
                        en_scl <= 1'b0;
                        state <= IDLE;
                        reg_sda_o <= 1'bz;
                        busy <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Input Sampling
    always_ff @(negedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sda_curr <= 2'b00;
            sda_prev <= 1'b0;
            scl_curr <= 1'b0;
            scl_prev <= 1'b0;
        end else begin
            sda_curr <= {sda_curr[0], sda_o};
            sda_prev <= sda_curr[1];
            scl_curr <= clk_i2c;
            scl_prev <= scl_curr;
        end
    end

    // Pin Assignments
    assign sda_o = reg_sda_o;
    assign scl_o = en_scl ? clk_i2c : 1'bz;
    
endmodule
