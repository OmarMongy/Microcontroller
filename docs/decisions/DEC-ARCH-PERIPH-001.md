# Human Engineering Decision — Peripheral Register-Map Specification (`UART`, `GPIO`, `Timer`)

- Decision ID: `DEC-ARCH-PERIPH-001`
- Date: 2026-11-27
- Topic: Approval of peripheral register maps, polling semantics, `PSLVERR` rules, and input synchronization (`#P1`–`#P5`)
- Related report/proposal: [PERIPHERAL_REGISTER_PROPOSAL.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/PERIPHERAL_REGISTER_PROPOSAL.md) (`ARCH-PROP-002`), [REP-ARCH-003.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-ARCH-003.md)
- Status: `APPROVED`

## Options considered

1. **Cross-Peripheral `PSLVERR` Policy (`#P1`):** Strict Option P-ERR1 (`PSLVERR = 1` on unimplemented offsets, `RO` writes, `WO` reads, `UART_BAUD_DIV < 2`) vs. Option P-ERR2 (permissive `RO`/`WO`).
2. **UART Baud Divider (`#P2`):** 24-bit bit-period divider `BAUD_DIV` (default `434` -> `+0.0064%` error @ 50 MHz, mid-bit start sampling `BAUD_DIV >> 1`, valid `>= 2`) vs. 16x oversampling (`27`, `+0.469%` error).
3. **UART Buffering & TX-Busy Write (`#P3`):** 1-entry TX/RX holding registers (`TX_EN=1, RX_EN=1` at reset, polling `TX_EMPTY`/`RX_VALID`, ignore write while `TX_BUSY == 1`) vs. multi-byte FIFO or `PSLVERR` on TX-busy write.
4. **GPIO Register Set (`#P4`):** Minimal 3-register map (`GPIO_DATA_IN`, `GPIO_DATA_OUT`, `GPIO_DIR`) with 2-FF `gpio_i` synchronizer vs. adding `OUT_SET`/`OUT_CLR`.
5. **Timer Register Set & Match Semantics (`#P5`):** 4-register map (`TIMER_CTRL`, `TIMER_STATUS`, `TIMER_COUNTER`, `TIMER_COMPARE` reset `32'hFFFF_FFFF`) with `AUTO_RELOAD` (`COMPARE + 1` period), `CLR_CNT`, and `W1C` `MATCH`/`OVF`.

## Decision

1. **`#P1` Approved (Option P-ERR1):** Strict `PSLVERR = 1'b1` on unimplemented `PADDR[11:0]` offsets within each 4 KB peripheral slot, writes to `RO` registers, reads from `WO` registers, and `UART_BAUD_DIV < 2`. Reserved bits read `0` and ignore writes without asserting `PSLVERR`. All peripherals return `PREADY = 1'b1`.
2. **`#P2` Approved:** 24-bit bit-period divider `UART_BAUD_DIV` (`reset = 24'd434`, `115,207.37` baud @ 50 MHz, `+0.0064%` error), valid `>= 2`, with 2-FF `uart_rx_i` synchronizer and mid-bit start sampling at `BAUD_DIV >> 1`.
3. **`#P3` Approved:** 1-entry TX and RX holding registers (`UART_CTRL` resets `TX_EN=1, RX_EN=1`; `UART_STATUS` resets `TX_EMPTY=1`); writes to `UART_TX_DATA` while `TX_BUSY == 1` or `TX_EN == 0` are ignored without `PSLVERR`; `RX_OVERRUN` and `RX_FRAME_ERR` are sticky `W1C` flags.
4. **`#P4` Approved:** Minimal 3-register GPIO map (`GPIO_DATA_IN`, `GPIO_DATA_OUT`, `GPIO_DIR`) with 2-FF `gpio_i[7:0]` synchronizer (all inputs at reset: `gpio_oe_o = 8'h00`, `gpio_o = 8'h00`).
5. **`#P5` Approved:** 4-register Timer map (`TIMER_CTRL`, `TIMER_STATUS`, `TIMER_COUNTER`, `TIMER_COMPARE` reset `32'hFFFF_FFFF`) with `AUTO_RELOAD` (`COMPARE + 1` tick period), `CLR_CNT` self-clearing reset, `W1C` `MATCH`/`OVF` flags, and hardware-event precedence on concurrent `W1C`.

## Rationale

- Strict `PSLVERR` rules catch software register-access mistakes immediately under the approved fault-and-halt policy.
- Bit-period `BAUD_DIV = 434` provides +0.0064% baud accuracy at 50 MHz with minimal hardware and fast simulation scaling.
- Minimal 1-entry UART buffers, 3-register GPIO, and 4-register Timer keep educational RTL simple while supporting all planned polling demonstrations and verification tests.

## Scope / files affected

- [PERIPHERAL_REGISTER_PROPOSAL.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/PERIPHERAL_REGISTER_PROPOSAL.md) (`ARCH-PROP-002`)
- [PERIPHERAL_REGISTER_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/PERIPHERAL_REGISTER_MAP_CONTRACT.md) (`CON-PERIPH-001` v1.0 — now `APPROVED`)

## Follow-up actions

1. Freeze `CON-PERIPH-001` (`PERIPHERAL_REGISTER_MAP_CONTRACT.md`) as `APPROVED`.
2. Unblock peripheral register-level verification (`VER-UART-*`, `VER-GPIO-*`, `VER-TIMER-*`, `VER-PERIPH-INT-001`) so the Verification Engineer can extend `SOC_VB_001` into `SOC_VB_002` upon human authorization.
3. Proceed to Gate 2 (RTL implementation) and Gate 4 (verification harness development) upon explicit human authorization.
