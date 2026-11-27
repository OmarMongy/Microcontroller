# Peripheral Register-Map Interface Contract (`UART`, `GPIO`, `Timer`)

- **Contract ID:** `CON-PERIPH-001`
- **Version:** `v1.0`
- **Status:** `APPROVED (DEC-ARCH-PERIPH-001)`
- **Date:** 2026-11-27
- **Parent Proposal:** [PERIPHERAL_REGISTER_PROPOSAL.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/PERIPHERAL_REGISTER_PROPOSAL.md) (`ARCH-PROP-002`)
- **Approved Decision:** [DEC-ARCH-PERIPH-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-PERIPH-001.md) (`#P1`–`#P5`)
- **Frozen Prerequisite Contracts:** `CON-ADDR-001` (`APPROVED`), `CON-APB3-001` (`APPROVED`), `CON-TOP-001` (`APPROVED`)

---

## 1. Common APB3 Peripheral Rules (`PROPOSED`)

All three peripherals (`uart_apb`, `gpio_apb`, `timer_apb`) are APB3 Completers clocked by `PCLK` (`50 MHz`) with active-LOW reset `PRESETn` (`sys_rst_n`):
1. **Access Width (`CON-APB3-001`):** Strictly 32-bit aligned `LW`/`SW` transfers (`PADDR[1:0] == 2'b00`).
2. **Wait States:** Fixed 0 APB wait states (**`PREADY = 1'b1`**). Every APB3 transfer completes on the first `ACCESS` cycle (`PSELx && PENABLE`).
3. **Error Response (`PSLVERR`, valid when `PSELx && PENABLE && PREADY`):**
   - Access (read or write) to any unimplemented `PADDR[11:0]` offset -> `PSLVERR = 1'b1` (read returns `32'h0`).
   - Write to a pure `RO` register -> `PSLVERR = 1'b1` (state unchanged).
   - Read from a pure `WO` register -> `PSLVERR = 1'b1` (returns `32'h0`).
   - Peripheral-specific invalid configuration write (`UART_BAUD_DIV < 2`) -> `PSLVERR = 1'b1` (state unchanged).
   - Reserved bits inside valid implemented registers: read as `0`, writes ignored (`PSLVERR = 1'b0`).
4. **Access Type Legend:** `RW` = Read/Write, `RO` = Read-Only, `WO` = Write-Only, `W1C` = Read/Write-1-to-Clear (writing `0` has no effect; writing `1` clears bit), `WO/SC` = Write-Only Self-Clearing (reads `0`).

---

## 2. UART (`uart_apb`) — Base `0x4000_0000` (`PSEL_UART`) (`PROPOSED`)

### 2.1 Register Summary (`PADDR[11:0]`)

| Offset | Name | Access | Reset Value | Description |
|---|---|---|---:|---|
| `0x000` | `UART_CTRL` | `RW` | `32'h0000_0003` | Transmitter/Receiver enable control |
| `0x004` | `UART_STATUS` | `RO` / `W1C` | `32'h0000_0002` | TX/RX status and sticky error flags |
| `0x008` | `UART_TX_DATA` | `WO` | `32'h0000_0000` | Transmit byte holding register |
| `0x00C` | `UART_RX_DATA` | `RO` | `32'h0000_0000` | Receive byte holding register (read clears `RX_VALID`) |
| `0x010` | `UART_BAUD_DIV` | `RW` | `32'h0000_01B2` | 24-bit clock-per-bit divisor (`434` = 115200 baud @ 50 MHz) |
| `0x014`–`0xFFC` | *Unimplemented* | — | — | `PSLVERR = 1'b1` on any read or write |

### 2.2 Register Bit Definitions

#### `UART_CTRL` (`0x000`, Reset: `32'h0000_0003`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:2` | `RSVD` | `RO` | `30'h0` | Reserved; reads `0`, writes ignored. |
| `1` | `RX_EN` | `RW` | `1'b1` | `1` = UART receiver enabled; `0` = receiver disabled (stops start-bit detection). |
| `0` | `TX_EN` | `RW` | `1'b1` | `1` = UART transmitter enabled; `0` = transmitter disabled (`uart_tx_o` held idle `1`). |

#### `UART_STATUS` (`0x004`, Reset: `32'h0000_0002`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:5` | `RSVD` | `RO` | `27'h0` | Reserved; reads `0`, writes ignored. |
| `4` | `RX_FRAME_ERR` | `W1C` | `1'b0` | Sticky framing error (`1` if stop bit sampled as `0`). Write `1` to clear. |
| `3` | `RX_OVERRUN` | `W1C` | `1'b0` | Sticky overrun (`1` if valid frame completes while `RX_VALID == 1`). Write `1` to clear. |
| `2` | `RX_VALID` | `RO` | `1'b0` | `1` when `UART_RX_DATA` holds an unread byte; cleared on read of `UART_RX_DATA`. |
| `1` | `TX_EMPTY` | `RO` | `1'b1` | `1` when TX is idle and ready for a new byte (`TX_EMPTY == ~TX_BUSY`). |
| `0` | `TX_BUSY` | `RO` | `1'b0` | `1` while TX is transmitting a frame (Start + 8 data + Stop). |

*(Note: Writing `UART_STATUS` clears only `W1C` bits `[4:3]` where `PWDATA[i] == 1`; writes to `RO` bits `[2:0]` are ignored without `PSLVERR`.)*

#### `UART_TX_DATA` (`0x008`, Reset: `32'h0000_0000`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:8` | `RSVD` | `WO` | `24'h0` | Ignored on write. |
| `7:0` | `TX_DATA` | `WO` | `8'h00` | Writing when `TX_EN == 1 && TX_BUSY == 0` starts 8N1 transmission (LSB first). Writing while `TX_BUSY == 1` or `TX_EN == 0` is ignored (`PREADY = 1, PSLVERR = 0`). Reading triggers `PSLVERR = 1`. |

#### `UART_RX_DATA` (`0x00C`, Reset: `32'h0000_0000`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:8` | `RSVD` | `RO` | `24'h0` | Reads `0`. |
| `7:0` | `RX_DATA` | `RO` | `8'h00` | Oldest unread received byte. Reading when `RX_VALID == 1` clears `RX_VALID` to `0` on that `PCLK` edge. Writing triggers `PSLVERR = 1`. |

#### `UART_BAUD_DIV` (`0x010`, Reset: `32'h0000_01B2`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:24` | `RSVD` | `RO` | `8'h00` | Reads `0`, writes ignored. |
| `23:0` | `BAUD_DIV` | `RW` | `24'h0001B2` (`434`) | Number of `PCLK` cycles per UART bit time (`Baud = 50 MHz / BAUD_DIV`). Must be `>= 2`; writing `PWDATA[23:0] < 2` asserts `PSLVERR = 1` and preserves previous `BAUD_DIV`. |

### 2.3 Functional & Timing Rules (`uart_apb`)
- **Frame Format:** Fixed 8N1 (1 Start bit `0`, 8 Data bits LSB-first, No parity, 1 Stop bit `1`). Idle `uart_tx_o = 1'b1` (including during `PRESETn == 0`).
- **RX Synchronizer & Sampling:** `uart_rx_i` passes through a 2-FF synchronizer (`rx_sync1`, `rx_sync2`, reset to `1'b1`) on `posedge PCLK`. On synchronized falling edge (`rx_sync2 == 0` in `RX_IDLE` while `RX_EN == 1`), RX waits `BAUD_DIV >> 1` cycles to verify Start-bit center (`rx_sync2 == 0`, else returns to `RX_IDLE`), then samples bits `0..7` and Stop bit every `BAUD_DIV` cycles.
- **RX Error & Overrun:** If Stop bit is `1`: if `RX_VALID == 0`, latches byte into `RX_DATA` and sets `RX_VALID <= 1`; if `RX_VALID == 1`, preserves existing `RX_DATA` and sets `RX_OVERRUN <= 1`. If Stop bit is `0`: sets `RX_FRAME_ERR <= 1` and discards frame (`RX_VALID` unchanged).

---

## 3. GPIO (`gpio_apb`) — Base `0x4000_1000` (`PSEL_GPIO`) (`PROPOSED`)

### 3.1 Register Summary (`PADDR[11:0]`)

| Offset | Name | Access | Reset Value | Description |
|---|---|---|---:|---|
| `0x000` | `GPIO_DATA_IN` | `RO` | `32'h0000_0000` | 2-FF synchronized external `gpio_i[7:0]` input state |
| `0x004` | `GPIO_DATA_OUT` | `RW` | `32'h0000_0000` | Output value register driving `gpio_o[7:0]` |
| `0x008` | `GPIO_DIR` | `RW` | `32'h0000_0000` | Direction register driving `gpio_oe_o[7:0]` (`1`=out, `0`=in) |
| `0x00C`–`0xFFC` | *Unimplemented* | — | — | `PSLVERR = 1'b1` on any read or write |

### 3.2 Register Bit Definitions

#### `GPIO_DATA_IN` (`0x000`, Reset: `32'h0000_0000`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:8` | `RSVD` | `RO` | `24'h0` | Reads `0`. |
| `7:0` | `DATA_IN` | `RO` | `8'h00` | Returns 2-FF synchronized `gpio_i[7:0]` (`sync2[7:0]`). Writing triggers `PSLVERR = 1`. |

#### `GPIO_DATA_OUT` (`0x004`, Reset: `32'h0000_0000`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:8` | `RSVD` | `RO` | `24'h0` | Reads `0`, writes ignored. |
| `7:0` | `DATA_OUT` | `RW` | `8'h00` | Registered output value; directly drives `gpio_o[7:0]`. |

#### `GPIO_DIR` (`0x008`, Reset: `32'h0000_0000`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:8` | `RSVD` | `RO` | `24'h0` | Reads `0`, writes ignored. |
| `7:0` | `DIR` | `RW` | `8'h00` | Per-bit direction (`1` = output enabled, `0` = input); directly drives `gpio_oe_o[7:0]`. |

### 3.3 Functional & Timing Rules (`gpio_apb`)
- **Input Synchronization:** `gpio_i[7:0]` is sampled by two flip-flop stages (`sync1 <= gpio_i; sync2 <= sync1;`, both reset to `8'h00`) on `posedge PCLK`. External input transitions become observable in `GPIO_DATA_IN` after 2–3 `PCLK` edges.
- **Output Update:** Writes to `GPIO_DATA_OUT` and `GPIO_DIR` update `gpio_o` / `gpio_oe_o` synchronously on the APB3 `ACCESS` completion edge (`PSEL_GPIO && PENABLE && PREADY && PWRITE`).

---

## 4. Timer (`timer_apb`) — Base `0x4000_2000` (`PSEL_TIMER`) (`PROPOSED`)

### 4.1 Register Summary (`PADDR[11:0]`)

| Offset | Name | Access | Reset Value | Description |
|---|---|---|---:|---|
| `0x000` | `TIMER_CTRL` | `RW` / `WO/SC` | `32'h0000_0000` | Enable, auto-reload mode, and software counter clear |
| `0x004` | `TIMER_STATUS` | `W1C` | `32'h0000_0000` | Sticky compare-match and overflow flags |
| `0x008` | `TIMER_COUNTER` | `RW` | `32'h0000_0000` | 32-bit up-counter value |
| `0x00C` | `TIMER_COMPARE` | `RW` | `32'hFFFF_FFFF` | 32-bit compare target value |
| `0x010`–`0xFFC` | *Unimplemented* | — | — | `PSLVERR = 1'b1` on any read or write |

### 4.2 Register Bit Definitions

#### `TIMER_CTRL` (`0x000`, Reset: `32'h0000_0000`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:3` | `RSVD` | `RO` | `29'h0` | Reads `0`, writes ignored. |
| `2` | `CLR_CNT` | `WO/SC` | `1'b0` | Writing `1` clears `TIMER_COUNTER` to `32'h0` on that `PCLK` edge (self-clearing; always reads `0`). |
| `1` | `AUTO_RELOAD` | `RW` | `1'b0` | `1` = reload `COUNTER <= 32'h0` on compare match (`period = COMPARE + 1` cycles); `0` = free-running up-counter. |
| `0` | `EN` | `RW` | `1'b0` | `1` = `COUNTER` increments every `PCLK` cycle; `0` = `COUNTER` paused. |

#### `TIMER_STATUS` (`0x004`, Reset: `32'h0000_0000`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:2` | `RSVD` | `RO` | `30'h0` | Reads `0`, writes ignored. |
| `1` | `OVF` | `W1C` | `1'b0` | Sticky overflow flag (`1` when `EN == 1`, no reload/write/clear, and `COUNTER == 32'hFFFF_FFFF` wraps to `0`). Write `1` to clear. |
| `0` | `MATCH` | `W1C` | `1'b0` | Sticky compare-match flag (`1` when `EN == 1`, no `COUNTER` write/`CLR_CNT`, and `COUNTER == COMPARE`). Write `1` to clear. |

#### `TIMER_COUNTER` (`0x008`, Reset: `32'h0000_0000`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:0` | `COUNTER` | `RW` | `32'h0000_0000` | 32-bit counter. Writing sets `COUNTER <= PWDATA` directly on that `PCLK` edge (no simultaneous `+1` increment). |

#### `TIMER_COMPARE` (`0x00C`, Reset: `32'hFFFF_FFFF`)
| Bits | Field | Access | Reset | Description |
|---|---|---|---:|---|
| `31:0` | `COMPARE` | `RW` | `32'hFFFF_FFFF` | 32-bit compare threshold. Reset to `32'hFFFF_FFFF` to prevent spurious cycle-0 match when enabling `EN = 1`. |

### 4.3 Cycle-Accurate Precedence & Match Rules (`timer_apb`)
On every `posedge PCLK` (when `PRESETn == 1`):
1. **Counter Next-State Precedence (Highest to Lowest):**
   1. APB write to `TIMER_COUNTER` -> `COUNTER <= PWDATA` (suppresses match/overflow on that edge).
   2. APB write to `TIMER_CTRL` with `CLR_CNT == 1` -> `COUNTER <= 32'h0000_0000` (suppresses match/overflow on that edge).
   3. `EN == 1 && AUTO_RELOAD == 1 && (COUNTER == COMPARE)` -> `COUNTER <= 32'h0000_0000`, `MATCH <= 1'b1`.
   4. `EN == 1` (otherwise) -> `COUNTER <= COUNTER + 32'd1`; if `COUNTER == COMPARE`, `MATCH <= 1'b1`; if `COUNTER == 32'hFFFF_FFFF`, `OVF <= 1'b1`.
   5. `EN == 0` -> `COUNTER` holds steady.
2. **Status Flag Precedence:** If a hardware `MATCH` or `OVF` event occurs on the same `posedge PCLK` as an APB `W1C` write clearing that bit, the hardware event takes precedence (`bit <= 1'b1`).
3. **Timing:** A match detected while `COUNTER == COMPARE` at `T_k` latches `MATCH <= 1` at `T_k`, so `TIMER_STATUS[0]` reads as `1` starting in cycle `[T_k, T_{k+1})`.
