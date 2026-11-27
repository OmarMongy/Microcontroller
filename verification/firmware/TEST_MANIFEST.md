# Verification Firmware & Test Manifest (`SOC_VB_001`)

- **Document ID:** `VER-MANIFEST-001`
- **Baseline ID:** `SOC_VB_001`
- **Status:** `APPROVED / FROZEN (DEC-VER-BASELINE-001)`
- **Date:** 2026-11-27
- **Approved Decision:** [DEC-VER-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-001.md)
- **Author:** Independent Verification Engineer Agent
- **Contract Authority:** `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1, `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1

---

## 1. Signature Mailbox & Completion Protocol (`DRAM 0x2000_7F00..0x2000_7F1F`)

| Address | Symbol | Purpose |
|---|---|---|
| `0x2000_7F00` | `MBOX_STATUS_ADDR` | `0xCAFE_0001` (`STATUS_PASS`), `0xDEAD_xxxx` (`STATUS_FAIL_BASE \| step`), `0xAAAA_0001` (`STATUS_PRE_FAULT`) |
| `0x2000_7F04` | `MBOX_TESTID_ADDR` | Unique numeric test/subcase identifier |
| `0x2000_7F08` | `MBOX_DETAIL_ADDR` | Subcheck bitmask / detail word (`0x0` expected on fault tests) |
| `0x2000_7F0C` | `MBOX_SENTINEL_ADDR` | Must remain `0x0000_0000` (if `0xBAD0_BAD0` appears, CPU failed to halt on fault!) |

---

## 2. Core & Fault Firmware Tests (`verification/firmware/src/`)

| Test ID | Subcase | Source / Target Image | Requirements | Expected `MBOX_STATUS` / `MBOX_TESTID` | Expected `fault_code_o` | Expected `fault_pc_o` | Expected `fault_addr_o` | Expected `fault_insn_o` | Harness |
|---|---|---|---|---|---|---|---|---|---|
| `VER-CORE-001` | — | `VER_CORE_001.S` -> `VER_CORE_001.mem` | `SPEC A1`, `DEC-ARCH-CORE-002 #3`, `CON-FLT-RST-001` | `0xCAFE_0001` / `0x0001` (`DETAIL=0x01FF`) | `4'h5` (`FAULT_EBREAK`) | `sym(ver_core_001_pass_ebreak)` | `32'h0` | `0x0010_0073` | `TB-SOC-TOP` / `TB-CORE-BUS` |
| `VER-CORE-002` | — | `VER_CORE_002.S` -> `VER_CORE_002.mem` | `CON-ADDR-001 §2`, `CON-MEM-001 §1, §2` | `0xCAFE_0001` / `0x0002` (`DETAIL=0x00FF`) | `4'h5` (`FAULT_EBREAK`) | `sym(ver_core_002_pass_ebreak)` | `32'h0` | `0x0010_0073` | `TB-SOC-TOP` / `TB-CORE-BUS` |
| `VER-CORE-003` | — | `VER_CORE_003.S` -> `VER_CORE_003.mem` | `CON-ADDR-001 §3`, `CON-APB3-001 §3–§5`, `DEC-CPU-APB-WAIT-001` | `0xCAFE_0001` / `0x0003` (`DETAIL=0x001F`) | `4'h5` (`FAULT_EBREAK`) | `sym(ver_core_003_pass_ebreak)` | `32'h0` | `0x0010_0073` | `TB-CORE-BUS` (Mock APB3, 0/1/2/5 waits) |
| `VER-CORE-004` | — | `crt0.S` + `VER_CORE_004.c` -> `VER_CORE_004.mem` | `SPEC H1`, `DEC-ARCH-CORE-001`, `CON-MEM-001`, `CON-APB3-001` | `0xCAFE_0001` / `0x0004` (`DETAIL=0x0000`) | `4'h5` (`FAULT_EBREAK`) | `sym(ver_core_004_done_ebreak)` | `32'h0` | `0x0010_0073` | `TB-CORE-BUS` (Mock APB3) |
| `VER-FAULT-001` | `0` | `VER_FAULT_001.S` (`SUBCASE=0`) | `CON-ADDR-001 §4.1`, `CON-FLT-RST-001` | `0xAAAA_0001` / `0x1010` (`SENTINEL=0`) | `4'h2` (`FAULT_IF_UNMAPPED`) | `0x0000_8000` | `0x0000_8000` | `32'h0` | `TB-SOC-TOP` |
| `VER-FAULT-001` | `1` | `VER_FAULT_001.S` (`SUBCASE=1`) | `CON-ADDR-001 §4.1`, `CON-FLT-RST-001` | `0xAAAA_0001` / `0x1011` (`SENTINEL=0`) | `4'h2` (`FAULT_IF_UNMAPPED`) | `0x2000_0000` | `0x2000_0000` | `32'h0` | `TB-SOC-TOP` |
| `VER-FAULT-001` | `2` | `VER_FAULT_001.S` (`SUBCASE=2`) | `CON-ADDR-001 §4.1`, `CON-FLT-RST-001` | `0xAAAA_0001` / `0x1012` (`SENTINEL=0`) | `4'h2` (`FAULT_IF_UNMAPPED`) | `0x4000_0000` | `0x4000_0000` | `32'h0` | `TB-SOC-TOP` |
| `VER-FAULT-002` | `0..1` | `VER_FAULT_002.S` (`SUBCASE=0..1`) | `CON-ADDR-001 §4.1`, `CON-FLT-RST-001` | `0xAAAA_0001` / `0x1020..1021` | `4'h1` (`FAULT_IF_MISALIGNED`) | `0x0000_0202` | `0x0000_0202` | `32'h0` | `TB-SOC-TOP` |
| `VER-FAULT-003` | `0..5` | `VER_FAULT_003.S` (`SUBCASE=0..5`) | `SPEC A2`, `CON-FLT-RST-001 §1.1` | `0xAAAA_0001` / `0x1030..1035` | `4'h3` (`FAULT_ILLEGAL_INSN`) | `sym(fault_trigger_pc)` | `32'h0` | `{0x0, 0xFFFF_FFFF, 0x3000_9073, 0x3020_0073, 0x0231_00B3, 0x0000_100F}` | `TB-SOC-TOP` |
| `VER-FAULT-004` | `0` | `VER_FAULT_004.S` | `CON-FLT-RST-001 §1.1` | `0xAAAA_0001` / `0x1040` | `4'h4` (`FAULT_ECALL`) | `sym(fault_trigger_pc)` | `32'h0` | `0x0000_0073` | `TB-SOC-TOP` |
| `VER-FAULT-005` | `0` | `VER_FAULT_005.S` | `CON-FLT-RST-001 §1.1` | `0xAAAA_0001` / `0x1050` | `4'h5` (`FAULT_EBREAK`) | `sym(fault_trigger_pc)` | `32'h0` | `0x0010_0073` | `TB-SOC-TOP` |
| `VER-FAULT-006` | `0..5` | `VER_FAULT_006.S` (`SUBCASE=0..5`) | `CON-ADDR-001 §2, §3, §4.2` | `0xAAAA_0001` / `0x1060..1065` | `4'h7` (`FAULT_DATA_UNMAPPED`) | `sym(fault_trigger_pc)` | `{0x0000_8000, 0x1FFF_FFFC, 0x2000_8000, 0x4000_3000, 0x4000_FFFC, 0x4001_0000}` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-FAULT-007` | `0..2` | `VER_FAULT_007.S` (`SUBCASE=0..2`) | `DEC-ARCH-CORE-002 #2`, `CON-FLT-RST-001` | `0xAAAA_0001` / `0x1070..1072` | `4'hA` (`FAULT_DATA_RO_WRITE`) | `sym(fault_trigger_pc)` | `{0x0000_0000, 0x0000_0200, 0x0000_7FFF}` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-FAULT-008` | `0..5` | `VER_FAULT_008.S` (`SUBCASE=0..5`) | `CON-APB3-001 §2` (`Option APB-W1`) | `0xAAAA_0001` / `0x1080..1085` | `4'h8` (`FAULT_DATA_SIZE_UNSUP`) | `sym(fault_trigger_pc)` | `{0x4000_0000, 0x4000_1000, 0x4000_2000, 0x4000_0004, 0x4000_1004, 0x4000_2004}` | `insn @ fault_trigger_pc` | `TB-CORE-BUS` / `TB-SOC-TOP` |
| `VER-FAULT-009` | `0..6` | `VER_FAULT_009.S` (`SUBCASE=0..6`) | `CON-MEM-001 §2.5`, `CON-APB3-001 §2` | `0xAAAA_0001` / `0x1090..1096` | `4'h6` (`FAULT_DATA_MISALIGNED`) | `sym(fault_trigger_pc)` | `{0x0000_0201, 0x0000_0202, 0x2000_0003, 0x2000_0001, 0x2000_0001, 0x2000_0003, 0x4000_0002}` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-FAULT-010` | `0..1` | `VER_FAULT_010.S` (`SUBCASE=0..1`) | `CON-APB3-001 §5.2.4`, `CON-FLT-RST-001` | `0xAAAA_0001` / `0x10A0..10A1` (`DETAIL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `{0x4000_0000, 0x4000_1000}` | `insn @ fault_trigger_pc` | `TB-CORE-BUS` (Mock `PSLVERR=1`) |
| `VER-FAULT-011` | `0` | `VER_FAULT_011.S` (`SUBCASE=0`) | `CON-FLT-RST-001 §1.2` (P1 > P2) | `0xAAAA_0001` / `0x10B0` | `4'h2` (`FAULT_IF_UNMAPPED`) | `0x0000_8002` | `0x0000_8002` | `32'h0` | `TB-SOC-TOP` |
| `VER-FAULT-011` | `1` | `VER_FAULT_011.S` (`SUBCASE=1`) | `CON-FLT-RST-001 §1.2` (P4 > P7) | `0xAAAA_0001` / `0x10B1` | `4'h7` (`FAULT_DATA_UNMAPPED`) | `sym(fault_trigger_pc)` | `0x0000_8001` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-FAULT-011` | `2` | `VER_FAULT_011.S` (`SUBCASE=2`) | `CON-FLT-RST-001 §1.2` (P4 > P6 > P7) | `0xAAAA_0001` / `0x10B2` | `4'h7` (`FAULT_DATA_UNMAPPED`) | `sym(fault_trigger_pc)` | `0x4000_3001` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-FAULT-011` | `3` | `VER_FAULT_011.S` (`SUBCASE=3`) | `CON-FLT-RST-001 §1.2` (P5 > P7) | `0xAAAA_0001` / `0x10B3` | `4'hA` (`FAULT_DATA_RO_WRITE`) | `sym(fault_trigger_pc)` | `0x0000_0102` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-FAULT-011` | `4` | `VER_FAULT_011.S` (`SUBCASE=4`) | `CON-FLT-RST-001 §1.2` (P6 > P7) | `0xAAAA_0001` / `0x10B4` | `4'h8` (`FAULT_DATA_SIZE_UNSUP`) | `sym(fault_trigger_pc)` | `0x4000_0001` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |

---

## 3. Testbench-Driven Core Tests (No Dedicated Firmware Beyond Core Images)

| Test ID | Stimulus Image | Purpose | Expected Outcome | Harness |
|---|---|---|---|---|
| `VER-RST-001` | `VER_CORE_001.mem` | Async `rst_n` pulse, 2-FF `rst_sync` release, reset values across all subsystems & `soc_top` pins | `SVA-RST-001..005` pass; `VER-CORE-001` passes after release | `TB-SOC-TOP` |
| `VER-RST-002` | `VER_CORE_003.mem` / `VER_FAULT_004.mem` | Reset during `ACCESS && !PREADY`, during `local_rd_valid`, and after `fault_o == 1` | Clean recovery to `PC=0`, `IDLE`, `fault_o=0`; `SVA-RST-006` pass | `TB-CORE-BUS` / `TB-SOC-TOP` |
| `VER-BUS-001` | `VER_CORE_003.mem` | APB3 wait-state sweep (`0, 1, 2, 5, 16` cycles) + `PSLVERR=1` glitch while `PREADY=0` | `VER-CORE-003` passes with zero spurious faults or duplicate transfers | `TB-CORE-BUS` |

---

## 4. `BLOCKED` Peripheral Functional Firmware Tests

| Test ID | Target Peripheral | Status | Blocking Dependency |
|---|---|---|---|
| `VER-UART-001..N` | `uart_apb` (`0x4000_0000`) | `BLOCKED` | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `VER-GPIO-001..N` | `gpio_apb` (`0x4000_1000`) | `BLOCKED` | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `VER-TIMER-001..N` | `timer_apb` (`0x4000_2000`) | `BLOCKED` | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `VER-PERIPH-INT-001` | Combined peripherals | `BLOCKED` | `BLOCKED (awaiting approved peripheral register-map contract)` |
