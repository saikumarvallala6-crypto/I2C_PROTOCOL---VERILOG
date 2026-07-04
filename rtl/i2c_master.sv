//=============================================================================
// Module Name : i2c_master
// Author      : Vallala Saikumar
// Description :
// -----------------------------------------------------------------------------
// This module implements a single-master I2C controller capable of performing
// both write and read transactions with an I2C slave.
//
// Features:
//   • Generates START and STOP conditions.
//   • Transmits 7-bit slave address with R/W bit.
//   • Supports both master write and master read operations.
//   • Samples slave ACK after address and data transfer.
//   • Generates SCL using an internal clock divider.
//   • Implements an open-drain SDA interface with external pull-up support.
//   • Controls the complete transaction using a finite state machine (FSM).
//
// Operation:
//   1. Waits for enable signal.
//   2. Generates START condition.
//   3. Sends slave address + R/W bit.
//   4. Waits for slave ACK.
//   5. Transfers one byte of data.
//   6. Generates STOP condition.
//   7. Returns to IDLE.
//
// Limitations:
//   • Single-master implementation.
//   • Supports single-byte read and write transactions.
//   • No clock stretching support.
//   • No arbitration support.
//   • Standard ACK/NACK handling only.
//
//=============================================================================

module i2c_master (
    input wire clk,             
    input wire rst,             
    input wire start,           
    input wire rw,              
    input wire [6:0] addr,      
    input wire [7:0] data_in,   
    output reg [7:0] data_out,  
    output reg i2c_scl,         
    inout wire i2c_sda,         
    output reg ready,           
    output reg ack_error        
);

//----------------------------------------------------
// Master FSM State Encoding
//----------------------------------------------------
    localparam IDLE       = 3'd0,
               START      = 3'd1,
               ADDR       = 3'd2,
               ACK1       = 3'd3,
               WRITE_DATA = 3'd4,
               READ_DATA  = 3'd5,
               MASTER_ACK = 3'd6,
               STOP       = 3'd7;

//----------------------------------------------------
// Internal Registers
//----------------------------------------------------
    reg [2:0] state;
    reg [3:0] bit_cnt;
    reg [8:0] shift_reg; 
    reg [7:0] rx_buffer;
    reg rw_reg;
    
    reg sda_drive_low;
	//----------------------------------------------------
// Open-Drain SDA Driver
//----------------------------------------------------
// Drive SDA Low when enabled.
// Otherwise release the line (High-Z), allowing the
// external pull-up resistor to pull SDA High.
//----------------------------------------------------
    assign i2c_sda = sda_drive_low ? 1'b0 : 1'bz;

    reg [7:0] clk_div;
    wire i2c_tick = (clk_div == 8'd24); 
    
    always @(posedge clk or posedge rst) begin
        if (rst) clk_div <= 0;
        else if (i2c_tick) clk_div <= 0;
        else clk_div <= clk_div + 1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= IDLE;
            sda_drive_low <= 1'b0;
            i2c_scl       <= 1'b1;
            ready         <= 1'b1; 
            ack_error     <= 1'b0;
            bit_cnt       <= 0;
            data_out      <= 8'h00;
            shift_reg     <= 9'h00;
            rx_buffer     <= 8'h00;
            rw_reg        <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
				// Wait for a transaction request while keeping the
				// I2C bus in the idle state (SCL High, SDA released).
                    i2c_scl       <= 1'b1;
                    sda_drive_low <= 1'b0; 
                    ready         <= 1'b1; 
                    if (start) begin
                        shift_reg <= {addr, rw}; 
                        rw_reg    <= rw;
                        state     <= START;
                        ready     <= 1'b0;
                        ack_error <= 1'b0;
                    end
                end

                START: begin
				// Generate the START condition by pulling SDA Low
				// while SCL remains High.
                
					if (i2c_tick) begin
                        sda_drive_low <= 1'b1; //It will makes sda_low @ open drain condition
                        i2c_scl       <= 1'b1;
                        bit_cnt       <= 4'd7;
                        state         <= ADDR;
                    end
                end

                ADDR: begin
					// Transmit the 7-bit slave address followed by
					// the Read/Write control bit.

                    if (i2c_tick) begin
                        i2c_scl <= ~i2c_scl; 
                        if (i2c_scl) begin 
                            sda_drive_low <= ~shift_reg[bit_cnt]; 
                        end else begin 
                            if (bit_cnt == 0) state <= ACK1;
                            else              bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                ACK1: begin
                    if (i2c_tick) begin
                        i2c_scl <= ~i2c_scl;
                        if (i2c_scl) begin
                            sda_drive_low <= 1'b0; 
                        end else begin
                            if (i2c_sda !== 1'b0) ack_error <= 1'b1; 
                            bit_cnt <= 4'd7;
                            if (rw_reg == 1'b1) state <= READ_DATA;
                            else begin
                                shift_reg <= {1'b0, data_in};
                                state     <= WRITE_DATA;
                            end
                        end
                    end
                end

                WRITE_DATA: begin
                    if (i2c_tick) begin
                        i2c_scl <= ~i2c_scl;
                        if (i2c_scl) begin
							// Transmit one byte of data to the slave.
                            sda_drive_low <= ~shift_reg[bit_cnt];
                        end else begin
                            if (bit_cnt == 0) state <= MASTER_ACK;
                            else              bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                READ_DATA: begin
                    if (i2c_tick) begin
                        i2c_scl <= ~i2c_scl;
                        if (i2c_scl) begin
                            sda_drive_low <= 1'b0; 
                        end else begin
                            rx_buffer[bit_cnt] <= (i2c_sda === 1'b1 || i2c_sda === 1'bz);
                            if (bit_cnt == 0) begin
                                data_out <= {rx_buffer[7:1], (i2c_sda === 1'b1 || i2c_sda === 1'bz)};
                                state    <= MASTER_ACK; 
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                            end
                        end
                    end
                end

				// Complete the data transfer.
                MASTER_ACK: begin
                    if (i2c_tick) begin
                        i2c_scl <= ~i2c_scl;
                        if (i2c_scl) begin
						// Read Operation:
						// Generate a NACK to terminate the single-byte read.
                           
						   if (rw_reg == 1'b1) sda_drive_low <= 1'b0; // Send NACK
                            else                sda_drive_low <= 1'b0; 
                        end else begin
                           // Write Operation:
						   // Wait for the slave ACK after transmitting data.

						   if (rw_reg == 1'b0 && i2c_sda !== 1'b0) ack_error <= 1'b1;
                            state <= STOP;
                        end
                    end
                end

				// Generate I2C STOP condition.
                STOP: begin
                    if (i2c_tick) begin
                        i2c_scl <= ~i2c_scl;
                        if (i2c_scl) begin
							// SDA transitions Low-to-High while SCL remains High.
                            sda_drive_low <= 1'b1; 
                        end else begin
                            sda_drive_low <= 1'b0; 
                            state         <= IDLE;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule

