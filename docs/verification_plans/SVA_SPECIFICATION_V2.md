# SystemVerilog Assertions (SVA) Specification V2 (`SOC_VB_002`)

- **Document ID:** `SVA-SPEC-002`
- **Baseline ID:** `SOC_VB_002` (extends immutable `SVA-SPEC-001` in `SOC_VB_001`)
- **Version:** `V2.0`
- **Status:** `APPROVED / FROZEN (DEC-VER-BASELINE-002)`
- **Date:** 2026-11-27
- **Approved Decision:** [DEC-VER-BASELINE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-002.md)
- **Author:** Independent Verification Engineer Agent
- **Contract Authority:** `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1 (+ `ARM IHI 0024E` APB3 / Issue B), `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1, `CON-PERIPH-001` v1.0.

---

## 1. Relationship to `SVA_SPECIFICATION_V1.md` (`SOC_VB_001`)

1. All properties in [SVA_SPECIFICATION_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V1.md) (`SVA-APB-001..010`, `SVA-MEM-001..009`, `SVA-DEC-001..003`, `SVA-CPU-001..005`, `SVA-INT-001..002`, `SVA-FLT-001..007`, `SVA-RST-001..006`, `COV-SVA-001..010`) remain active under `SOC_VB_002`.
2. **Syntax Correction for `SVA-CPU-006` (IEEE 1800-2017 / Verilator 5.032 Safe Form):**
   In `SVA_SPECIFICATION_V1.md`, `SVA-CPU-006` combined `|-> (...) and |=> (...)`. For clean IEEE 1800-2017 / Verilator 5.032 compilation in `sva/sva_cpu_fault_rst.sv`, `SVA-CPU-006` is split into two equivalent, unambiguous properties (same-cycle control check and next-cycle `PC` advance):
   ```systemverilog
   property p_cpu_fence_ctrl;
     @(posedge clk) disable iff (!sys_rst_n)
     (!fault_valid && !if_fault && insn[6:0] == 7'b0001111 && insn[14:12] == 3'b000)
     |-> (!dmem_req && !dmem_stall && !rf_we && !fault_detect);
   endproperty

   property p_cpu_fence_pc_step;
     @(posedge clk) disable iff (!sys_rst_n)
     (!fault_valid && !if_fault && insn[6:0] == 7'b0001111 && insn[14:12] == 3'b000)
     |=> (pc == ($past(pc) + 32'd4));
   endproperty
   ```
3. **Peripheral Protocol & Register SVA Unblocked:** Sections 2–4 below define Part A (APB3 Completer boundary & pin) and Part B (register/behavior) SVA properties for `uart_apb`, `gpio_apb`, and `timer_apb` derived strictly from `CON-PERIPH-001` v1.0.

---

## 2. UART (`uart_apb`) Assertions (`CON-PERIPH-001` §1 & §2)

- **Clock & Reset:** `@(posedge PCLK)`, `disable iff (!PRESETn)` (except `SVA-UART-001`).
- **Convenience Expressions:**
  - `let uart_xfer = PSEL_UART && PENABLE && PREADY;`
  - `let uart_wr   = uart_xfer && PWRITE;`
  - `let uart_rd   = uart_xfer && !PWRITE;`

| SVA ID | Separation | Contract Source | Formal Intent & SystemVerilog Property |
|---|---|---|---|
| `SVA-UART-001` | Part A (Boundary) | `CON-FLT-RST-001 §2.2`, `CON-PERIPH-001 §2.3` | **UART Reset Output State:** While `!PRESETn`, `uart_tx_o` must be `1'b1`.<br>`property p_uart_rst_tx_idle; @(posedge PCLK) !PRESETn |-> (uart_tx_o == 1'b1); endproperty` |
| `SVA-UART-002` | Part A (Boundary) | `CON-PERIPH-001 §1.2` | **UART Zero Wait States:** Whenever `PSEL_UART && PENABLE`, `uart_apb` asserts `PREADY == 1'b1`.<br>`property p_uart_zero_wait; @(posedge PCLK) disable iff (!PRESETn) (PSEL_UART && PENABLE) |-> PREADY; endproperty` |
| `SVA-UART-003` | Part A (Boundary) | `CON-PERIPH-001 §1.3, §2.1, §2.2` | **UART Strict `PSLVERR` Rules:** When `uart_xfer` occurs, `PSLVERR` must be `1'b1` iff: (a) `PADDR[11:0]` is unimplemented (`> 12'h010` or unaligned), (b) write to `UART_RX_DATA` (`0x00C`), (c) read from `UART_TX_DATA` (`0x008`), or (d) write to `UART_BAUD_DIV` (`0x010`) with `PWDATA[23:0] < 24'd2`.<br>`property p_uart_pslverr_exact; @(posedge PCLK) disable iff (!PRESETn)`<br>`  uart_xfer |-> (PSLVERR == (`<br>`    !(PADDR[11:0] inside {12'h000, 12'h004, 12'h008, 12'h00C, 12'h010}) ||`<br>`    (PWRITE && PADDR[11:0] == 12'h00C) ||`<br>`    (!PWRITE && PADDR[11:0] == 12'h008) ||`<br>`    (PWRITE && PADDR[11:0] == 12'h010 && PWDATA[23:0] < 24'd2)`<br>`  )); endproperty` |
| `SVA-UART-004` | Part A (Boundary) | `CON-PERIPH-001 §1.3, §2.2` | **UART Error Read Data Zero:** On a failing read (`uart_rd && PSLVERR`), `PRDATA == 32'h0`; on valid reads, reserved upper bits are `0`.<br>`property p_uart_err_rdata_zero; @(posedge PCLK) disable iff (!PRESETn) (uart_rd && PSLVERR) |-> (PRDATA == 32'h0); endproperty` |
| `SVA-UART-005` | Part B (Internal) | `CON-PERIPH-001 §2.2` | **`TX_EMPTY` / `TX_BUSY` Complementary Invariant & `TX_EN=0` Idle:** `tx_empty == !tx_busy` always, and while `!tx_en`, `uart_tx_o == 1'b1`.<br>`property p_uart_tx_status_inv; @(posedge PCLK) disable iff (!PRESETn) (tx_empty == !tx_busy); endproperty`<br>`property p_uart_tx_dis_idle; @(posedge PCLK) disable iff (!PRESETn) !tx_en |-> (uart_tx_o == 1'b1); endproperty` |
| `SVA-UART-006` | Part B (Internal) | `CON-PERIPH-001 §2.2` | **Invalid `UART_BAUD_DIV < 2` Preserves Divider & `BAUD_DIV >= 2` Invariant:** `baud_div >= 24'd2` on every cycle, and writing `< 2` leaves `baud_div` unchanged.<br>`property p_uart_baud_valid; @(posedge PCLK) disable iff (!PRESETn) (baud_div >= 24'd2); endproperty`<br>`property p_uart_baud_err_keep; @(posedge PCLK) disable iff (!PRESETn) (uart_wr && PADDR[11:0] == 12'h010 && PWDATA[23:0] < 24'd2) |=> $stable(baud_div); endproperty` |
| `SVA-UART-007` | Part B (Internal) | `CON-PERIPH-001 §2.2` | **Write While `TX_BUSY` Ignored:** Writing `UART_TX_DATA` when `tx_busy == 1` does not corrupt the active `tx_shift` / `tx_bit_idx`.<br>`property p_uart_tx_busy_ignore; @(posedge PCLK) disable iff (!PRESETn) (uart_wr && PADDR[11:0] == 12'h008 && tx_busy) |-> !tx_start; endproperty` |
| `SVA-UART-008` | Part B (Internal) | `CON-PERIPH-001 §2.2` | **`UART_RX_DATA` Read Clears `RX_VALID`:** Reading `UART_RX_DATA` (`0x00C`) when `rx_valid == 1` (without simultaneous new frame completion) clears `rx_valid` to `0` on the next `PCLK` edge.<br>`property p_uart_rx_read_clears; @(posedge PCLK) disable iff (!PRESETn) (uart_rd && PADDR[11:0] == 12'h00C && rx_valid) |=> !rx_valid; endproperty` |

---

## 3. GPIO (`gpio_apb`) Assertions (`CON-PERIPH-001` §1 & §3)

- **Clock & Reset:** `@(posedge PCLK)`, `disable iff (!PRESETn)` (except `SVA-GPIO-001`).
- **Convenience Expressions:** `let gpio_xfer = PSEL_GPIO && PENABLE && PREADY;`

| SVA ID | Separation | Contract Source | Formal Intent & SystemVerilog Property |
|---|---|---|---|
| `SVA-GPIO-001` | Part A (Boundary) | `CON-FLT-RST-001 §2.2`, `CON-PERIPH-001 §3.1` | **GPIO Reset Outputs:** While `!PRESETn`, `gpio_o == 8'h00` and `gpio_oe_o == 8'h00`.<br>`property p_gpio_rst_outputs; @(posedge PCLK) !PRESETn |-> (gpio_o == 8'h00 && gpio_oe_o == 8'h00); endproperty` |
| `SVA-GPIO-002` | Part A (Boundary) | `CON-PERIPH-001 §1.2` | **GPIO Zero Wait States:** Whenever `PSEL_GPIO && PENABLE`, `gpio_apb` asserts `PREADY == 1'b1`.<br>`property p_gpio_zero_wait; @(posedge PCLK) disable iff (!PRESETn) (PSEL_GPIO && PENABLE) |-> PREADY; endproperty` |
| `SVA-GPIO-003` | Part A (Boundary) | `CON-PERIPH-001 §1.3, §3.1` | **GPIO Strict `PSLVERR` Rules:** `PSLVERR` is `1'b1` iff `PADDR[11:0]` is unimplemented (`not in {0x000, 0x004, 0x008}`) or a write targets `RO` `GPIO_DATA_IN` (`0x000`).<br>`property p_gpio_pslverr_exact; @(posedge PCLK) disable iff (!PRESETn)`<br>`  gpio_xfer |-> (PSLVERR == (`<br>`    !(PADDR[11:0] inside {12'h000, 12'h004, 12'h008}) ||`<br>`    (PWRITE && PADDR[11:0] == 12'h000)`<br>`  )); endproperty` |
| `SVA-GPIO-004` | Part A (Boundary) | `CON-PERIPH-001 §3.3` | **GPIO Output Stability & Exact Update:** `gpio_o` updates only after a valid write to `GPIO_DATA_OUT` (`0x004`), and `gpio_oe_o` updates only after a valid write to `GPIO_DIR` (`0x008`), capturing `PWDATA[7:0]`.<br>`property p_gpio_out_update; @(posedge PCLK) disable iff (!PRESETn) (gpio_xfer && PWRITE && PADDR[11:0] == 12'h004) |=> (gpio_o == $past(PWDATA[7:0])); endproperty`<br>`property p_gpio_out_hold; @(posedge PCLK) disable iff (!PRESETn) !(gpio_xfer && PWRITE && PADDR[11:0] == 12'h004) |=> $stable(gpio_o); endproperty`<br>`property p_gpio_dir_update; @(posedge PCLK) disable iff (!PRESETn) (gpio_xfer && PWRITE && PADDR[11:0] == 12'h008) |=> (gpio_oe_o == $past(PWDATA[7:0])); endproperty`<br>`property p_gpio_dir_hold; @(posedge PCLK) disable iff (!PRESETn) !(gpio_xfer && PWRITE && PADDR[11:0] == 12'h008) |=> $stable(gpio_oe_o); endproperty` |
| `SVA-GPIO-005` | Part B (Internal) | `CON-PERIPH-001 §3.3` | **GPIO 2-FF Input Synchronizer:** Reading `GPIO_DATA_IN` (`0x000`) returns `{24'h0, sync2}` where `sync2 == $past(gpio_i, 2)`.<br>`property p_gpio_sync2_read; @(posedge PCLK) disable iff (!PRESETn) (gpio_xfer && !PWRITE && PADDR[11:0] == 12'h000) |-> (PRDATA == {24'h0, sync2}); endproperty`<br>`property p_gpio_2ff_pipeline; @(posedge PCLK) disable iff (!PRESETn) ($past(PRESETn,2)) |-> (sync2 == $past(gpio_i, 2)); endproperty` |

---

## 4. Timer (`timer_apb`) Assertions (`CON-PERIPH-001` §1 & §4)

- **Clock & Reset:** `@(posedge PCLK)`, `disable iff (!PRESETn)` (except `SVA-TIMER-001`).
- **Convenience Expressions:**
  - `let tmr_xfer = PSEL_TIMER && PENABLE && PREADY;`
  - `let tmr_wr   = tmr_xfer && PWRITE;`
  - `let tmr_rd   = tmr_xfer && !PWRITE;`

| SVA ID | Separation | Contract Source | Formal Intent & SystemVerilog Property |
|---|---|---|---|
| `SVA-TIMER-001` | Part B (Internal) | `CON-PERIPH-001 §4.1` | **Timer Reset State:** While `!PRESETn`, `ctrl == 0`, `status == 0`, `counter == 32'h0`, `compare == 32'hFFFF_FFFF`.<br>`property p_timer_rst_state; @(posedge PCLK) !PRESETn |-> (!en && !auto_reload && !status_match && !status_ovf && counter == 32'h0 && compare == 32'hFFFF_FFFF); endproperty` |
| `SVA-TIMER-002` | Part A (Boundary) | `CON-PERIPH-001 §1.2` | **Timer Zero Wait States:** Whenever `PSEL_TIMER && PENABLE`, `timer_apb` asserts `PREADY == 1'b1`.<br>`property p_timer_zero_wait; @(posedge PCLK) disable iff (!PRESETn) (PSEL_TIMER && PENABLE) |-> PREADY; endproperty` |
| `SVA-TIMER-003` | Part A (Boundary) | `CON-PERIPH-001 §1.3, §4.1` | **Timer Strict `PSLVERR` Rules:** `PSLVERR` is `1'b1` iff `PADDR[11:0]` is outside `{0x000, 0x004, 0x008, 0x00C}`.<br>`property p_timer_pslverr_exact; @(posedge PCLK) disable iff (!PRESETn) tmr_xfer |-> (PSLVERR == !(PADDR[11:0] inside {12'h000, 12'h004, 12'h008, 12'h00C})); endproperty` |
| `SVA-TIMER-004` | Part A (Boundary) | `CON-PERIPH-001 §4.2` | **`CLR_CNT` Self-Clearing (`WO/SC`):** Reading `TIMER_CTRL` (`0x000`) always returns `PRDATA[31:2] == 30'h0` (bit `[2]` `CLR_CNT` always reads `0`).<br>`property p_timer_ctrl_clr_reads_zero; @(posedge PCLK) disable iff (!PRESETn) (tmr_rd && PADDR[11:0] == 12'h000) |-> (PRDATA[31:2] == 30'h0); endproperty` |
| `SVA-TIMER-005` | Part B (Internal) | `CON-PERIPH-001 §4.3.1` | **Counter Direct Write & `CLR_CNT` Precedence:** Writing `TIMER_COUNTER` sets `counter <= PWDATA` (no `+1`), and writing `TIMER_CTRL` with `PWDATA[2]==1` clears `counter <= 32'h0` (without raising `MATCH` or `OVF`).<br>`property p_timer_cnt_wr_prio; @(posedge PCLK) disable iff (!PRESETn) (tmr_wr && PADDR[11:0] == 12'h008) |=> (counter == $past(PWDATA)); endproperty`<br>`property p_timer_clr_cnt_prio; @(posedge PCLK) disable iff (!PRESETn) (!(tmr_wr && PADDR[11:0] == 12'h008) && tmr_wr && PADDR[11:0] == 12'h000 && PWDATA[2]) |=> (counter == 32'h0); endproperty` |
| `SVA-TIMER-006` | Part B (Internal) | `CON-PERIPH-001 §4.3.1` | **Auto-Reload (`COMPARE + 1`) & Free-Running Count:** When `EN == 1` and neither `TIMER_COUNTER` write nor `CLR_CNT` occurs, if `AUTO_RELOAD && counter == compare` then `counter <= 0` and `status_match <= 1`; else `counter <= counter + 1`. When `EN == 0` (and no write/`CLR_CNT`), `counter` holds.<br>`property p_timer_auto_reload; @(posedge PCLK) disable iff (!PRESETn)`<br>`  (en && auto_reload && (counter == compare) && !(tmr_wr && PADDR[11:0] == 12'h008) && !(tmr_wr && PADDR[11:0] == 12'h000 && PWDATA[2])) |=> (counter == 32'h0 && status_match); endproperty`<br>`property p_timer_pause_hold; @(posedge PCLK) disable iff (!PRESETn)`<br>`  (!en && !(tmr_wr && PADDR[11:0] == 12'h008) && !(tmr_wr && PADDR[11:0] == 12'h000 && PWDATA[2])) |=> $stable(counter); endproperty` |
| `SVA-TIMER-007` | Part B (Internal) | `CON-PERIPH-001 §4.2, §4.3.2` | **Overflow (`OVF`) on `0xFFFF_FFFF` Wrap & Hardware Precedence:** When `en && !auto_reload_match && !cnt_wr && !clr_cnt && counter == 32'hFFFF_FFFF`, next cycle `counter == 0` and `status_ovf == 1` (even if simultaneous `W1C` write occurred).<br>`property p_timer_ovf_set; @(posedge PCLK) disable iff (!PRESETn)`<br>`  (en && !(auto_reload && counter == compare) && !(tmr_wr && PADDR[11:0] == 12'h008) && !(tmr_wr && PADDR[11:0] == 12'h000 && PWDATA[2]) && (counter == 32'hFFFF_FFFF)) |=> (counter == 32'h0 && status_ovf); endproperty` |
| `SVA-TIMER-008` | Part B (Internal) | `CON-PERIPH-001 §4.2` | **`W1C` Clear When No Simultaneous Hardware Event:** Writing `1` to `TIMER_STATUS[0]` (`MATCH`) or `[1]` (`OVF`) clears the flag if no new hardware match/ovf occurs on that cycle.<br>`property p_timer_w1c_match; @(posedge PCLK) disable iff (!PRESETn) (tmr_wr && PADDR[11:0] == 12'h004 && PWDATA[0] && !(en && !clr_or_cnt_wr && counter == compare)) |=> !status_match; endproperty` |

---

## 5. Peripheral Functional `cover property` Milestones

| Cover ID | Scenario Description | Cover Expression (`@(posedge PCLK)`, `disable iff (!PRESETn)`) |
|---|---|---|
| `COV-SVA-011` | UART valid TX write accepted (`TX_EN && !TX_BUSY`) | `(uart_wr && PADDR[11:0] == 12'h008 && tx_en && !tx_busy)` |
| `COV-SVA-012` | UART write while `TX_BUSY` ignored | `(uart_wr && PADDR[11:0] == 12'h008 && tx_busy)` |
| `COV-SVA-013` | UART `RX_VALID` read-clear | `(uart_rd && PADDR[11:0] == 12'h00C && rx_valid)` |
| `COV-SVA-014` | UART `RX_OVERRUN` and `RX_FRAME_ERR` `W1C` cleared | `(uart_wr && PADDR[11:0] == 12'h004 && (PWDATA[4] || PWDATA[3]))` |
| `COV-SVA-015` | UART `PSLVERR` triggered (invalid `BAUD_DIV < 2` or RO/WO/unimpl) | `(uart_xfer && PSLVERR)` |
| `COV-SVA-016` | GPIO direction & output driven non-zero, then `GPIO_DATA_IN` read non-zero | `(gpio_oe_o != 8'h00 && gpio_o != 8'h00) ##[1:20] (gpio_xfer && !PWRITE && PADDR[11:0] == 12'h000 && PRDATA[7:0] != 8'h00)` |
| `COV-SVA-017` | Timer `AUTO_RELOAD` match reload (`counter == compare` -> `0`) | `(en && auto_reload && counter == compare)` |
| `COV-SVA-018` | Timer `0xFFFF_FFFF` wrap (`OVF` set) | `(en && counter == 32'hFFFF_FFFF && !(auto_reload && counter == compare))` |
| `COV-SVA-019` | Timer `W1C` clear of `MATCH` and `OVF` | `(tmr_wr && PADDR[11:0] == 12'h004 && PWDATA[1:0] == 2'b11)` |
