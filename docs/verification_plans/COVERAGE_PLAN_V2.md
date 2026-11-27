# Functional Coverage Plan V2 — RV32I Microcontroller SoC (`SOC_VB_002`)

- **Document ID:** `COV-PLAN-002`
- **Baseline ID:** `SOC_VB_002` (extends immutable `COV-PLAN-001` in `SOC_VB_001`)
- **Version:** `V2.0`
- **Status:** `APPROVED / FROZEN (DEC-VER-BASELINE-002)`
- **Date:** 2026-11-27
- **Approved Decision:** [DEC-VER-BASELINE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-002.md)
- **Author:** Independent Verification Engineer Agent
- **Companion Documents:** [VERIFICATION_PLAN_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V2.md), [SVA_SPECIFICATION_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V2.md)

---

## 1. Coverage Inheritance & Collection

- All core covergroups defined in [COVERAGE_PLAN_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/COVERAGE_PLAN_V1.md) (`CG-RV32I-OPS`, `CG-RV32I-HAZARD`, `CG-ADDR-REGIONS`, `CG-IROM-PORTB`, `CG-DRAM-ACCESS`, `CG-APB3-PROTO`, `CG-FAULT-CODES`, `CG-FAULT-PRIO`, `CG-RESET`) remain required at **100% hit rate**.
- `SOC_VB_002` unblocks and defines the peripheral register-level covergroups below, implemented in `tb/tb_cov_collector.sv` and `sva/sva_periph_if.sv` (`COV-SVA-011..019`).

---

## 2. Peripheral Functional Covergroups (`CON-PERIPH-001` v1.0)

### 2.1 `CG-UART-REG` — `uart_apb` (`0x4000_0000`)
- **Required Bins:**
  - `b_uart_rst`: Reset values read immediately after reset (`UART_CTRL=3`, `UART_STATUS=2`, `UART_BAUD_DIV=434`).
  - `b_uart_reg_rw`: Read & write of `UART_CTRL`, `UART_STATUS`, `UART_BAUD_DIV`; write `UART_TX_DATA`; read `UART_RX_DATA`.
  - `b_uart_baud_prog`: `UART_BAUD_DIV` programmed to valid values (`2`, `4`, `16`, `434`); invalid writes (`0`, `1`) raising `PSLVERR` without corrupting `BAUD_DIV`.
  - `b_uart_tx_data`: TX bytes `{0x00, 0xFF, 0x55, 0xAA}` transmitted 8N1; `TX_BUSY == 1` observed; write-while-`TX_BUSY` ignored without `PSLVERR`.
  - `b_uart_tx_disable`: `TX_EN = 0` holds `uart_tx_o = 1` and ignores writes.
  - `b_uart_rx_data`: RX bytes `{0x00, 0xFF, 0xA3}` received; `RX_VALID` observed `1` then cleared on `UART_RX_DATA` read.
  - `b_uart_rx_overrun`: Second valid RX byte completes while `RX_VALID == 1` -> `RX_OVERRUN` set, old byte preserved, cleared via `W1C`.
  - `b_uart_rx_ferr`: Stop bit `0` frame -> `RX_FRAME_ERR` set, frame discarded, cleared via `W1C`.
  - `b_uart_pslverr`: Read `UART_TX_DATA` (`WO`), write `UART_RX_DATA` (`RO`), `BAUD_DIV < 2`, unimplemented offset (`0x014`, `0xFFC`).
  - `b_uart_rsvd`: Write non-zero to reserved bits -> read back `0`, no `PSLVERR`.
- **Primary Stimulus:** `VER-UART-001`, `VER-UART-002`.

### 2.2 `CG-GPIO-REG` — `gpio_apb` (`0x4000_1000`)
- **Required Bins:**
  - `b_gpio_rst`: Reset values (`GPIO_DATA_IN=0`, `GPIO_DATA_OUT=0`, `GPIO_DIR=0`, `gpio_oe_o=0`, `gpio_o=0`).
  - `b_gpio_dir_masks`: `GPIO_DIR` patterns `{8'h00, 8'hFF, 8'h0F, 8'hF0}` reflected on `gpio_oe_o`.
  - `b_gpio_out_walk`: Walking-1 (`8'h01..8'h80`) and walking-0 (`8'hFE..8'h7F`) plus `8'h55`/`8'hAA` on `GPIO_DATA_OUT` -> `gpio_o`.
  - `b_gpio_in_sync`: `gpio_i` driven `{8'h00, 8'hFF, 8'hA5, 8'h5A}` and sampled accurately in `GPIO_DATA_IN` after 2-FF sync delay.
  - `b_gpio_pslverr`: Write `GPIO_DATA_IN` (`RO`), read `0x00C`, write `0xFFC`.
  - `b_gpio_rsvd`: Write upper `[31:8]` reserved bits -> read back `0`, no `PSLVERR`.
- **Primary Stimulus:** `VER-GPIO-001`, `VER-GPIO-002`.

### 2.3 `CG-TIMER-REG` — `timer_apb` (`0x4000_2000`)
- **Required Bins:**
  - `b_tmr_rst`: Reset values (`CTRL=0`, `STATUS=0`, `COUNTER=0`, `COMPARE=0xFFFF_FFFF`).
  - `b_tmr_pause`: `EN=0` holds `TIMER_COUNTER` constant across multiple APB reads.
  - `b_tmr_freerun_match`: `EN=1, AUTO_RELOAD=0` matches `TIMER_COMPARE`, continues counting past `COMPARE`, sets sticky `MATCH`, cleared via `W1C`.
  - `b_tmr_autoreload`: `EN=1, AUTO_RELOAD=1` resets `TIMER_COUNTER` to `0` on `COMPARE` (`COMPARE + 1` period) and sets `MATCH`.
  - `b_tmr_clr_cnt`: `CLR_CNT=1` resets `TIMER_COUNTER` to `0` and always reads `0` in `TIMER_CTRL[2]`.
  - `b_tmr_cnt_write`: Direct write to `TIMER_COUNTER` (both while `EN=0` and `EN=1`) sets exact value without `+1` or spurious match.
  - `b_tmr_wrap_ovf`: Preload `TIMER_COUNTER` near `0xFFFF_FFF0` with `EN=1, AUTO_RELOAD=0` -> wraps `0xFFFF_FFFF -> 0`, sets sticky `OVF`, cleared via `W1C`.
  - `b_tmr_pslverr`: Read `0x010`, write `0xFFC`.
  - `b_tmr_rsvd`: Write reserved bits -> read back `0`, no `PSLVERR`.
- **Primary Stimulus:** `VER-TIMER-001`, `VER-TIMER-002`.

### 2.4 `CG-PERIPH-INT` — Combined Multi-Peripheral Interaction
- **Required Bins:**
  - `b_int_timer_gpio_uart`: Single bare-metal C execution (`VER-PERIPH-INT-001`) using `timer_apb` polling delay to pace `gpio_apb` output/input loopback and `uart_apb` TX/RX polling, passing `DRAM` mailbox verification.

---

## 3. `SOC_VB_002` Coverage Closure Target

- **100%** of `SOC_VB_001` core bins + **100%** of `SOC_VB_002` peripheral bins (`CG-UART-REG`, `CG-GPIO-REG`, `CG-TIMER-REG`, `CG-PERIPH-INT`) + **100%** of `COV-SVA-001..019` prior to Gate 5/Gate 8 sign-off.
