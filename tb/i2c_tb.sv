//==============================================================================
// Module Name : i2c_tb
// Author      : vallala saikumar
// Project     : I2C Protocol Implementation in Verilog
//
// Description :
// -----------------------------------------------------------------------------
// Testbench for verifying communication between the I2C Master and I2C Slave.
//
// Test Cases:
//
// Test Case 1:
// - Master writes one byte to slave.
// - Slave stores received data.
// - Testbench checks received value.
//
// Test Case 2:
// - Slave loads transmit data.
// - Master performs read transaction.
// - Testbench compares received byte.
//
// Verification Features:
// - Generates system clock.
// - Generates reset.
// - Drives transaction requests.
// - Displays transaction status.
// - Checks received data.
// - Ends simulation automatically.
//
// Notes:
// - Uses behavioral verification.
// - Results can be observed using both console messages and waveform.
// - Intended for educational and learning purposes.
//
//==============================================================================

`include "i2c_rtl_top.sv"
`timescale 1ns / 1ps

module i2c_tb;

    reg clk;
    reg rst;
    reg start;
    reg rw;
    reg [6:0] slave_addr;
    reg [7:0] master_write_data;
    reg [7:0] slave_tx_data;

    wire [7:0] master_read_data;
    wire [7:0] slave_rx_data;
    wire master_ready;
    wire master_ack_err;
    wire slave_rx_valid;

    i2c_top_system uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .rw(rw),
        .slave_addr(slave_addr),
        .master_write_data(master_write_data),
        .master_read_data(master_read_data),
        .slave_tx_data(slave_tx_data),
        .slave_rx_data(slave_rx_data),
        .master_ready(master_ready),
        .master_ack_err(master_ack_err),
        .slave_rx_valid(slave_rx_valid)
    );

    always #10 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        rw = 0;
        slave_addr = 7'h00;
        master_write_data = 8'h00;
        slave_tx_data = 8'h00;

        #200;
        rst = 0;
        #1000; 

        // ==========================================
        // TEST CASE 1: MASTER WRITE TO SLAVE
        // ==========================================
        $display("[TB INFO] @ %0t ns: Starting Test Case 1 (Master Write)...", $time);
        
        @(posedge clk);
        slave_addr        = 7'h50;  
        master_write_data = 8'hA5;  
        rw                = 1'b0;   
        start             = 1'b1;   
        
        @(posedge clk);
        start = 1'b0;               

        // Wait dynamically for Slave validation flag
        wait(slave_rx_valid == 1'b1);
        #100; 
        if (slave_rx_data == 8'hA5) begin
            $display("[SUCCESS] Test Case 1 Passed! Slave successfully received 8'h%h", slave_rx_data);
        end else begin
            $display("[FAILURE] Test Case 1 Failed! Received: 8'h%h", slave_rx_data);
        end

        // Wait for master to return to IDLE completely
        wait(master_ready == 1'b1);
        #5000; 

        // ==========================================
        // TEST CASE 2: MASTER READ FROM SLAVE
        // ==========================================
        $display("[TB INFO] @ %0t ns: Starting Test Case 2 (Master Read)...", $time);
        slave_tx_data = 8'h3C;  
        
        @(posedge clk);
        slave_addr        = 7'h50;  
        rw                = 1'b1;   
        start             = 1'b1;   
        
        @(posedge clk);
        start = 1'b0;

        // Wait for master to finish fetching and go back to ready status
        #100;
        wait(master_ready == 1'b1);
        #100;
        
        if (master_read_data == 8'h3C) begin
            $display("[SUCCESS] Test Case 2 Passed! Master successfully read 8'h%h", master_read_data);
        end else begin
            $display("[FAILURE] Test Case 2 Failed! Master read: 8'h%h", master_read_data);
        end

        #500;
        $display("[TB INFO] Simulation Finished.");
        $finish;
    end

endmodule
