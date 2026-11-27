# Regression Run Report — `RUN-GATE5-002`

- **Run ID:** `RUN-GATE5-002`
- **Date/time:** `2026-11-27T18:09:10+02:00`
- **Author:** Independent Verification Engineer Agent
- **Status:** `PASS` (**68 / 68 passed**, **0 failed**, **0 SVA property errors**, **0 Golden ISS mismatches**)
- **Specification revision:** `SOC_SPECIFICATION_DRAFT.md` (Draft 0.3)
- **Interface contracts:** `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1 (`IHI0024E` Issue B), `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1, `CON-PERIPH-001` v1.0
- **Verification baselines:** `SOC_VB_001.1` (`DEC-VER-BASELINE-003` — `APPROVED`) & `SOC_VB_002` (`DEC-VER-BASELINE-002` — `APPROVED`), with approved TB patch `DEC-VER-PATCH-001` (`INV-GATE5-001` resolved; `RUN-GATE5-001` preserved intact)
- **RTL branch/commit:** `dev/gate2-4-rtl-and-verif` (branched from `main` checkpoint `85dcd83`, zero RTL changes since `RUN-GATE5-001`)

---

## 1. Tools & Commands Executed
- **RISC-V Toolchain:** `riscv64-unknown-elf-gcc (14.2.0+19) 14.2.0`, `GNU assembler 2.45.50` (`60 / 60` `.mem` images, `180 / 180` SHA-256 `OK` from `DEC-VER-BASELINE-003` build)
- **RTL Simulator:** `Verilator 5.032 2025-01-01 rev (Debian 5.032-1)` (`--binary --assert --timing --public-flat-rw`, `-DSVA_ENABLE_INTERNAL_BINDS` on `tb_soc_top`)
- **Command:** `python3 tb/run_gate5.py --log regression/runs/RUN-GATE5-002.log` -> **`exit 0` (`PASSED=68, FAILED=0, SVA_ERRORS=0, TOTAL=68`)**
- **Full run log:** [RUN-GATE5-002.log](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-002.log)

---

## 2. Per-Test Results Summary

| Group | Test ID(s) | Harness | Result | Notes |
|---|---|---|---|---|
| RV32I Base ISA & `FENCE` | `VER-CORE-001` | `TB-SOC-TOP` | `PASS` (163 retires) | All 40 RV32I ops, `x0`, branches, `JAL/JALR`, `FENCE` |
| Modified Harvard `IROM` Port B + `DRAM` `RAM-B` | `VER-CORE-002` | `TB-SOC-TOP` | `PASS` (154 retires) | 2-cycle `.rodata` & `DRAM` loads, byte/halfword `SB/SH/SW` |
| APB3 Wait-State Sweep (`0,1,2,5,16`) & Glitch | `VER-CORE-003` (`w0,w1,w2,w5`), `VER-BUS-001` | `TB-CORE-BUS` | `PASS` (5/5, 77 retires each) | Mock APB3 Completers, `PSLVERR` ignored when `PREADY=0` |
| Bare-Metal C Modified Harvard | `VER-CORE-004` | `TB-CORE-BUS` | `PASS` (62 retires) | `.rodata` in `IROM`, `.data` copy, `.bss` clear, stack, APB3 |
| `FAULT_IF_UNMAPPED` (`4'h2`) | `VER-FAULT-001_sub0..2` | `TB-SOC-TOP` | `PASS` (3/3) | `0x0000_8000`, `0x2000_0000`, `0x4000_0000` |
| `FAULT_IF_MISALIGNED` (`4'h1`) | `VER-FAULT-002_sub0..1` | `TB-SOC-TOP` | `PASS` (2/2) | `JALR` to `0x202` and `0x203` (`& ~1 -> 0x202`) |
| `FAULT_ILLEGAL_INSN` (`4'h3`) | `VER-FAULT-003_sub0..5` | `TB-SOC-TOP` | `PASS` (6/6) | `0x0`, `0xFFFF_FFFF`, `CSRRW`, `MRET`, `MUL`, `FENCE.I` |
| `FAULT_ECALL` (`4'h4`) / `FAULT_EBREAK` (`4'h5`) | `VER-FAULT-004`, `VER-FAULT-005` | `TB-SOC-TOP` | `PASS` (2/2) | Exact `fault_pc`, `fault_insn`, sentinel untouched |
| `FAULT_DATA_UNMAPPED` (`4'h7`) | `VER-FAULT-006_sub0..5` | `TB-SOC-TOP` | `PASS` (6/6) | Gaps 0/1/2 + reserved APB slots `0x4000_3000..FFFC` |
| `FAULT_DATA_RO_WRITE` (`4'hA`) | `VER-FAULT-007_sub0..2` | `TB-SOC-TOP` | `PASS` (3/3) | `SW`/`SH`/`SB` to `IROM` |
| `FAULT_DATA_SIZE_UNSUP` (`4'h8`) | `VER-FAULT-008_sub0..5` | `TB-SOC-TOP` | `PASS` (6/6) | `LB`/`LBU`/`LH`/`LHU`/`SB`/`SH` to APB3 slots |
| `FAULT_DATA_MISALIGNED` (`4'h6`) | `VER-FAULT-009_sub0..6` | `TB-SOC-TOP` | `PASS` (7/7) | `IROM`/`DRAM`/`APB3` halfword & word misalignment |
| `FAULT_APB_SLVERR` (`4'h9`) | `VER-FAULT-010_sub0..1` (3 runs) | `TB-CORE-BUS` | `PASS` (3/3) | `LW` (0/2 waits) & `SW` (1 wait), `RF[rd]` unmutated |
| Fault Priority Matrix | `VER-FAULT-011_sub0..4` | `TB-SOC-TOP` | `PASS` (5/5) | All 5 priority overlap cases |
| Reset Recovery (APB stall / Local RD / Fault) | `VER-RST-002` (3 runs) | `TB-CORE-BUS` / `TB-SOC-TOP` | `PASS` (3/3) | Clean recovery from `ACCESS`, `local_rd_valid`, and `ECALL` |
| UART Functional & `PSLVERR` | `VER-UART-001`, `VER-UART-002_sub0..4` | `TB-SOC-TOP` | `PASS` (6/6) | `887` retires on `VER-UART-001`; all 5 `PSLVERR` subcases |
| GPIO Functional & `PSLVERR` | `VER-GPIO-001`, `VER-GPIO-002_sub0..2` | `TB-SOC-TOP` | `PASS` (4/4) | `330` retires on `VER-GPIO-001`; walking-1/0, 2-FF `ECHO_INV`, `PSLVERR` |
| Timer Functional & `PSLVERR` | `VER-TIMER-001`, `VER-TIMER-002_sub0..1` | `TB-SOC-TOP` | `PASS` (3/3) | `275` retires on `VER-TIMER-001`; `MATCH`, `AUTO_RELOAD`, `CLR_CNT`, `OVF` |
| Combined Peripheral Integration (C) | `VER-PERIPH-INT-001` | `TB-SOC-TOP` | `PASS` (669 retires) | Timer + GPIO + UART bare-metal C integration |

---

## 3. SVA, Scoreboard, and Aggregated Coverage Summary

- **SVA Property Assertions (`--assert`):** **`0` SVA errors** across all 68 runs (`sva_soc_fault_rst_if`, `sva_apb3_if`, `sva_mem_if` via `SVA_ENABLE_INTERNAL_BINDS`, `sva_uart_apb_if`, `sva_gpio_apb_if`, `sva_timer_apb_if`).
- **Golden RV32I ISS Scoreboard:** **`0` mismatches** across all 68 runs.
- **Aggregated `tb_cov_collector` Metrics (68 runs):**
  - **RV32I Ops:** `LUI=529`, `AUIPC=16`, `JAL=6`, `JALR=10`, `BR=825`, `LD=578`, `ST=341`, `ALUI=1543`, `ALUR=60`, `FENCE=24`, `X0_DST=424`
  - **Local Memory & Byte Enables:** `IROM_RD=44`, `DRAM_RD=32`, `DRAM_WR=174`, `BE_0001=3`, `BE_0010=3`, `BE_0100=2`, `BE_1000=2`, `BE_0011=2`, `BE_1100=3`, `BE_1111=157`
  - **APB3 Slots & Wait States:** `UART=355`, `GPIO=120`, `TIMER=174`, `WAIT_0=570`, `WAIT_1=7`, `WAIT_2PLUS=72`, `SLVERR=13`
  - **Peripheral Registers:** `UART_CTRL=27`, `UART_STATUS=294`, `UART_TX=10`, `UART_RX=4`, `UART_BAUD=7`, `GPIO_IN=41`, `GPIO_OUT=59`, `GPIO_DIR=6`, `TMR_CTRL=42`, `TMR_STATUS=96`, `TMR_CNT=13`, `TMR_CMP=9`
  - **Reset Recovery:** `DURING_STALL=2`, `FROM_FAULT=1`
  - **Fault-Code Verification Coverage (End-of-Test Checks across 68 runs):** All 10 active fault codes (`4'h1`–`4'hA`) and priority overlaps hit and verified (`4'h1`: 2 runs, `4'h2`: 4 runs, `4'h3`: 6 runs, `4'h4`: 2 runs, `4'h5`: 13 runs, `4'h6`: 7 runs, `4'h7`: 8 runs, `4'h8`: 7 runs, `4'h9`: 15 runs, `4'hA`: 4 runs). *(Note: `tb_cov_collector`'s `always_ff` fault-edge counter reported `0` for single-cycle halt runs only because `tb_soc_top`/`tb_core_bus` break out of the poll loop on the exact cycle `fault_o` rises before an extra post-halt clock edge; `VER-RST-002_from_fault` which stays halted across reset logged `4'h4=1`.)*
