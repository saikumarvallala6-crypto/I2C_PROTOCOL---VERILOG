# I2C Protocol Implementation in Verilog

## Overview

This repository contains a Verilog implementation of the **Inter-Integrated Circuit (I2C)** protocol using a **single Master** and **single Slave** architecture.

The project demonstrates the fundamental operation of the I2C protocol including address transmission, acknowledgment handling, single-byte data transfer, and open-drain bus communication. The design is intended for learning RTL design, digital communication protocols, and finite state machine (FSM) implementation.

The project was developed as part of my RTL Design and VLSI learning journey.

---

## Features

- Single Master implementation
- Single Slave implementation
- 7-bit slave addressing
- Read operation
- Write operation
- START and STOP condition generation
- ACK/NACK handling
- Open-drain SDA implementation
- Internal SCL generation using clock divider
- Synchronization of asynchronous SDA/SCL signals inside slave
- FSM-based protocol implementation
- Self-checking style simulation testbench

---

## Repository Structure

```
I2C_Protocol/
│
├── i2c_master.sv
├── i2c_slave.sv
├── i2c_rtl_top.sv
├── i2c_tb.sv
│
├── images/
│   ├── i2c_master_fsm.png
│   ├── i2c_slave_fsm.png
│   ├── i2c_rtl_schematic_diagram.png
│   └── i2c_wave.png
│
└── README.md
```

---

## Module Description

### 1. i2c_master.sv

Implements the I2C Master controller.

Responsibilities:

- Generates START condition
- Generates STOP condition
- Generates SCL
- Sends Slave Address
- Sends Read/Write bit
- Waits for ACK
- Performs single-byte Write
- Performs single-byte Read
- Generates Master NACK after Read
- Reports ACK error
- Controls entire transaction using FSM

---

### 2. i2c_slave.sv

Implements an I2C Slave device.

Responsibilities:

- Detects START condition
- Detects STOP condition
- Receives slave address
- Matches configured slave address
- Sends ACK
- Receives write data
- Transmits read data
- Synchronizes SDA/SCL using system clock
- Generates receive valid signal

---

### 3. i2c_top_system.sv

Top-level integration module.

Responsibilities:

- Instantiates Master
- Instantiates Slave
- Connects shared SDA bus
- Connects shared SCL bus
- Models pull-up resistors
- Provides complete one-master one-slave I2C system

---

### 4. i2c_tb.sv

Simulation testbench.

Implements two functional test cases:

### Test Case 1

Master Write

- Sends slave address
- Sends one byte
- Slave stores received byte
- Testbench checks received data

### Test Case 2

Master Read

- Slave loads transmit data
- Master performs read transaction
- Testbench checks received data

Simulation status is displayed using `$display`.

---

# Master FSM

The Master controller consists of the following states:

```
IDLE
 ↓
START
 ↓
ADDR
 ↓
ACK1
 ↓
 ├── WRITE_DATA
 │      ↓
 │   MASTER_ACK
 │
 └── READ_DATA
        ↓
   MASTER_ACK
        ↓
STOP
 ↓
IDLE
```

---

# Slave FSM

The Slave controller consists of the following states:

```
IDLE
 ↓
GET_ADDR
 ↓
SEND_ACK1
 ↓
 ├── RX_DATA
 │
 └── TX_DATA
        ↓
     RX_ACK2
        ↓
      IDLE
```

---

# I2C Bus

The design models the physical I2C bus using:

- Shared SDA line
- Shared SCL line
- Open-drain SDA
- Pull-up resistor

```
          +-------------+
          |  I2C Master |
          +-------------+
                |
        SDA <---+--------------------+
                |                    |
        SCL ----+--------------------+
                |                    |
          +-------------+            |
          |  I2C Slave  |            |
          +-------------+            |
                                     |
                               Pull-up Resistor
```

---

# Simulation

The project has been simulated using

- QuestaSim

Simulation verifies

- START generation
- Address transfer
- ACK reception
- Write transaction
- Read transaction
- STOP generation

Waveforms are included in the repository.

---

# Limitations

Current implementation supports

- Single Master
- Single Slave
- One-byte transfer
- 7-bit addressing

The following protocol features are not implemented

- Multi-master arbitration
- Clock stretching
- Repeated START
- 10-bit addressing
- Burst transfer
- Multiple slave devices
- High-Speed mode
- General Call addressing

---

# Tools Used

- Verilog HDL
- QuestaSim
- Git
- GitHub

---

# Learning Outcomes

This project helped me understand

- RTL Design
- FSM Design
- I2C Protocol
- Open-drain bus implementation
- Clock division
- Synchronization of asynchronous inputs
- Testbench development
- Digital communication protocols

---

# Future Improvements

Possible future enhancements include

- Multiple slave support
- Repeated START
- Clock stretching
- 10-bit addressing
- Burst read/write
- Parameterized clock frequency
- Parameterized data width
- UVM/SystemVerilog verification environment
- Functional coverage
- Assertions (SVA)

---

## Author

**Vallala Saikumar**

RTL Design | FPGA | VLSI Design Verification

GitHub: *(Add your GitHub profile link here)*

LinkedIn: *(Add your LinkedIn profile link here)*

---

## License

This project is intended for educational and learning purposes.
