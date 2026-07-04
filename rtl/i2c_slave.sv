//==============================================================================
// Module Name : i2c_slave
// Author      : vallala saikumar
// Project     : I2C Protocol Implementation in Verilog
//
// Description :
// -----------------------------------------------------------------------------
// This module implements a single-byte I2C slave compatible with a single-master
// I2C bus. The slave detects START and STOP conditions, decodes the incoming
// 7-bit slave address, acknowledges valid transactions, and supports both
// master-write and master-read operations.
//
// Features:
//   • Detects START and STOP conditions.
//   • Receives and decodes 7-bit slave address.
//   • Supports one-byte write operation.
//   • Supports one-byte read operation.
//   • Generates ACK after successful address reception.
//   • Samples write data on SCL rising edge.
//   • Drives read data on SCL falling edge.
//   • Open-drain SDA implementation.
//   • Two-stage synchronization for SDA and SCL inputs.
//
// FSM States:
//   IDLE
//   GET_ADDR
//   SEND_ACK1
//   RX_DATA
//   TX_DATA
//   RX_ACK2
//
// Notes:
// - Implements open-drain SDA behavior.
// - Intended for protocol demonstration.
// - Stores one received byte.
//
// Limitations:
//   • Single-master operation only.
//   • Supports one-byte transfers.
//   • No repeated START support.
//   • No clock stretching.
//   • No arbitration support.
//==============================================================================

module i2c_slave (
    input wire clk,             // Uses system clock to filter and sample signals safely
    input wire rst,
    input wire i2c_scl,
    inout wire i2c_sda,
    input wire [7:0] tx_data,   
    output reg [7:0] rx_data,   
    output reg rx_valid         
);

    parameter SLAVE_ADDR = 7'h50; 

    localparam IDLE      = 3'd0,
               GET_ADDR  = 3'd1,
               SEND_ACK1 = 3'd2,
               RX_DATA   = 3'd3,
               TX_DATA   = 3'd4,
               RX_ACK2   = 3'd5;

    reg [2:0] state;
    reg [3:0] bit_cnt;

	// Stores received address and R/W bit
	reg [7:0] addr_buffer;
	
	// Stores received data byte
	reg [7:0] rx_buffer;
	
	// Stores transmit data byte
	reg [7:0] tx_buffer;
	
	// Indicates Read(1) or Write(0) transaction
	reg rw_mode;
    
    reg sda_drive_low;
    assign i2c_sda = sda_drive_low ? 1'b0 : 1'bz;

    // Synchronize and filter SCL and SDA lines to clear race conditions
    reg scl_r0, scl_r1;
    reg sda_r0, sda_r1;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scl_r0 <= 1'b1; scl_r1 <= 1'b1;
            sda_r0 <= 1'b1; sda_r1 <= 1'b1;
        end else begin
            scl_r0 <= i2c_scl;
            scl_r1 <= scl_r0;
            sda_r0 <= (i2c_sda === 1'b1 || i2c_sda === 1'bz);
            sda_r1 <= sda_r0;
        end
    end

    // Edge Detection Filters
    wire scl_posedge = (scl_r0 && !scl_r1);
    wire scl_negedge = (!scl_r0 && scl_r1);
    wire start_detect = (!sda_r0 && sda_r1 && scl_r0);
    wire stop_detect  = (sda_r0 && !sda_r1 && scl_r0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            bit_cnt     <= 0;
            rx_valid    <= 1'b0;
            rx_data     <= 8'h00;
            addr_buffer <= 8'h00;
            rx_buffer   <= 8'h00;
            rw_mode     <= 1'b0;
            sda_drive_low <= 1'b0;
            tx_buffer   <= 8'h00;
        end else if (stop_detect) begin
            state         <= IDLE;
            bit_cnt       <= 0;
            rx_valid      <= 1'b0;
            sda_drive_low <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    rx_valid      <= 1'b0;
                    sda_drive_low <= 1'b0;
					// Wait for START condition from master.
                    if (start_detect) begin
                        state   <= GET_ADDR;
                        bit_cnt <= 0;
                    end
                end

                GET_ADDR: begin
                    if (scl_posedge) begin
						// Receive 7-bit slave address and R/W bit.
                        addr_buffer[7 - bit_cnt] <= sda_r0;
                       
					  	 if (bit_cnt == 7) begin
							// Compare received address with local address.
                            if (addr_buffer[7:1] == SLAVE_ADDR) begin
                                rw_mode <= sda_r0;
                                state   <= SEND_ACK1;
                            end else begin
                                state   <= IDLE;
                            end
                            bit_cnt <= 0;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end

                SEND_ACK1: begin
                    if (scl_negedge) begin
                        sda_drive_low <= 1'b1; // Drive low on SCL falling edge
                    end else if (scl_posedge) begin
                        // Move forward on rising edge
                        bit_cnt <= 0;

						// Decide next operation based on R/W bit.
                        if (rw_mode == 1'b1) begin
                            tx_buffer <= tx_data;
                            state     <= TX_DATA;
                        end else begin
                            state     <= RX_DATA;
                        end
                    end
                end

                RX_DATA: begin
                    if (scl_negedge) sda_drive_low <= 1'b0; // Release ACK driving
                    // Receive one byte from master.
					// Sample data on SCL rising edge.
                    
					if (scl_posedge) begin
                        rx_buffer[7 - bit_cnt] <= sda_r0;
                        if (bit_cnt == 7) begin
                            rx_data  <= {rx_buffer[7:1], sda_r0};
                            rx_valid <= 1'b1;
                            state    <= IDLE;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end

                TX_DATA: begin
				// Transmit one byte to master.
				// Update SDA on SCL falling edge.
                    if (scl_negedge) begin
                        sda_drive_low <= ~tx_buffer[7 - bit_cnt];
                    end else if (scl_posedge) begin
                        if (bit_cnt == 7) begin
                            state   <= RX_ACK2;
                            bit_cnt <= 0;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end

                RX_ACK2: begin
				// Wait for ACK/NACK from master after
				// completing slave transmit operation.
                    if (scl_negedge) sda_drive_low <= 1'b0;
                    if (scl_posedge) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
