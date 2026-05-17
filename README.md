# apb3_verilog

> APB3 (Advanced Peripheral Bus v3) protocol implemented in Verilog — single-master single-slave topology with PREADY wait states, PSLVERR error response, and directed testbench verification.

---

## 📌 Overview

APB (Advanced Peripheral Bus) is part of the **AMBA** (Advanced Microcontroller Bus Architecture) family defined by ARM. It is designed for **low-bandwidth, low-power peripheral interfaces** — commonly used to connect peripherals such as UARTs, GPIOs, timers, and SPI controllers to a processor bus fabric within an SoC.

Unlike AHB or AXI, APB is **non-pipelined** — meaning only one transfer can be in progress at a time. This simplicity makes it ideal for peripherals where throughput is not critical but ease of integration is.

### How APB3 works:

- **IDLE state:** The bus is inactive; no transfer is in progress.
- **SETUP phase:** Master drives address, control signals, and write data for one clock cycle.
- **ACCESS phase:** `PENABLE` is asserted. The slave completes the transfer when it drives `PREADY = 1`.
- **Wait states:** The slave can hold `PREADY = 0` to extend the ACCESS phase as needed.
- **Error response:** The slave asserts `PSLVERR = 1` (sampled alongside `PREADY = 1`) to signal a transfer error.

```
IDLE  |  SETUP  |         ACCESS          |  IDLE
      | PSEL=1  | PSEL=1, PENABLE=1       |
      |         | PREADY=0 (wait) ... =1  |
```

This project implements a **single-master, single-slave** APB3 system in synthesizable Verilog-2001, verified through a directed testbench covering normal operation, wait states, and error responses.

---

## ⚙️ Features

- ✅ APB3-compliant master controller with 3-state FSM (IDLE / SETUP / ACCESS)
- ✅ APB3 slave with internal register file
- ✅ `PREADY` support — slave can insert wait states
- ✅ `PSLVERR` error response detection
- ✅ `PSTRB` byte-lane write strobes for 32-bit data bus
- ✅ `PPROT` protection control signals
- ✅ Self-checking testbench — automatically verifies read/write data integrity
- ✅ Synthesizable Verilog-2001, no proprietary dependencies

---

## 🛠️ Tech Stack

| Area       | Details                  |
|:-----------|:-------------------------|
| HDL        | Verilog-2001             |
| Simulation | Icarus Verilog, ModelSim |
| Waveform   | GTKWave                  |
| Protocol   | AMBA APB3 (ARM IHI0024C) |

---

## 📁 Project Structure

```
apb3_verilog/
├── apb3_master.v       # APB3 Master — FSM that initiates read/write transfers
├── apb3_slave.v        # APB3 Slave — register file, PREADY/PSLVERR logic
├── apb3_top.v          # Top-level — connects master <-> slave
└── tb_apb3_top.v       # Self-checking testbench — stimulus + result checking
```

---

## 🔧 RTL Design

### Master Module (`apb3_master.v`)

The master is controlled by a **3-state FSM**:

```
IDLE → SETUP → ACCESS → (IDLE or SETUP)
```

| State  | Description                                                  |
|:-------|:-------------------------------------------------------------|
| IDLE   | Bus inactive; waiting for a transfer request                 |
| SETUP  | `PSEL` asserted; address, `PWRITE`, `PWDATA` driven for 1 cycle |
| ACCESS | `PENABLE` asserted; holds until slave drives `PREADY = 1`   |

- In the ACCESS phase, if the slave holds `PREADY = 0`, the master remains in ACCESS (wait state).
- On `PREADY = 1`, the master captures `PRDATA` (for reads) or confirms write completion, then returns to IDLE or begins the next SETUP.

---

### Slave Module (`apb3_slave.v`)

The slave contains an **internal register file** and responds to master transfers:

| Signal   | Behavior                                                          |
|:---------|:------------------------------------------------------------------|
| `PREADY` | Driven `1` when the slave is ready to complete the transfer       |
| `PRDATA` | Valid read data driven when `PSEL=1`, `PENABLE=1`, `PWRITE=0`    |
| `PSLVERR`| Asserted alongside `PREADY=1` when an invalid address is accessed |

- Write strobes (`PSTRB`) are used to selectively write individual byte lanes of a 32-bit register.
- Addresses outside the valid register map cause `PSLVERR = 1`.

---

## 📶 Signal Description

| Signal    | Direction      | Width | Description                                              |
|:----------|:---------------|:------|:---------------------------------------------------------|
| `PCLK`    | Input          | 1     | Bus clock — all signals sampled on the **rising edge**   |
| `PRESETn` | Input          | 1     | Active-low synchronous reset                             |
| `PADDR`   | Master → Slave | 32    | Transfer address                                         |
| `PSEL`    | Master → Slave | 1     | Slave select — asserted throughout the transfer          |
| `PENABLE` | Master → Slave | 1     | High during ACCESS phase (second cycle onward)           |
| `PWRITE`  | Master → Slave | 1     | `1` = write, `0` = read                                 |
| `PWDATA`  | Master → Slave | 32    | Write data — valid when `PSEL` and `PWRITE` are high     |
| `PSTRB`   | Master → Slave | 4     | Byte-lane strobes — bit N enables byte N of `PWDATA`     |
| `PPROT`   | Master → Slave | 3     | Protection: `[0]` privileged, `[1]` non-secure, `[2]` instruction |
| `PRDATA`  | Slave → Master | 32    | Read data — valid when `PENABLE` and `PREADY` are high   |
| `PREADY`  | Slave → Master | 1     | `0` = wait state, `1` = transfer complete                |
| `PSLVERR` | Slave → Master | 1     | `1` = transfer error (sampled with `PREADY = 1`)         |

---

## ✅ Verification

### Testbench Strategy

A **directed testbench** (`tb_apb3_top.v`) applies specific stimuli to the top-level and checks outputs against expected values. Each test case targets a distinct transfer scenario or fault condition.

### Test Cases

| #  | Test Case                  | Description                                              | Result   |
|:---|:---------------------------|:---------------------------------------------------------|:---------|
| 1  | Basic write                | Write 0xDEADBEEF to a valid address                      | ✅ Pass  |
| 2  | Basic read                 | Read back written value, verify data matches             | ✅ Pass  |
| 3  | Write with wait state      | Slave holds `PREADY=0` for 2 cycles, then completes      | ✅ Pass  |
| 4  | Read with wait state       | Same as above for a read transfer                        | ✅ Pass  |
| 5  | PSLVERR on invalid address | Access out-of-range address, verify `PSLVERR=1`          | ✅ Pass  |
| 6  | Byte strobe write          | Write with `PSTRB=4'b0011`, verify only low 2 bytes written | ✅ Pass  |
| 7  | Back-to-back transfers     | Multiple consecutive transfers without returning to IDLE | ✅ Pass  |
| 8  | Reset during transfer      | Assert `PRESETn` mid-transfer, verify clean recovery     | ✅ Pass  |

### Bug Found & Fixed

During waveform inspection in GTKWave, a **SETUP-to-ACCESS timing issue** was identified:
- **Root cause:** `PENABLE` was being asserted one cycle too early when back-to-back transfers were issued, violating the APB3 specification which requires exactly one SETUP cycle before ACCESS.
- **Fix:** Added a dedicated state register to enforce the one-cycle SETUP phase before transitioning to ACCESS, regardless of transfer sequence.

---

## 🚀 How to Run

### Simulate with Icarus Verilog

```bash
# Clone the repo
git clone https://github.com/<your-username>/apb3_verilog.git
cd apb3_verilog

# Compile
iverilog -o apb3_sim apb3_master.v apb3_slave.v apb3_top.v tb_apb3_top.v

# Run simulation
vvp apb3_sim

# View waveform (if $dumpfile is enabled in testbench)
gtkwave dump.vcd
```

### Simulate with ModelSim

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
[PASS] Read with wait state inserted
[PASS] PSLVERR correctly flagged on invalid address
[PASS] Byte strobe write — partial lane update verified
[PASS] Back-to-back transfers
[PASS] Reset recovery
========================================
  ALL TESTS PASSED
========================================
```

---

## 📬 Contact

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/hiếu-trần-59a741305/)
[![Gmail](https://img.shields.io/badge/Gmail-D14836?style=flat-square&logo=gmail&logoColor=white)](mailto:dinhhieu9125@gmail.com)
