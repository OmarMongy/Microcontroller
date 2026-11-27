# Master Verification Plan V2 — RV32I Microcontroller SoC (`SOC_VB_002`)

- **Document ID:** `VER-PLAN-002`
- **Baseline ID:** `SOC_VB_002` (extends immutable frozen baseline `SOC_VB_001`)
- **Version:** `V2.0`
- **Status:** `APPROVED / FROZEN (DEC-VER-BASELINE-002)`
- **Date:** 2026-11-27
- **Approved Decision:** [DEC-VER-BASELINE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-002.md)
- **Author:** Independent Verification Engineer Agent
- **Immutable Core Baseline Preserved:** [VERIFICATION_PLAN_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V1.md) (`SOC_VB_001`, approved in [DEC-VER-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-001.md))
- **Newly Approved Contract Integrated:** [PERIPHERAL_REGISTER_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/PERIPHERAL_REGISTER_MAP_CONTRACT.md) (`CON-PERIPH-001` v1.0, approved in [DEC-ARCH-PERIPH-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-PERIPH-001.md))
- **All Frozen Contracts Referenced:** `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1 (+ `ARM IHI 0024E` APB3 / Issue B), `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1, `CON-PERIPH-001` v1.0.
- **Companion V2 Documents:**
  - [SVA_SPECIFICATION_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V2.md)
  - [COVERAGE_PLAN_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/COVERAGE_PLAN_V2.md)
  - [TEST_MANIFEST_V2.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TEST_MANIFEST_V2.md)

> **Baseline Immutability & Independence Notice:**
> `SOC_VB_001` (`*_V1.md`, `TEST_MANIFEST.md`, `TOOLCHAIN_AND_BUILD.md`, `VER_CORE_001..004`, `VER_FAULT_001..011`) remains **strictly immutable**. `SOC_VB_002` adds peripheral register-level verification, Gate 4 testbench harnesses (`tb/`), and SVA bind modules (`sva/`) derived solely from the six frozen interface contracts and `ARM IHI 0024E` without inspecting implementation RTL.

---

## 1. Scope Expansion in `SOC_VB_002`

`SOC_VB_002` retains 100% of `SOC_VB_001` core verification (`VER-CORE-001..004`, `VER-FAULT-001..011`, `VER-RST-001..002`, `VER-BUS-001`) and unblocks all peripheral register-level verification items previously blocked in `SOC_VB_001`:

1. **`uart_apb` (`0x4000_0000`–`0x4000_0FFF`, `CON-PERIPH-001` §2):**
   - Reset defaults (`UART_CTRL=32'h0000_0003`, `UART_STATUS=32'h0000_0002`, `UART_BAUD_DIV=32'h0000_01B2`, `uart_tx_o=1`).
   - Programmable `UART_BAUD_DIV` (`>= 2`; writes `< 2` raise `PSLVERR=1` and preserve prior divider).
   - 8N1 TX transmission (`TX_BUSY` / `TX_EMPTY` polling, LSB-first framing, write-while-`TX_BUSY` ignored without `PSLVERR`, `TX_EN=0` holds `uart_tx_o=1` and ignores TX writes).
   - 8N1 RX reception with 2-FF synchronizer and `BAUD_DIV >> 1` start-bit center check (`RX_VALID` set on valid stop bit, cleared on `UART_RX_DATA` read, `RX_EN=0` disables start detection).
   - Sticky `RX_OVERRUN` (`W1C`, preserves existing unread `UART_RX_DATA`) and `RX_FRAME_ERR` (`W1C`, discards invalid stop-bit frame).
   - `PSLVERR` on reading `UART_TX_DATA` (`WO`), writing `UART_RX_DATA` (`RO`), `UART_BAUD_DIV < 2`, and unimplemented offsets `0x014`–`0xFFC`; reserved bits read `0` and ignore writes.
2. **`gpio_apb` (`0x4000_1000`–`0x4000_1FFF`, `CON-PERIPH-001` §3):**
   - Reset defaults (`GPIO_DATA_IN=0`, `GPIO_DATA_OUT=0`, `GPIO_DIR=0`, `gpio_o=8'h00`, `gpio_oe_o=8'h00`).
   - Per-bit `GPIO_DIR` -> `gpio_oe_o` and `GPIO_DATA_OUT` -> `gpio_o` updates on APB3 completion edge.
   - 2-FF `gpio_i` input synchronization reflected in `GPIO_DATA_IN` after 2–3 `PCLK` edges.
   - `PSLVERR` on writing `GPIO_DATA_IN` (`RO`) and accessing unimplemented offsets `0x00C`–`0xFFC`; reserved bits `[31:8]` read `0` and ignore writes.
3. **`timer_apb` (`0x4000_2000`–`0x4000_2FFF`, `CON-PERIPH-001` §4):**
   - Reset defaults (`TIMER_CTRL=0`, `TIMER_STATUS=0`, `TIMER_COUNTER=0`, `TIMER_COMPARE=32'hFFFF_FFFF`).
   - `EN=0` pause vs `EN=1` free-running increment; `AUTO_RELOAD=1` periodic reload to `0` (`period = COMPARE + 1` cycles).
   - `CLR_CNT` (`WO/SC`) clearing `TIMER_COUNTER` and always reading `0`.
   - Direct `TIMER_COUNTER` write precedence (no simultaneous `+1`, suppresses match/overflow on that edge).
   - Sticky `MATCH` and `OVF` flags (`W1C`, `0xFFFF_FFFF` wrap, hardware event precedence over concurrent `W1C`).
   - `PSLVERR` on unimplemented offsets `0x010`–`0xFFC`; reserved bits read `0` and ignore writes.
4. **Integrated Multi-Peripheral Interaction (`VER-PERIPH-INT-001`):**
   - Bare-metal C stimulus combining `timer_apb` polling delay, `gpio_apb` output/input loopback, and `uart_apb` TX/RX polling in one program using the `DRAM` verification mailbox (`0x2000_7F00`–`0x2000_7FFF`).
5. **Gate 4 Verification Infrastructure (`tb/` & `sva/`):**
   - Shared testbench package (`tb/tb_pkg.sv`), programmable `mock_apb_completer` (`tb/mock_apb_completer.sv`), Golden RV32I + Modified Harvard reference model & scoreboard (`tb/rv32i_golden_iss.sv`), functional coverage collector (`tb/tb_cov_collector.sv`), subsystem harness (`tb/tb_core_bus.sv`), full-SoC harness with UART 8N1 + GPIO BFMs (`tb/tb_soc_top.sv`), and SVA checkers + `bind` module (`sva/*.sv`).

---

## 2. Updated Requirement-to-Test Traceability Matrix (Peripheral Extension)

*(Core matrix in `VERIFICATION_PLAN_V1.md` §3.1 remains unchanged and active.)*

| Req / Contract ID | Requirement Summary | Verification Method | Test ID(s) | SVA ID(s) | Coverage ID(s) | Status |
|---|---|---|---|---|---|---|
| `CON-PERIPH-001 §1` | Common peripheral rules: `PREADY=1`, `PSLVERR` on unimplemented/RO/WO/`BAUD_DIV<2`, reserved bits read `0` & ignore writes | Firmware + `TB-SOC-TOP` + SVA | `VER-UART-001/002`, `VER-GPIO-001/002`, `VER-TIMER-001/002` | `SVA-UART-007/008`, `SVA-GPIO-004/005`, `SVA-TIMER-007/008` | `CG-UART-REG`, `CG-GPIO-REG`, `CG-TIMER-REG` | `READY` |
| `CON-PERIPH-001 §2` (`SPEC D1, D2`) | `uart_apb` registers, 8N1 TX/RX, `BAUD_DIV` (`434` reset, `>=2`), `TX_BUSY`/`TX_EMPTY`, `RX_VALID` read-clear, `RX_OVERRUN`/`RX_FRAME_ERR` `W1C`, `RX_EN`/`TX_EN` | Firmware + UART 8N1 BFM + SVA | `VER-UART-001`, `VER-UART-002` | `SVA-UART-001..008` | `CG-UART-REG` | `READY` |
| `CON-PERIPH-001 §3` (`SPEC E1, E2`) | `gpio_apb` registers, `gpio_oe_o` / `gpio_o` outputs, 2-FF `gpio_i` synchronizer | Firmware + GPIO BFM + SVA | `VER-GPIO-001`, `VER-GPIO-002` | `SVA-GPIO-001..005` | `CG-GPIO-REG` | `READY` |
| `CON-PERIPH-001 §4` (`SPEC F1`) | `timer_apb` registers, `EN`, `AUTO_RELOAD` (`COMPARE+1`), `CLR_CNT` `WO/SC`, `COUNTER` write precedence, `MATCH`/`OVF` sticky `W1C`, wrap | Firmware + `TB-SOC-TOP` + SVA | `VER-TIMER-001`, `VER-TIMER-002` | `SVA-TIMER-001..008` | `CG-TIMER-REG` | `READY` |
| `SPEC H2` | Combined Timer + GPIO + UART bare-metal C integration test | Bare-metal C + `TB-SOC-TOP` + SVA | `VER-PERIPH-INT-001` | All `SVA-*` | `CG-PERIPH-INT` | `READY` |

---

## 3. Peripheral Testbench BFM Coordination (`tb_soc_top`)

To keep verification deterministic and self-checking without altering `SOC_VB_001` behavior:
1. **Test-Select Parameter / Plusarg (`+TEST_ID=...`):** `tb_soc_top` selects the matching BFM behavior per test ID:
   - **UART BFM (`uart_rx_i` & `uart_tx_o`):**
     - Passively decodes all 8N1 bytes transmitted on `uart_tx_o` at the configured `BAUD_DIV` (default `434`, or fast sim `BAUD_DIV = 4` / `16` during `VER-UART-001` / `VER-PERIPH-INT-001` — detected cleanly by a testbench-configured baud parameter `+UART_BAUD_DIV=N` matching the firmware's programmed `UART_BAUD_DIV`!).
     - For `VER-UART-001`: Upon observing a trigger byte on `uart_tx_o` (e.g., `0x55` -> BFM sends RX byte `0xA3`; `0x56` -> BFM sends two back-to-back bytes `0x3C`, `0x7E` while firmware delays reading to test `RX_OVERRUN`; `0x57` -> BFM sends a corrupted stop-bit `0` frame to test `RX_FRAME_ERR`), the BFM drives `uart_rx_i` deterministically. Using TX-triggered handshakes eliminates fragile cycle-count guessing!
   - **GPIO BFM (`gpio_i` & `gpio_o`/`gpio_oe_o`):**
     - Supports loopback mode (`gpio_i = gpio_o` on output-enabled bits, driven patterns on input bits) and directed `VER-GPIO-001` handshake (reflecting `~gpio_o[3:0]` onto `gpio_i[7:4]` or driving known stimuli `8'hA5`, `8'h5A` so firmware verifies 2-FF `GPIO_DATA_IN` sampling).

---

## 4. Gate 5 Prerequisite & Approval Gate for `SOC_VB_002`

- **Gate 5 Prerequisite:** Install a bare-metal RV32I GNU toolchain (`gcc-riscv64-unknown-elf` + `binutils-riscv64-unknown-elf` or `riscv32-unknown-elf-gcc`) to compile `verification/firmware/` `.mem` images prior to running Gate 5 simulation.
- **Human Approval Required:** Approve `VERIFICATION_PLAN_V2.md`, `SVA_SPECIFICATION_V2.md`, `COVERAGE_PLAN_V2.md`, and `TEST_MANIFEST_V2.md` (+ new peripheral firmware sources) to freeze **`SOC_VB_002`**.
