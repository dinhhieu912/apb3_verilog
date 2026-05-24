# APB3 Bus Protocol Implementation (Verilog)

A synthesizable, fully verified implementation of the **AMBA APB3 (Advanced Peripheral Bus)** protocol written in Verilog. The design includes a 3-state FSM master, a parameterizable register-file slave, a two-slave top-level interconnect with address decoding, and a self-checking testbench.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Module Descriptions](#module-descriptions)
  - [apb\_master](#apb_master)
  - [apb\_slave](#apb_slave)
  - [apb\_top](#apb_top)
  - [tb\_apb](#tb_apb)
- [Signal Interface](#signal-interface)
- [State Machine](#state-machine)
- [Memory Map](#memory-map)
- [Waveform Description](#waveform-description)
- [Simulation](#simulation)

---

## Overview

This project implements the **APB3 specification** as defined in the ARM AMBA protocol family. APB3 extends the base APB protocol with:

- `PREADY` — slave-driven wait-state insertion
- `PSLVERR` — slave error reporting
- `PSTRB` — byte-lane write strobes
- `PPROT` — protection attributes

The design is structured as a single master connected to two independent slaves through a lightweight address decoder and response multiplexer.

---

## Architecture

```
                        ┌──────────────┐
                        │  apb_master  │
                        │  (FSM-based) │
                        └──────┬───────┘
                               │ APB3 Bus
                        ┌──────┴───────┐
                        │   apb_top    │
                        │ (addr decode │
                        │  + resp mux) │
                        └──────┬───────┘
               ┌───────────────┴──────────────────┐
        ┌──────┴──────┐                    ┌───────┴─────┐
        │  apb_slave  │                    │  apb_slave  │
        │  (slave 0)  │                    │  (slave 1)  │
        │ 0x0000_0000 │                    │ 0x0000_1000 │
        └─────────────┘                    └─────────────┘
```

---

## Module Descriptions

### `apb_master`

The master drives all APB3 transactions. It implements a **3-state Mealy/Moore FSM** registered on `PCLK`:

| State    | Description |
|----------|-------------|
| `IDLE`   | Bus idle. Asserts no selects. Transitions to `SETUP` when `start` is asserted. |
| `SETUP`  | Drives `PSEL`, latches `PADDR`, `PWDATA`, `PWRITE`, `PSTRB`, `PPROT`. `PENABLE` is deasserted. |
| `ACCESS` | Asserts `PENABLE`. Holds until slave drives `PREADY` high. On completion, captures `PRDATA` (read) and samples `PSLVERR`. |

Key behaviours:
- `done` pulses for one cycle after a transaction completes.
- `error` reflects `PSLVERR` sampled at the end of the ACCESS phase.
- All outputs are registered — no combinational glitch paths to the bus.

---

### `apb_slave`

A parameterizable APB3 slave with a **4 × 32-bit register file**.

| Parameter    | Default          | Description                         |
|--------------|------------------|-------------------------------------|
| `base_addr`  | `32'h0000_0000`  | Base address; top 28 bits are compared for address validation. |

Features:
- **Byte-lane write strobes (`PSTRB`)**: each of the four `PSTRB` bits independently enables writing to the corresponding byte lane of the selected register.
- **Address validation**: `addr_valid` checks `paddr[31:4]` against `base_addr[31:4]`. An access outside the valid window asserts `PSLVERR`.
- **Single-cycle ready**: `PREADY` is registered and asserted combinationally from `psel && penable`, producing a one-cycle access latency.
- **Read path**: `PRDATA` is registered on the clock edge when a valid read access completes.

Register map (relative to `base_addr`):

| Offset | Register  |
|--------|-----------|
| `0x00` | REG[0]    |
| `0x04` | REG[1]    |
| `0x08` | REG[2]    |
| `0x0C` | REG[3]    |

---

### `apb_top`

Top-level integration module. Instantiates the master and two slaves, and provides:

**Address decode** — 12-bit page granularity using `paddr[31:12]`:

| Slave    | Address Range               | `psel` condition             |
|----------|-----------------------------|------------------------------|
| Slave 0  | `0x0000_0000 – 0x0000_0FFF` | `paddr[31:12] == 20'h00000`  |
| Slave 1  | `0x0000_1000 – 0x0000_1FFF` | `paddr[31:12] == 20'h00001`  |

**Response multiplexer** — routes `PRDATA`, `PREADY`, and `PSLVERR` back to the master based on which `PSEL` is active. If no slave is selected, the mux defaults to `PRDATA=0`, `PREADY=0`, `PSLVERR=1`.

---

### `tb_apb`

A self-checking testbench that exercises the full system:

- **`apb_write(addr, data)`** task: drives a complete APB write transaction, waits for `done`, prints result with `$display`.
- **`apb_read(addr)`** task: drives a complete APB read transaction, waits for `done`, prints `RDATA` and `error`.
- 3 idle clock cycles are inserted between transactions to allow bus settling.

**Test sequence:**

| Step | Operation                        | Expected outcome         |
|------|----------------------------------|--------------------------|
| 1    | Write `0xDEADBEAD` → Slave 0 `0x00` | `error = 0`           |
| 2    | Write `0xCAFEBABA` → Slave 0 `0x04` | `error = 0`           |
| 3    | Read Slave 0 `0x00`              | `rdata = 0xDEADBEAD`     |
| 4    | Read Slave 0 `0x04`              | `rdata = 0xCAFEBABA`     |
| 5    | Write `0x11223344` → Slave 1 `0x1000` | `error = 0`         |
| 6    | Write `0xAABBCCDD` → Slave 1 `0x1004` | `error = 0`         |
| 7    | Read Slave 1 `0x1000`            | `rdata = 0x11223344`     |
| 8    | Read Slave 1 `0x1004`            | `rdata = 0xAABBCCDD`     |
| 9    | Read invalid address `0x0000_3000` | `error = 1` (PSLVERR)  |

---

## Signal Interface

### Master (`apb_master`) — Top-level ports

| Port      | Direction | Width | Description                        |
|-----------|-----------|-------|------------------------------------|
| `pclk`    | Input     | 1     | Bus clock                          |
| `presetn` | Input     | 1     | Active-low synchronous reset       |
| `start`   | Input     | 1     | Initiate a transaction             |
| `write`   | Input     | 1     | 1 = write, 0 = read                |
| `addr`    | Input     | 32    | Target address                     |
| `wdata`   | Input     | 32    | Write data                         |
| `strb`    | Input     | 4     | Byte write strobes                 |
| `prot`    | Input     | 3     | Protection attributes              |
| `done`    | Output    | 1     | Transaction complete (1-cycle pulse) |
| `error`   | Output    | 1     | `PSLVERR` captured at end of ACCESS |
| `rdata`   | Output    | 32    | Read data captured from slave      |

---

## State Machine

```
        start=0              start=1
  ┌───────────────┐    ┌──────────────────┐
  │               ▼    │                  ▼
  │            ┌──────┐          ┌────────────┐
  └────────────│ IDLE │─────────▶│   SETUP    │
               └──────┘          └─────┬──────┘
                                       │ (next cycle)
                                       ▼
                               ┌───────────────┐
                   PREADY=0 ──▶│    ACCESS     │──── PREADY=1 ──▶ IDLE
                               └───────────────┘
```

- **IDLE → SETUP**: `start` asserted
- **SETUP → ACCESS**: unconditional (1 cycle setup phase)
- **ACCESS → IDLE**: `PREADY` asserted by slave
- **ACCESS → ACCESS**: `PREADY` deasserted (wait state insertion)

---

## Memory Map

```
0x0000_0000  ┌─────────────────────┐
             │  Slave 0 – REG[0]   │  ← 0x0000_0000
             │  Slave 0 – REG[1]   │  ← 0x0000_0004
             │  Slave 0 – REG[2]   │  ← 0x0000_0008
             │  Slave 0 – REG[3]   │  ← 0x0000_000C
0x0000_1000  ├─────────────────────┤
             │  Slave 1 – REG[0]   │  ← 0x0000_1000
             │  Slave 1 – REG[1]   │  ← 0x0000_1004
             │  Slave 1 – REG[2]   │  ← 0x0000_1008
             │  Slave 1 – REG[3]   │  ← 0x0000_100C
0x0000_2000  └─────────────────────┘
             (addresses ≥ 0x0000_2000 → PSLVERR)
```

---

## Waveform Description

### Write Transaction (no wait states)

```
PCLK     ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
           └─┘ └─┘ └─┘ └─┘
           │IDLE│SETUP│ACCESS│IDLE
PSEL       ____┌─────────────┐____
PENABLE    _________┌────────┐____
PWRITE     ____┌─────────────┐____
PADDR      XXXX│─── ADDR ───│XXXX
PWDATA     XXXX│─── DATA ───│XXXX
PREADY     _________┌────────┐____   (slave asserts immediately)
done       _________________┌─┐___
```

### Read Transaction with Wait State

```
PCLK     ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
           └─┘ └─┘ └─┘ └─┘ └─┘
           │IDLE│SETUP│  ACCESS  │IDLE
PSEL       ____┌──────────────────┐__
PENABLE    _________┌─────────────┐__
PREADY     ____________0____┌─────┐__   (slave inserts 1 wait state)
PRDATA     XXXXXXXXXXXXXXXX│ DATA │XX
done       _________________________┌─┐
```

### Error Response (invalid address)

```
PSLVERR    _________┌────────┐____
done       _________________┌─┐___
error      _________________┌─┐___   (error = 1 for 1 cycle)
```

---

## Simulation

Run in any Verilog-2001 compatible simulator (Vivado, ModelSim, Icarus Verilog, VCS):

```bash
# Icarus Verilog example
iverilog -o apb_sim tb_apb.v apb_top.v apb_master.v apb_slave.v
vvp apb_sim
```

Expected console output:

```
========== Starting APB Bus Test ==========
RESET done
WRITE @ 00000000 = deadbead    error = 0
WRITE @ 00000004 = cafebaba    error = 0
READ  @ 00000000 = deadbead    error = 0
READ  @ 00000004 = cafebaba    error = 0
WRITE @ 00001000 = 11223344    error = 0
WRITE @ 00001004 = aabbccdd    error = 0
READ  @ 00001000 = 11223344    error = 0
READ  @ 00001004 = aabbccdd    error = 0
READ  @ 00003000 = xxxxxxxx    error = 1
========== APB Bus Test Completed ==========
```
