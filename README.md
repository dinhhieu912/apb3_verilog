# apb3_verilog

> RTL implementation of the **AMBA APB3 (Advanced Peripheral Bus v3)** protocol written in Verilog HDL, compliant with the ARM AMBA 3 specification.

![Language](https://img.shields.io/badge/Language-Verilog--2001-blue?style=flat-square)
![Protocol](https://img.shields.io/badge/Protocol-AMBA%20APB3-orange?style=flat-square)
![Status](https://img.shields.io/badge/Status-Simulation%20Verified-brightgreen?style=flat-square)

---

## Table of Contents

- [Overview](#overview)
- [Protocol Background](#protocol-background)
- [File Structure](#file-structure)
- [Signal Description](#signal-description)
- [State Machine](#state-machine)
- [Timing Diagrams](#timing-diagrams)
- [Simulation](#simulation)
- [References](#references)

---

## Overview

APB (Advanced Peripheral Bus) is part of the **AMBA** (Advanced Microcontroller Bus Architecture) family defined by ARM. It is specifically designed for **low-bandwidth, low-power peripheral interfaces** — ideal for connecting peripherals such as UARTs, GPIOs, timers, and SPI controllers within an SoC.

This project implements a complete **single-master, single-slave** APB3 system in synthesizable Verilog-2001, including:

- A master that initiates read and write transfers
- A slave with an internal register file that responds to transfers
- A top-level module that wires the two together
- A self-checking testbench that verifies data integrity

---

## Protocol Background

### APB3 vs APB2

| Feature | APB2 | APB3 |
|---------|------|------|
| Wait states | ✗ | ✅ via `PREADY` |
| Error response | ✗ | ✅ via `PSLVERR` |
| Byte strobes | ✗ | ✅ via `PSTRB` |
| Protection control | ✗ | ✅ via `PPROT` |

### Transfer Phases

Every APB3 transfer goes through three phases:

| Phase | Duration | Description |
|-------|----------|-------------|
| **IDLE** | — | Bus is inactive, no transfer in progress |
| **SETUP** | 1 cycle | Address, control, and write data are driven |
| **ACCESS** | 1+ cycles | `PENABLE` is asserted; slave may extend with `PREADY = 0` |

Minimum transfer latency is **2 clock cycles** (SETUP + ACCESS with no wait states).

---

## File Structure

```
apb3_verilog/
├── apb3_master.v       # APB3 Master controller — FSM that initiates transfers
├── apb3_slave.v        # APB3 Slave — internal register file, PREADY/PSLVERR logic
├── apb3_top.v          # Top-level integration — connects master <-> slave
└── tb_apb3_top.v       # Self-checking testbench — write/read stimulus + assertions
```

---

## Signal Description

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `PCLK` | Input | 1 | Bus clock — all signals are sampled on the **rising edge** |
| `PRESETn` | Input | 1 | Active-low synchronous reset |
| `PADDR` | Master → Slave | 32 | Transfer address |
| `PSEL` | Master → Slave | 1 | Slave select — asserted for the entire duration of a transfer |
| `PENABLE` | Master → Slave | 1 | Asserted in the ACCESS phase (second cycle onward) |
| `PWRITE` | Master → Slave | 1 | Transfer direction: `1` = write, `0` = read |
| `PWDATA` | Master → Slave | 32 | Write data — valid when `PSEL` and `PWRITE` are high |
| `PSTRB` | Master → Slave | 4 | Byte-lane write strobes: bit N enables byte lane N of `PWDATA` |
| `PPROT` | Master → Slave | 3 | Protection type: `[0]` privileged, `[1]` non-secure, `[2]` instruction |
| `PRDATA` | Slave → Master | 32 | Read data — valid when `PENABLE` and `PREADY` are high |
| `PREADY` | Slave → Master | 1 | `0` = slave inserts wait state, `1` = transfer complete |
| `PSLVERR` | Slave → Master | 1 | `1` = slave signals a transfer error (sampled with `PREADY = 1`) |

---

## State Machine

The APB3 master is implemented as a 3-state FSM:

```
                  +-------------------------------------------+
                  |                                           |
         +--------v--------+                                  |
  Reset  |                 |  PSEL deasserted                 |
 ------->|      IDLE       |<---------------------------------+
         |                 |                                  |
         +--------+--------+                                  |
                  | PSEL asserted                             |
                  v                                           |
         +-----------------+                                  |
         |                 |  Address, PWRITE, PWDATA valid   |
         |      SETUP      |                                  |
         |                 |                                  |
         +--------+--------+                                  |
                  | PENABLE asserted                          |
                  v                                           |
         +-----------------+  PREADY = 0                     |
         |                 |--------------------(hold)        |
         |     ACCESS      |                                  |
         |                 |  PREADY = 1                     |
         +--------+--------+--------------------------------->+
                  |
                  |  Transfer complete — PRDATA / PSLVERR captured
```

---

## Timing Diagrams

### Write Transfer (no wait states)

```
          Cycle:   1       2       3
          PCLK  __|~|__|~|__|~|__|~|__
          PSEL  ______|~~~~~~~~~~~~~
         PWRITE ______|~~~~~~~~~~~~~
        PENABLE ___________|~~~~~~~~
          PADDR ------[ ADDR ]------
         PWDATA ------[ DATA ]------
         PREADY ~~~~~~~~~~~~~~~~~~~
                  IDLE  SETUP ACCESS
```

### Read Transfer (with 1 wait state)

```
          Cycle:   1       2       3       4
          PCLK  __|~|__|~|__|~|__|~|__|~|__
          PSEL  ______|~~~~~~~~~~~~~~~~~
         PWRITE __________________________ (low = read)
        PENABLE ___________|~~~~~~~~~~~~
          PADDR ------[ ADDR ]----------
         PREADY _______________|__|~~~~~ <- wait state cycle 3
         PRDATA _____________________[ DATA ]
                  IDLE  SETUP  ACCESS(wait) done
```

---

## Simulation

### Requirements

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) — free and open-source
- [GTKWave](https://gtkwave.sourceforge.net/) — waveform viewer (optional)
- Or: ModelSim / QuestaSim / Vivado Simulator

### Run with Icarus Verilog

```bash
# Compile all source and testbench files
iverilog -o apb3_sim apb3_master.v apb3_slave.v apb3_top.v tb_apb3_top.v

# Run simulation
vvp apb3_sim

# Open waveform (if $dumpfile is enabled in testbench)
gtkwave dump.vcd
```

### Run with ModelSim / QuestaSim

```tcl
vlog apb3_master.v apb3_slave.v apb3_top.v tb_apb3_top.v
vsim work.tb_apb3_top
add wave -r /*
run -all
```

### Expected Console Output

```
[PASS] Write 0xDEADBEEF to 0x00000000
[PASS] Read back 0xDEADBEEF from 0x00000000
[PASS] Write with wait state inserted
[PASS] PSLVERR correctly flagged on invalid address
=======================================
  ALL TESTS PASSED
=======================================
```

---

## References

- [ARM AMBA 3 APB Protocol Specification — IHI0024C](https://developer.arm.com/documentation/ihi0024/latest/)
- Samir Palnitkar, *Verilog HDL: A Guide to Digital Design and Synthesis*, 2nd Edition, Pearson, 2008
- [EDA Playground — Free online Verilog simulator](https://www.edaplayground.com)
