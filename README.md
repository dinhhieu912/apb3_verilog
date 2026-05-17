# apb3_verilog

RTL implementation of the **AMBA APB3 (Advanced Peripheral Bus v3)** protocol in Verilog HDL.

![Language](https://img.shields.io/badge/Language-Verilog%20HDL-blue?style=flat-square)
![Protocol](https://img.shields.io/badge/Protocol-AMBA%20APB3-orange?style=flat-square)

---

## Overview

This project implements the AMBA 3 APB bus protocol as defined by ARM. APB3 is designed for low-power, low-complexity peripheral interfaces in SoC designs — commonly used to connect peripherals such as UARTs, GPIOs, and timers to a processor bus fabric.

---

## Files

| File | Description |
|------|-------------|
| `apb3_master.v` | APB3 Master — initiates read/write transfers on the bus |
| `apb3_slave.v` | APB3 Slave — receives and responds to transfers from the master |
| `apb3_top.v` | Top-level — connects master and slave, handles address decode |
| `tb_apb3_top.v` | Testbench — applies read/write stimulus and checks correctness |

---

## Protocol Summary

APB3 (AMBA 3) adds two signals over APB2: `PREADY` (slave wait states) and `PSLVERR` (error response). Every transfer uses a 3-state FSM with a minimum of 2 clock cycles:
### Signal Table

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `PCLK` | Input | 1 | Bus clock — all signals sampled on rising edge |
| `PRESETn` | Input | 1 | Active-low reset |
| `PADDR` | Master → Slave | 32 | Transfer address |
| `PSEL` | Master → Slave | 1 | Slave select |
| `PENABLE` | Master → Slave | 1 | High during ACCESS phase |
| `PWRITE` | Master → Slave | 1 | `1` = write, `0` = read |
| `PWDATA` | Master → Slave | 32 | Write data |
| `PSTRB` | Master → Slave | 4 | Byte-lane write strobes |
| `PPROT` | Master → Slave | 3 | Protection type |
| `PRDATA` | Slave → Master | 32 | Read data |
| `PREADY` | Slave → Master | 1 | `0` = wait, `1` = transfer complete |
| `PSLVERR` | Slave → Master | 1 | `1` = transfer error |

---

## Simulation

### Icarus Verilog

```bash
iverilog -o apb3_sim apb3_master.v apb3_slave.v apb3_top.v tb_apb3_top.v
vvp apb3_sim
```

### ModelSim / QuestaSim

```tcl
vlog apb3_master.v apb3_slave.v apb3_top.v tb_apb3_top.v
vsim work.tb_apb3_top
run -all
```

---

## References

- [ARM AMBA 3 APB Protocol Specification (IHI0024C)](https://developer.arm.com/documentation/ihi0024/latest/)
- Samir Palnitkar, *Verilog HDL: A Guide to Digital Design and Synthesis*, 2nd Edition
