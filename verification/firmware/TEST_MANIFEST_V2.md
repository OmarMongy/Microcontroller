# Verification Firmware & Test Manifest V2 (`SOC_VB_002`)

- **Document ID:** `VER-MANIFEST-002`
- **Baseline ID:** `SOC_VB_002` (extends immutable `VER-MANIFEST-001` in `SOC_VB_001`)
- **Status:** `APPROVED / FROZEN (DEC-VER-BASELINE-002)`
- **Date:** 2026-11-27
- **Approved Decision:** [DEC-VER-BASELINE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-002.md)
- **Author:** Independent Verification Engineer Agent
- **Immutable Core Manifest Preserved:** [TEST_MANIFEST.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TEST_MANIFEST.md) (`SOC_VB_001`)
- **Peripheral Contract Authority:** `CON-PERIPH-001` v1.0 (`DEC-ARCH-PERIPH-001`)

---

## 1. Peripheral Verification Firmware Tests (`SOC_VB_002` Additions)

*(All `VER-CORE-001..004`, `VER-FAULT-001..011`, `VER-RST-001..002`, and `VER-BUS-001` entries in `TEST_MANIFEST.md` remain active and unchanged.)*

| Test ID | Subcase | Source / Target Image | Requirements | Expected `MBOX_STATUS` / `MBOX_TESTID` | Expected `fault_code_o` | Expected `fault_pc_o` | Expected `fault_addr_o` | Expected `fault_insn_o` | Harness / BFM Mode |
|---|---|---|---|---|---|---|---|---|---|
| `VER-UART-001` | — | `VER_UART_001.S` -> `VER_UART_001.mem` | `CON-PERIPH-001 §1, §2` | `0xCAFE_0001` / `0x2001` (`DETAIL=0x007F`) | `4'h5` (`FAULT_EBREAK`) | `sym(ver_uart_001_pass_ebreak)` | `32'h0` | `0x0010_0073` | `TB-SOC-TOP` (`+UART_BAUD_DIV=16`, TX-triggered RX BFM) |
| `VER-UART-002` | `0` | `VER_UART_002.S` (`SUBCASE=0`) | `CON-PERIPH-001 §1.3, §2.2` (Read `WO` `UART_TX_DATA`) | `0xAAAA_0001` / `0x2010` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_0008` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-UART-002` | `1` | `VER_UART_002.S` (`SUBCASE=1`) | `CON-PERIPH-001 §1.3, §2.2` (Write `RO` `UART_RX_DATA`) | `0xAAAA_0001` / `0x2011` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_000C` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-UART-002` | `2` | `VER_UART_002.S` (`SUBCASE=2`) | `CON-PERIPH-001 §2.2` (`UART_BAUD_DIV = 1 < 2`) | `0xAAAA_0001` / `0x2012` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_0010` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-UART-002` | `3` | `VER_UART_002.S` (`SUBCASE=3`) | `CON-PERIPH-001 §2.2` (`UART_BAUD_DIV = 0 < 2`) | `0xAAAA_0001` / `0x2013` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_0010` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-UART-002` | `4` | `VER_UART_002.S` (`SUBCASE=4`) | `CON-PERIPH-001 §1.3, §2.1` (Unimpl offset `0x014`) | `0xAAAA_0001` / `0x2014` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_0014` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-GPIO-001` | — | `VER_GPIO_001.S` -> `VER_GPIO_001.mem` | `CON-PERIPH-001 §1, §3` | `0xCAFE_0001` / `0x2020` (`DETAIL=0x000F`) | `4'h5` (`FAULT_EBREAK`) | `sym(ver_gpio_001_pass_ebreak)` | `32'h0` | `0x0010_0073` | `TB-SOC-TOP` (`+GPIO_MODE=ECHO_INV`) |
| `VER-GPIO-002` | `0` | `VER_GPIO_002.S` (`SUBCASE=0`) | `CON-PERIPH-001 §1.3, §3.2` (Write `RO` `GPIO_DATA_IN`) | `0xAAAA_0001` / `0x2030` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_1000` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-GPIO-002` | `1` | `VER_GPIO_002.S` (`SUBCASE=1`) | `CON-PERIPH-001 §1.3, §3.1` (Read unimpl `0x00C`) | `0xAAAA_0001` / `0x2031` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_100C` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-GPIO-002` | `2` | `VER_GPIO_002.S` (`SUBCASE=2`) | `CON-PERIPH-001 §1.3, §3.1` (Write unimpl `0xFFC`) | `0xAAAA_0001` / `0x2032` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_1FFC` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-TIMER-001` | — | `VER_TIMER_001.S` -> `VER_TIMER_001.mem` | `CON-PERIPH-001 §1, §4` | `0xCAFE_0001` / `0x2040` (`DETAIL=0x003F`) | `4'h5` (`FAULT_EBREAK`) | `sym(ver_timer_001_pass_ebreak)` | `32'h0` | `0x0010_0073` | `TB-SOC-TOP` |
| `VER-TIMER-002` | `0` | `VER_TIMER_002.S` (`SUBCASE=0`) | `CON-PERIPH-001 §1.3, §4.1` (Read unimpl `0x010`) | `0xAAAA_0001` / `0x2050` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_2010` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-TIMER-002` | `1` | `VER_TIMER_002.S` (`SUBCASE=1`) | `CON-PERIPH-001 §1.3, §4.1` (Write unimpl `0xFFC`) | `0xAAAA_0001` / `0x2051` (`SENTINEL=0`) | `4'h9` (`FAULT_APB_SLVERR`) | `sym(fault_trigger_pc)` | `0x4000_2FFC` | `insn @ fault_trigger_pc` | `TB-SOC-TOP` |
| `VER-PERIPH-INT-001` | — | `crt0_periph.S` + `VER_PERIPH_INT_001.c` -> `VER_PERIPH_INT_001.mem` | `CON-PERIPH-001` (UART+GPIO+Timer), `SPEC H2` | `0xCAFE_0001` / `0x2060` (`DETAIL=0x0000`) | `4'h5` (`FAULT_EBREAK`) | `sym(ver_periph_int_001_done_ebreak)` | `32'h0` | `0x0010_0073` | `TB-SOC-TOP` (`+UART_BAUD_DIV=16 +GPIO_MODE=ECHO_INV`) |
