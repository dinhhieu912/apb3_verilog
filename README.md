# apb3_verilog

> RTL implementation of the **AMBA APB3 (Advanced Peripheral Bus v3)** protocol in Verilog HDL, including Master, configurable Slaves, and a self-checking testbench.

[![Language](https://img.shields.io/badge/Language-Verilog%20HDL-blue?style=flat-square)](https://en.wikipedia.org/wiki/Verilog)
[![Protocol](https://img.shields.io/badge/Protocol-AMBA%20APB3-orange?style=flat-square)](https://developer.arm.com/documentation/ihi0024/latest/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

---

## 📖 Table of Contents

- [Overview](#overview)
- [Protocol Background](#protocol-background)
- [Features](#features)
- [Directory Structure](#directory-structure)
- [Signal Description](#signal-description)
- [State Machine](#state-machine)
- [Getting Started](#getting-started)
- [Simulation](#simulation)
- [Waveform Example](#waveform-example)
- [References](#references)

---

## Overview

This repository provides a clean, readable Verilog RTL implementation of the **AMBA 3 APB** bus protocol as defined by ARM. APB3 is designed for low-power, low-complexity peripheral interfaces in System-on-Chip (SoC) designs — commonly used to connect peripherals such as UARTs, GPIOs, timers, and SPI controllers to a processor bus fabric.

The design follows a **single-master, multi-slave** topology with address decoding, byte-enable strobes, protection control (`PPROT`), and error response signaling (`PSLVERR`).

---

## Protocol Background

APB (Advanced Peripheral Bus) is part of the **AMBA** (Advanced Microcontroller Bus Architecture) family introduced by ARM. APB3 (AMBA 3) adds two key signals over APB2:

| Signal   | Added in | Description                          |
|----------|----------|--------------------------------------|
| `PREADY` | APB3     | Slave can insert wait states         |
| `PSLVERR`| APB3     | Slave signals a transfer error       |

Every APB transfer uses a **2-state FSM** (minimum 2 clock cycles):

```
IDLE → SETUP → ACCESS → (back to IDLE or SETUP)
```

---

## Features

- ✅ **APB3-compliant** master controller
- ✅ **Multiple slaves** with configurable address map and decode logic
- ✅ **PREADY** support — slaves can extend transfers with wait states
- ✅ **PSLVERR** error response detection and propagation
- ✅ **PPROT** protection control signals
- ✅ **PSTRB** byte-enable strobes for 32-bit write granularity
- ✅ **Self-checking testbench** — verifies read/write data integrity automatically
- ✅ Clean, well-commented code following synthesizable Verilog coding style

---

## Directory Structure

```
apb3_verilog/
├── rtl/
│   ├── apb3_master.v        # APB3 Master (initiates transfers)
│   ├── apb3_slave.v         # Generic APB3 Slave template
│   ├── apb3_decoder.v       # Address decode / slave select logic
│   └── apb3_top.v           # Top-level integration
├── tb/
│   ├── tb_apb3_top.v        # Self-checking testbench
│   └── tb_apb3_slave.v      # Individual slave unit test
├── sim/
│   └── run.do               # ModelSim / QuestaSim run script
├── docs/
│   └── apb3_waveform.png    # Example simulation waveform
└── README.md
```

---

## Signal Description

### APB3 Bus Signals

| Signal    | Direction        | Width | Description                                      |
|-----------|------------------|-------|--------------------------------------------------|
| `PCLK`    | Input            | 1     | Bus clock — all signals sampled on rising edge   |
| `PRESETn` | Input            | 1     | Active-low asynchronous reset                    |
| `PADDR`   | Master → Slave   | 32    | Transfer address                                 |
| `PSEL`    | Master → Slave   | 1/N   | Slave select (one per slave)                     |
| `PENABLE` | Master → Slave   | 1     | Indicates ACCESS phase (2nd cycle)               |
| `PWRITE`  | Master → Slave   | 1     | `1` = write, `0` = read                         |
| `PWDATA`  | Master → Slave   | 32    | Write data                                       |
| `PSTRB`   | Master → Slave   | 4     | Byte-lane strobes for write (APB3)               |
| `PPROT`   | Master → Slave   | 3     | Protection type (APB3)                           |
| `PRDATA`  | Slave → Master   | 32    | Read data                                        |
| `PREADY`  | Slave → Master   | 1     | `0` = insert wait state, `1` = transfer complete |
| `PSLVERR` | Slave → Master   | 1     | `1` = transfer error response (APB3)             |

---

## State Machine

```
         ┌─────────┐
  Reset  │         │
 ───────►│  IDLE   │◄──────────────────────────────┐
         │         │                                │
         └────┬────┘                                │
              │ PSEL asserted                       │
              ▼                                     │
         ┌─────────┐                                │
         │  SETUP  │  (1 cycle: address/ctrl valid) │
         │         │                                │
         └────┬────┘                                │
              │ PENABLE asserted                    │
              ▼                                     │
         ┌─────────┐  PREADY=0                      │
         │ ACCESS  │──────────────────────(wait)    │
         │         │                                │
         └────┬────┘  PREADY=1                      │
              │       ──────────────────────────────┘
              │       (next transfer or back to IDLE)
```

---

## Getting Started

### Prerequisites

- **ModelSim** / **QuestaSim** / **Icarus Verilog** / **Vivado Simulator**
- Any standard Verilog-2001 compatible simulator

### Clone

```bash
git clone https://github.com/<your-username>/apb3_verilog.git
cd apb3_verilog
```

---

## Simulation

### With Icarus Verilog (iverilog)

```bash
# Compile
iverilog -o sim/apb3_sim \
  rtl/apb3_master.v rtl/apb3_slave.v rtl/apb3_decoder.v rtl/apb3_top.v \
  tb/tb_apb3_top.v

# Run simulation
vvp sim/apb3_sim

# View waveform (requires GTKWave)
gtkwave sim/dump.vcd
```

### With ModelSim / QuestaSim

```tcl
# In ModelSim console
do sim/run.do
```

### Expected Output

```
[INFO] TEST: Write 0xDEADBEEF to Slave 0 @ ADDR 0x00000004 ... PASS
[INFO] TEST: Read back from Slave 0 @ ADDR 0x00000004  ... PASS
[INFO] TEST: Write with PSLVERR response from Slave 1   ... PASS
[INFO] TEST: Read with wait states (PREADY extension)   ... PASS
[INFO] ===== ALL TESTS PASSED =====
```

---

## Waveform Example

```
PCLK    ___/‾\_/‾\_/‾\_/‾\_/‾\_/‾\___
PRESETn ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
PSEL    ________/‾‾‾‾‾‾‾‾‾‾‾\________
PENABLE _____________/‾‾‾‾‾‾‾\________   ← ACCESS phase
PWRITE  ________/‾‾‾‾‾‾‾‾‾‾‾\________   ← Write transfer
PADDR   --------[  0x00000004  ]------
PWDATA  --------[ 0xDEADBEEF  ]------
PREADY  _____________/‾‾\___/‾‾\____   ← Wait state inserted
PSLVERR ________________________________
```

---

## References

- [ARM AMBA 3 APB Protocol Specification (IHI0024C)](https://developer.arm.com/documentation/ihi0024/latest/)
- Samir Palnitkar, *Verilog HDL: A Guide to Digital Design and Synthesis*, 2nd Edition, Pearson, 2008
- [EDA Playground — Free online Verilog simulator](https://www.edaplayground.com)

---

## License

This project is licensed under the [MIT License](LICENSE). Free to use for educational and research purposes.
