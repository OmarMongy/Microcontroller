# Regression Run Report — `RUN-GATE5-001`

- **Run ID:** `RUN-GATE5-001`
- **Date/time:** `2026-11-27T18:02:28+02:00`
- **Author:** Independent Verification Engineer Agent
- **Status:** `FAIL` (**67 / 68 passed**, **1 failed: `VER-GPIO-001`**, **0 SVA property errors**; failure diagnosed as TB GPIO BFM stimulus defect in [INV-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/investigations/INV-GATE5-001.md))
- **Specification revision:** `SOC_SPECIFICATION_DRAFT.md` (Draft 0.3)
- **Interface contracts:** `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1 (`IHI0024E` Issue B), `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1, `CON-PERIPH-001` v1.0
- **Verification baselines:** `SOC_VB_001.1` (`DEC-VER-BASELINE-003` — `APPROVED`) & `SOC_VB_002` (`PROPOSED`)
- **RTL branch/commit:** `dev/gate2-4-rtl-and-verif` (branched from `main` checkpoint `85dcd83`)

---

## 1. Tools & Commands Executed
- **RISC-V Toolchain:** `riscv64-unknown-elf-gcc (14.2.0+19) 14.2.0`, `GNU assembler 2.45.50`
  - Build command: `make -C verification/firmware clean all-v2` -> **60 / 60** `.mem` images built (`exit 0`)
  - Integrity check: `(cd verification/firmware && sha256sum -c build/*.sha256)` -> **180 / 180** files `OK` (`exit 0`)
- **RTL Simulator:** `Verilator 5.032 2025-01-01 rev (Debian 5.032-1)` (`--binary --assert --timing --public-flat-rw`, `-DSVA_ENABLE_INTERNAL_BINDS` on `tb_soc_top`)
  - Regression command: `python3 tb/run_gate5.py` -> **67 passed, 1 failed (`VER-GPIO-001`), 0 SVA property errors**
  - Full run log: [RUN-GATE5-001.log](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-001.log)

---

## 2. Per-Test Results Summary

| Group | Test ID(s) | Harness | Result | Notes |
|---|---|---|---|---|
| RV32I Base ISA & `FENCE` | `VER-CORE-001` | `TB-SOC-TOP` | `PASS` (163 retires) | All 40 RV32I ops, `x0`, branches, `JAL/JALR`, `FENCE` |
| Modified Harvard `IROM` Port B + `DRAM` `RAM-B` | `VER-CORE-002` | `TB-SOC-TOP` | `PASS` (154 retires) | 2-cycle `.rodata` & `DRAM` loads, byte/halfword `SB/SH/SW` |
| APB3 Wait-State Sweep (`0,1,2,5,16`) & Glitch | `VER-CORE-003` (4 runs), `VER-BUS-001` | `TB-CORE-BUS` | `PASS` (5/5, 77 retires each) | Mock APB3 Completers, `PSLVERR` ignored when `PREADY=0` |
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
| UART Functional & `PSLVERR` | `VER-UART-001`, `VER-UART-002_sub0..4` | `TB-SOC-TOP` | `PASS` (6/6) | 887 retires on `VER-UART-001` (TX/RX/Overrun/FrameErr) |
| GPIO Functional | `VER-GPIO-001` | `TB-SOC-TOP` | **`FAIL` (1/1)** | Step 1 failed (`MBOX_STATUS=0xDEAD_0001`); see `INV-GATE5-001.md` |
| GPIO `PSLVERR` | `VER-GPIO-002_sub0..2` | `TB-SOC-TOP` | `PASS` (3/3) | `RO` write & unimplemented offsets |
| Timer Functional & `PSLVERR` | `VER-TIMER-001`, `VER-TIMER-002_sub0..1` | `TB-SOC-TOP` | `PASS` (3/3) | 275 retires on `VER-TIMER-001` (`MATCH`, `AUTO_RELOAD`, `CLR_CNT`, `OVF`) |
| Combined Peripheral Integration (C) | `VER-PERIPH-INT-001` | `TB-SOC-TOP` | `PASS` (669 retires) | Timer + GPIO + UART bare-metal C integration |

---

## 3. SVA & Scoreboard Summary
- **SVA Property Assertions (`--assert`):** `0` SVA property failures across all 68 simulations (note: `run_gate5.py` reported `SVA_ASSERT_ERRORS=1` due to regex matching Verilator's `$fatal` message `"Assertion failed in tb_soc_top"` on `VER-GPIO-001`; zero `sva_*` protocol/internal assertions failed).
- **Golden RV32I ISS Scoreboard:** `0` mismatches across all 67 passing runs (all instructions retired matched `PC`, `DRAM`, `APB3`, and `fault_*` outputs 100%).

## 4. Failure Investigation Pointer
- [INV-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/investigations/INV-GATE5-001.md) — `VER-GPIO-001` (`VERIFICATION_DEFECT_SUSPECTED`: confirmed TB GPIO BFM stimulus defect in `tb/tb_soc_top.sv` driving `8'hF0` before `gpio_oe_o == 8'h0F`).
