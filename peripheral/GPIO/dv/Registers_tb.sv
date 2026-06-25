import GPIO_pkg::*;

`timescale 1ns/1ps

module Registers_tb();

    logic                  sys_clk;
    logic                  sys_rst;
    logic                  gpio_we;
    logic [ADDR_WIDTH-1:0] gpio_addr;
    logic [DATA_WIDTH-1:0] gpio_dat_i;
    logic [DATA_WIDTH-1:0] gpio_dat_o;
    logic                  gpio_inta_o;
    
    logic [DATA_WIDTH-1:0] in_pad_i;
    logic [DATA_WIDTH-1:0] aux_i;
    logic [DATA_WIDTH-1:0] out_pad_o;
    logic [DATA_WIDTH-1:0] oen_padoe_o;
    logic                  gpio_eclk;
        
    logic [DATA_WIDTH-1:0] temp_data;    
  
    Registers #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .sys_clk(sys_clk),
        .sys_rst(sys_rst),
        .gpio_we(gpio_we),
        .gpio_addr(gpio_addr),
        .gpio_dat_i(gpio_dat_i),
        .gpio_dat_o(gpio_dat_o),
        .gpio_inta_o(gpio_inta_o),
        .in_pad_i(in_pad_i),
        .aux_i(aux_i),
        .out_pad_o(out_pad_o),
        .oen_padoe_o(oen_padoe_o),
        .gpio_eclk(gpio_eclk)
    );

    // Clock Generation (100MHz)
    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk; 
    end

    // VERIFICATION TASKS 
    
    task reset_system();
        sys_rst = 0;
        gpio_we = 0;
        gpio_addr = 0;
        gpio_dat_i = 0;
        in_pad_i = 0;
        @(posedge sys_clk);
        sys_rst = 1;
        @(posedge sys_clk);
    endtask

    task write_reg(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        @(posedge sys_clk);
        gpio_we = 1;
        gpio_addr = addr;
        gpio_dat_i = data;
        @(posedge sys_clk);
        gpio_we = 0;
    endtask

    task read_and_check(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] expected, input string test_name);
        @(posedge sys_clk);
        gpio_we = 0;
        gpio_addr = addr;
        #1; // Wait for combinational logic to settle
        if (gpio_dat_o !== expected) 
            $error("[FAIL] %s. Expected: %h, Got: %h", test_name, expected, gpio_dat_o);
        else 
            $display("[PASS] %s", test_name);
    endtask

    // START TEST -
    
    initial begin
        $display("=== STARTING GPIO REGISTERS VERIFICATION ===");
        
        // PHASE 1: RESET & DEFAULT STATES 
        reset_system();
        read_and_check(4'h0, 32'h0, "Test 1: Reset state of DATA_OUT");
        read_and_check(4'h4, 32'h0, "Test 2: Reset state of DIR");
        read_and_check(4'hC, 32'h0, "Test 3: Reset state of INT_STATUS");
        if (out_pad_o !== 0) $error("[FAIL] Test 4: out_pad_o not reset");
        // Test 5: Hardware Enable Pad Reset (High-Z mode)
        if (oen_padoe_o !== 0) $error("[FAIL] Test 5: oen_padoe_o not reset");

        // PHASE 2: BASIC READ/WRITE (HAPPY PATH) 
        // Test 6: Write all 1s to DATA_OUT
        write_reg(4'h0, 32'hFFFF_FFFF);
        read_and_check(4'h0, 32'hFFFF_FFFF, "Test 6: Write/Read DATA_OUT All 1s");
        
        // Test 7: Write alternating bits to DATA_OUT
        write_reg(4'h0, 32'hAAAA_5555);
        read_and_check(4'h0, 32'hAAAA_5555, "Test 7: Write/Read DATA_OUT Alternating");
        
        // Test 8: Write all 1s to DIR (All Output)
        write_reg(4'h4, 32'hFFFF_FFFF);
        read_and_check(4'h4, 32'hFFFF_FFFF, "Test 8: Write/Read DIR All 1s");
        
        // Test 9: Verify internal flip-flops connected to physical pads
        #1; if (out_pad_o !== 32'hAAAA_5555 || oen_padoe_o !== 32'hFFFF_FFFF) 
            $error("[FAIL] Test 9: Physical pad outputs do not match registers");

        // PHASE 3: READ-ONLY PROTECTION & SYNCHRONIZER TIMING 
        // Test 10: Try to overwrite DATA_IN (Should be ignored by hardware)
        write_reg(4'h8, 32'hFFFF_FFFF); // 0x8 is DATA_IN
        read_and_check(4'h8, 32'h0, "Test 10: Read-Only protection on DATA_IN");

        // Test 11: Apply external signal to Pad
        in_pad_i = 32'h0000_000F;
        // Test 12: Read immediately (Should be 0 due to sync delay)
        read_and_check(4'h8, 32'h0, "Test 12: Sync Delay - Cycle 1");
        // Test 14: Read after 2 clocks (Should now be updated)
        read_and_check(4'h8, 32'h0000_000F, "Test 14: Sync Delay - Cycle 2 (Data Valid)");

        // Test 15: Glitch filter corner case (Pulse shorter than clock period)
        @(negedge sys_clk);
        in_pad_i = 32'hFFFF_FFFF;
        #2 in_pad_i = 32'h0000_000F; // Glitch disappears before posedge
        @(posedge sys_clk);
        @(posedge sys_clk);
        read_and_check(4'h8, 32'h0000_000F, "Test 15: Glitch rejection on async inputs");

        // PHASE 4: INTERRUPT GENERATION & W1C CORNER CASES 
        reset_system();
        
        // Test 16: Rising edge on Pin 0
        in_pad_i[0] = 1;
        repeat(3) @(posedge sys_clk); // Wait for sync
        read_and_check(4'hC, 32'h1, "Test 16: Interrupt generation on Pin 0");
        
        // Test 17: Check global interrupt signal
        if (!gpio_inta_o) $error("[FAIL] Test 17: gpio_inta_o is not high");

        // Test 18: Rising edge on Pin 31
        in_pad_i[31] = 1;
        repeat(3) @(posedge sys_clk);
        read_and_check(4'hC, 32'h8000_0001, "Test 18: Multiple interrupts (Pin 0 and 31)");

        // Test 19: Write 0 to clear (Should NOT clear anything)
        write_reg(4'hC, 32'h0);
        read_and_check(4'hC, 32'h8000_0001, "Test 19: W1C protection against writing 0");

        // Test 20: Write 1 to Clear Pin 0 only
        write_reg(4'hC, 32'h1);
        read_and_check(4'hC, 32'h8000_0000, "Test 20: W1C partial clear (Pin 0 cleared, 31 remains)");

        // Test 21: Verify global interrupt remains high
        if (!gpio_inta_o) $error("[FAIL] Test 21: gpio_inta_o dropped prematurely");

        // PHASE 5: HARDWARE VS SOFTWARE COLLISION (STRESS TEST) 
        // Test 22: CPU clears Pin 31 EXACTLY when hardware sets Pin 5
        in_pad_i[5] = 1; // Trigger hardware event
        @(posedge sys_clk);
        @(posedge sys_clk); // Sync1 -> Sync2 transition happens now
        // At this exact posedge, Software writes 1 to clear bit 31
        gpio_we = 1;
        gpio_addr = 4'hC;
        gpio_dat_i = 32'h8000_0000; 
        @(posedge sys_clk);
        gpio_we = 0;
        
        // Hardware should prioritize keeping the new interrupt on Pin 5 while clearing 31
        read_and_check(4'hC, 32'h0000_0020, "Test 22: Hardware/Software Collision Handling");

        // PHASE 6: BUS PROTOCOL & ADDRESS CORNER CASES 
        // Test 23: Back-to-back writes (No idle cycle)
        @(posedge sys_clk);
        gpio_we = 1; gpio_addr = 4'h0; gpio_dat_i = 32'h1111_1111;
        @(posedge sys_clk);
        gpio_we = 1; gpio_addr = 4'h4; gpio_dat_i = 32'h2222_2222;
        @(posedge sys_clk);
        gpio_we = 0;
        read_and_check(4'h0, 32'h1111_1111, "Test 23a: Back-to-back write DATA_OUT");
        read_and_check(4'h4, 32'h2222_2222, "Test 23b: Back-to-back write DIR");

        // Test 24: Unaligned/Invalid Addresses inside the 4-byte block (using bits [3:2])
        // In APB, if addr is 0x1, 0x2, 0x3, it should map to 0x0 because we slice [3:2]
        write_reg(4'h2, 32'hBEEF_BEEF);
        read_and_check(4'h0, 32'hBEEF_BEEF, "Test 24: Address alignment slice [3:2] mapping");

        // Test 25: Write enable dropping exactly at clock edge (Setup/Hold emulation)
        @(negedge sys_clk);
        gpio_we = 1; gpio_addr = 4'h0; gpio_dat_i = 32'hDEAD_BEEF;
        #4 gpio_we = 0; // Drops right before posedge
        @(posedge sys_clk);
        read_and_check(4'h0, 32'hBEEF_BEEF, "Test 25: Write enable setup time violation test");

        // PHASE 7: ASYNCHRONOUS RESET CORNER CASES 
        in_pad_i = 32'h0;
        // Test 26: Reset during active write
        @(posedge sys_clk);
        gpio_we = 1; gpio_addr = 4'h0; gpio_dat_i = 32'h1234_5678;
        sys_rst = 0; // Async reset pulled down
        @(posedge sys_clk);
        sys_rst = 1;
        gpio_we = 0;
        read_and_check(4'h0, 32'h0, "Test 26: Async reset priority over Write enable");

        // Test 27: Reset during active hardware interrupt event
        in_pad_i[15] = 1;
        @(posedge sys_clk); // sync 1
        sys_rst = 0; // Pull down reset midway
        in_pad_i = 32'h0;
        
        @(posedge sys_clk);
        sys_rst = 1;
        read_and_check(4'hC, 32'h0, "Test 27: Reset mid-synchronization clears pipeline");
        
        // PHASE 8: EXTREME CONTINUOUS TOGGLING 
        // Test 28: Toggle ALL writable registers continuously
        for(int i=0; i<3; i++) begin
            write_reg(4'h0, $urandom());
            write_reg(4'h4, $urandom());
        end
        read_and_check(4'hC, 32'h0, "Test 28: High-speed toggle did not corrupt INT_STATUS");

        // Test 29: Read combinational path stability under changing inputs
        gpio_we = 0;
        gpio_addr = 4'h0; // Read DATA_OUT
        #1;
        temp_data = gpio_dat_o; // Snapshot
        in_pad_i = 32'hFFFF_FFFF; // Change async inputs aggressively
        #1;
        if (gpio_dat_o !== temp_data) $error("[FAIL] Test 29: Read path isolation failed");
        
        // Test 30: Final sanity check on Pad Outputs after random toggles
        if (out_pad_o !== dut.reg_data_out || oen_padoe_o !== dut.reg_dir)
             $error("[FAIL] Test 30: Pad continuous assignments broken");
        else 
             $display("[PASS] Test 30: Pad assignments intact");

        $display("=== VERIFICATION COMPLETE ===");
        $finish;
    end

endmodule
