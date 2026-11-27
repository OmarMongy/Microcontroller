# Peripheral Register-Map Architecture Proposal (`UART`, `GPIO`, `Timer`)

- **Document ID:** `ARCH-PROP-002`
- **Version:** `V1 (APPROVED PER DEC-ARCH-PERIPH-001)`
- **Date:** 2026-11-27
- **Author:** Architect Agent
- **Approved Human Decision:** [DEC-ARCH-PERIPH-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-PERIPH-001.md) (`APPROVED` — `#P1`–`#P5`)
- **Frozen Prerequisite Contracts:**
  - [ADDRESS_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/ADDRESS_MAP_CONTRACT.md) (`CON-ADDR-001` — `APPROVED`)
  - [APB3_BRIDGE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/APB3_BRIDGE_CONTRACT.md) (`CON-APB3-001` — `APPROVED`)
  - [SOC_TOP_HIERARCHY_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/SOC_TOP_HIERARCHY_CONTRACT.md) (`CON-TOP-001` — `APPROVED`)
- **External Protocol Reference:** `AMBA® APB Protocol Specification` (ARM IHI 0024E / ID022823, Issue E — APB3 / Issue B rules only)

> **Status Notice:** Decisions `#P1`–`#P5` in this proposal and [PERIPHERAL_REGISTER_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/PERIPHERAL_REGISTER_MAP_CONTRACT.md) (`CON-PERIPH-001`) are **APPROVED / FROZEN** per [DEC-ARCH-PERIPH-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-PERIPH-001.md).

---

## 1. Frozen Architectural Constraints Respected

1. **Peripheral Address Slots (`CON-ADDR-001`):**
   - `uart_apb` (`PSEL_UART`): `0x4000_0000` – `0x4000_0FFF` (4 KB, decodes `PADDR[11:0]`)
   - `gpio_apb` (`PSEL_GPIO`): `0x4000_1000` – `0x4000_1FFF` (4 KB, decodes `PADDR[11:0]`)
   - `timer_apb` (`PSEL_TIMER`): `0x4000_2000` – `0x4000_2FFF` (4 KB, decodes `PADDR[11:0]`)
2. **APB3 Bus Rules (`CON-APB3-001`):**
   - Strict APB3 (`PCLK` = 50 MHz, `PRESETn`, `PADDR`, `PSELx`, `PENABLE`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`, `PSLVERR`). No `PSTRB`, `PPROT`, or APB5 signals.
   - Strict 32-bit aligned `LW`/`SW` only (`PADDR[1:0] == 2'b00`); sub-word and unaligned accesses fault in `data_bus_decode` before reaching the peripherals.
   - `PSLVERR` is valid only when `PSELx && PENABLE && PREADY`.
3. **Top-Level Pins & Polling (`CON-TOP-001`, `SOC_SPECIFICATION_DRAFT`):**
   - `uart_rx_i`, `uart_tx_o`; `gpio_i[7:0]`, `gpio_o[7:0]`, `gpio_oe_o[7:0]`.
   - No interrupts initially; software polls peripheral status registers.

---

## 2. Cross-Peripheral APB3 Consistency Policy (`PROPOSED`)

### 2.1 `PREADY` Policy (`PROPOSED`: Fixed 0-Wait-State `PREADY = 1'b1`)
All three peripherals (`uart_apb`, `gpio_apb`, `timer_apb`) operate synchronously on `PCLK` (50 MHz) with simple register files and return **`PREADY = 1'b1`** unconditionally (0 APB wait states beyond the standard 2-phase APB3 `SETUP` + `ACCESS` transfer, i.e., 3 total SoC clock cycles via `Design 4A`).
- *Trade-off vs. stalling `PREADY = 0` on `UART_TX_DATA` when busy:* Stalling APB3 for ~4,340 cycles (86.8 µs at 115200 baud) would freeze the CPU and block timer/GPIO polling; polling `UART_STATUS.TX_EMPTY` keeps bus latency deterministic and educational.

### 2.2 `PSLVERR` & Reserved-Bit Policy (`PROPOSED` Option P-ERR1 — Strict Access Checking)
To give clear software diagnostics and clean, testable `PSLVERR` conditions:
1. **Unimplemented register offset** within a peripheral's 4 KB slot (`PADDR[11:0]` outside defined offsets, read or write) -> **`PREADY = 1, PSLVERR = 1`** (read returns `32'h0`).
2. **Write to a Read-Only (`RO`) register** (e.g., `UART_RX_DATA`, `GPIO_DATA_IN`) -> **`PREADY = 1, PSLVERR = 1`** (register untouched).
3. **Read from a Write-Only (`WO`) register** (e.g., `UART_TX_DATA`) -> **`PREADY = 1, PSLVERR = 1`** (read returns `32'h0`).
   - *Alternative (Option P-ERR2 — Permissive `RO`/`WO`):* Ignore writes to `RO` and return `0` on reads of `WO` with `PSLVERR = 0`, using `PSLVERR = 1` only for unimplemented offsets. **Human decision required (Decision #P1).**
4. **Invalid configuration value** (`UART_BAUD_DIV < 2`) -> **`PREADY = 1, PSLVERR = 1`** (divisor untouched).
5. **Reserved bits inside implemented registers:** Reads return `0`; writes are ignored (must not assert `PSLVERR`, preserving forward compatibility).

---

## 3. UART (`uart_apb`) Design & Trade-Offs (`PROPOSED`)

### 3.1 Proposed Register Set (`0x4000_0000`–`0x4000_0FFF`)
- `0x000` **`UART_CTRL`** (`RW`, reset `32'h0000_0003`): `[0] TX_EN` (reset `1`), `[1] RX_EN` (reset `1`).
- `0x004` **`UART_STATUS`** (`RO/W1C`, reset `32'h0000_0002`): `[0] TX_BUSY` (`RO`), `[1] TX_EMPTY` (`RO`, reset `1`), `[2] RX_VALID` (`RO`), `[3] RX_OVERRUN` (`W1C`), `[4] RX_FRAME_ERR` (`W1C`).
- `0x008` **`UART_TX_DATA`** (`WO`, reset `32'h0`): `[7:0] TX_DATA`.
- `0x00C` **`UART_RX_DATA`** (`RO`, reset `32'h0`): `[7:0] RX_DATA` (reading clears `RX_VALID`).
- `0x010` **`UART_BAUD_DIV`** (`RW`, reset `32'h0000_01B2` = `434`): `[23:0] BAUD_DIV` (`>= 2`).

### 3.2 Baud-Rate Math @ 50 MHz (`PROPOSED`: Bit-Period Divider `BAUD_DIV`)
- **Formula:** `Baud = f_clk / BAUD_DIV`, where `f_clk = 50,000,000 Hz`.
- **Default (`115200` baud):** `50,000,000 / 115,200 = 434.0278` -> **`BAUD_DIV = 434` (`0x00_01B2`)**.
  - Actual baud rate = `50,000,000 / 434 = 115,207.37 Hz`.
  - Frequency error = **`+0.0064%`** (far below the typical ±2% UART tolerance).
- **Field width (`24-bit` `[23:0]` vs `16-bit` `[15:0]`):** A 16-bit divider maxes out at `50 MHz / 65,535 = 763 baud` (cannot reach 300 baud = `166,667`). A **24-bit** field covers `< 3 baud` up to `25 Mbaud` (`BAUD_DIV = 2`).
- **Alternative (16x Oversampling):** `50,000,000 / (16 * 115,200) = 27.127 -> 27`, yielding `115,740.7 Hz` (**`+0.469%`** error — ~73x worse accuracy) and coarser high-baud steps.
  - *Why bit-period divider with mid-bit start sampling (`BAUD_DIV >> 1`) is recommended:* Simpler RTL, 73x better baud accuracy at 50 MHz, and trivial small-divisor simulation speedup (e.g., `BAUD_DIV = 4`). **Human decision required (Decision #P2).**

### 3.3 Buffering, TX-Busy Write, and `uart_rx_i` Synchronization (`PROPOSED`)
- **Buffering (`PROPOSED` 1-entry TX/RX holding buffer vs. multi-byte FIFO):**
  - *1-entry holding buffer:* Simplest educational hardware; `TX_BUSY` (`~TX_EMPTY`) is `1` while the TX shift register is active; `RX_VALID` is `1` when `UART_RX_DATA` holds an unread byte.
  - *Trade-off:* No hardware back-to-back byte queue; software must poll `RX_VALID` before the next 10-bit frame completes (`~86.8 µs` @ 115200 baud = ~4,340 CPU clocks, ample time for polling). A deeper FIFO (e.g. 4–16 bytes) adds area and reset/pointer complexity without changing the external 8N1 pins. **Human decision required (Decision #P3).**
- **Write to `UART_TX_DATA` while `TX_BUSY == 1` (or `TX_EN == 0`) (`PROPOSED`):** Write is **ignored** (active frame in flight is not corrupted, `PREADY = 1, PSLVERR = 0`). *(Alternative: assert `PSLVERR = 1`, which would halt the CPU if polling had an off-by-one bug.)*
- **`uart_rx_i` Input Synchronization:** `uart_rx_i` is routed through a **2-FF synchronizer** (`rx_sync1`, `rx_sync2`, both reset to `1'b1` idle HIGH) clocked by `clk` (50 MHz). Start-bit detection waits `BAUD_DIV / 2` cycles from the synchronized falling edge to verify `rx_sync2 == 0` at bit center (glitch rejection), then samples bits `0..7` and the Stop bit every `BAUD_DIV` cycles.
- **RX Error Policies (`PROPOSED`):**
  - If a valid Stop bit completes while `RX_VALID == 1`, set sticky `RX_OVERRUN = 1` (`W1C`) and **preserve the existing unread `UART_RX_DATA`** (discarding the newer byte).
  - If Stop bit samples as `0`, set sticky `RX_FRAME_ERR = 1` (`W1C`) and **do not assert `RX_VALID`** for the corrupted frame.

---

## 4. GPIO (`gpio_apb`) Design & Trade-Offs (`PROPOSED`)

### 4.1 Proposed Register Set (`0x4000_1000`–`0x4000_1FFF`)
- `0x000` **`GPIO_DATA_IN`** (`RO`, reset `32'h0000_0000`): `[7:0]` returns 2-FF synchronized `gpio_i[7:0]`.
- `0x004` **`GPIO_DATA_OUT`** (`RW`, reset `32'h0000_0000`): `[7:0]` drives `gpio_o[7:0]`.
- `0x008` **`GPIO_DIR`** (`RW`, reset `32'h0000_0000`): `[7:0]` drives `gpio_oe_o[7:0]` (`0` = input, `1` = output).

### 4.2 Design Choices & Trade-Offs
- **2-FF Input Synchronizer:** `gpio_i[7:0]` passes through two `posedge clk` flip-flop stages (`sync1`, `sync2`, reset to `8'h00`). Reading `GPIO_DATA_IN` returns `sync2[7:0]` (2–3 `clk` cycles external-pin-to-read latency) regardless of `DIR` (`gpio_oe_o`), allowing testbenches/external pads to verify pin state directly while `GPIO_DATA_OUT` reads back the driven output register.
- **Simple `DATA_OUT` + `DIR` vs. Optional `OUT_SET` / `OUT_CLR` (`0x00C` / `0x010`):**
  - *Recommended (`PROPOSED`):* Omit atomic `OUT_SET`/`OUT_CLR` registers initially because interrupts are out of scope (`A2`), so bare-metal C read-modify-write on `GPIO_DATA_OUT` is atomic with zero race conditions and keeps the register map minimal. Adding `OUT_SET`/`OUT_CLR` later is non-breaking if ever needed. **Human decision required (Decision #P4).**

---

## 5. Timer (`timer_apb`) Design & Trade-Offs (`PROPOSED`)

### 5.1 Proposed Register Set (`0x4000_2000`–`0x4000_2FFF`)
- `0x000` **`TIMER_CTRL`** (`RW`, reset `32'h0000_0000`): `[0] EN`, `[1] AUTO_RELOAD`, `[2] CLR_CNT` (`WO` self-clearing `1` -> resets `COUNTER <= 0`).
- `0x004` **`TIMER_STATUS`** (`W1C`, reset `32'h0000_0000`): `[0] MATCH` (`W1C`), `[1] OVF` (`W1C`).
- `0x008` **`TIMER_COUNTER`** (`RW`, reset `32'h0000_0000`): `[31:0] COUNTER`.
- `0x00C` **`TIMER_COMPARE`** (`RW`, reset `32'hFFFF_FFFF`): `[31:0] COMPARE`.

### 5.2 Key Semantic Choices (`PROPOSED`)
1. **`TIMER_COMPARE` Reset Value = `32'hFFFF_FFFF` (not `32'h0000_0000`):** Prevents an unintended cycle-0 `0 == 0` compare match if software sets `EN = 1` before writing `TIMER_COMPARE`.
2. **Exact Cycle-Accurate Match Rule:** On `posedge clk` when `EN == 1` and `COUNTER == COMPARE` (and no software write to `TIMER_COUNTER` / `CLR_CNT` in that cycle):
   - Sticky `MATCH` sets to `1` (visible on APB reads starting the very next cycle).
   - If `AUTO_RELOAD == 1`: `COUNTER <= 32'h0000_0000` (giving a periodic interval of **`COMPARE + 1`** clock cycles, e.g., `COMPARE = 49,999` -> `50,000` ticks = `1.000 ms` @ 50 MHz).
   - If `AUTO_RELOAD == 0`: `COUNTER <= COUNTER + 32'd1` (free-running; wraps at `32'hFFFF_FFFF -> 32'h0000_0000` and sets sticky `OVF = 1`).
3. **Concurrent Software Writes while `EN == 1`:**
   - Writing `TIMER_COUNTER` (or `CTRL.CLR_CNT = 1`) updates `COUNTER` on that `posedge clk` and suppresses the `+1` increment for that cycle so the written value is exact.
   - Writing `TIMER_COMPARE` updates `COMPARE` on that `posedge clk`; comparison uses the registered `COMPARE` value on the following cycle.
   - If a hardware `MATCH`/`OVF` event occurs on the same `posedge clk` as a `W1C` clear write, the new hardware event wins (`MATCH <= 1`) so events are not silently lost.

---

## 6. Exact Human Decisions Required

1. **Decision #P1 (Cross-Peripheral `PSLVERR` Policy):** Approve **Option P-ERR1** (strict: unimplemented offsets, writes to `RO`, reads from `WO`, and `UART_BAUD_DIV < 2` assert `PSLVERR = 1`; reserved bits read `0`/ignore writes) vs. Option P-ERR2 (permissive on `RO`/`WO`)?
2. **Decision #P2 (UART Baud Divider Architecture):** Approve **24-bit bit-period divider `BAUD_DIV`** (default `434`, `+0.0064%` error @ 50 MHz, mid-bit start sampling at `BAUD_DIV >> 1`, valid `>= 2`) vs. 16x oversampling (`27`, `+0.469%` error)?
3. **Decision #P3 (UART Buffering & TX-Busy Write Behavior):** Approve **1-entry TX/RX holding registers** (TX/RX enabled at reset, polling `TX_EMPTY`/`RX_VALID`, ignoring writes while `TX_BUSY == 1`) vs. deeper FIFO or `PSLVERR` on TX-busy write?
4. **Decision #P4 (GPIO Register Set):** Approve minimal 3-register map (`GPIO_DATA_IN`, `GPIO_DATA_OUT`, `GPIO_DIR`) with 2-FF `gpio_i` synchronizer vs. adding `OUT_SET`/`OUT_CLR` registers?
5. **Decision #P5 (Timer Register Set & Match Semantics):** Approve 4-register map (`TIMER_CTRL`, `TIMER_STATUS`, `TIMER_COUNTER`, `TIMER_COMPARE` reset `32'hFFFF_FFFF`) with `AUTO_RELOAD` (`COMPARE + 1` tick period), `CLR_CNT`, `W1C` `MATCH`/`OVF`?
