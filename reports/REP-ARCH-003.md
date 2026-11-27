# Task Report

- Report ID: `REP-ARCH-003`
- Date/time: `2026-11-27T13:15:00+02:00`
- Agent/role: Architect Agent
- Task: `ARCH-003` (Task A) — Detailed Peripheral Register-Map Specification (`uart_apb`, `gpio_apb`, `timer_apb`)
- Status: `REVIEW_REQUIRED`
- Relevant spec/interface revision: `docs/specifications/SOC_SPECIFICATION_DRAFT.md` (Draft 0.3); Frozen Core Contracts `CON-ADDR-001`, `CON-APB3-001`, `CON-TOP-001`; Proposed `ARCH-PROP-002` & `CON-PERIPH-001` (`v1.0`)
- Git branch/commit: `main` / `5562d37` (with uncommitted workspace changes)

## Work performed
1. Reviewed [DEC-ARCH-CORE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-002.md) and the frozen core contracts (`CON-ADDR-001`, `CON-APB3-001`, `CON-TOP-001`).
2. Authored [PERIPHERAL_REGISTER_PROPOSAL.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/PERIPHERAL_REGISTER_PROPOSAL.md) (`ARCH-PROP-002`) covering design choices, baud-rate divisor math (`50 MHz / 434 = 115,207.37 Hz`, `+0.0064%` error vs 16x oversampling `+0.469%`), 2-FF input synchronizers, buffering/polling policies, `PREADY`/`PSLVERR` consistency rules, and 5 explicit human decision items (`#P1`–`#P5`).
3. Authored [PERIPHERAL_REGISTER_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/PERIPHERAL_REGISTER_MAP_CONTRACT.md) (`CON-PERIPH-001` v1.0, `DRAFT / PROPOSED — PENDING HUMAN APPROVAL`) defining word-aligned register offsets, bit fields, access permissions, reset values, cycle-accurate timer precedence, and APB3 `PREADY`/`PSLVERR` rules for:
   - `uart_apb` (`0x4000_0000`–`0x4000_0FFF`): `UART_CTRL`, `UART_STATUS`, `UART_TX_DATA`, `UART_RX_DATA`, `UART_BAUD_DIV`
   - `gpio_apb` (`0x4000_1000`–`0x4000_1FFF`): `GPIO_DATA_IN`, `GPIO_DATA_OUT`, `GPIO_DIR`
   - `timer_apb` (`0x4000_2000`–`0x4000_2FFF`): `TIMER_CTRL`, `TIMER_STATUS`, `TIMER_COUNTER`, `TIMER_COMPARE`
4. Verified no RTL files or verification/regression assets were created or modified.

## Files created/changed
- Created: [PERIPHERAL_REGISTER_PROPOSAL.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/PERIPHERAL_REGISTER_PROPOSAL.md) (`ARCH-PROP-002`)
- Created: [PERIPHERAL_REGISTER_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/PERIPHERAL_REGISTER_MAP_CONTRACT.md) (`CON-PERIPH-001` `v1.0`, `PROPOSED`)
- Created: [REP-ARCH-003.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-ARCH-003.md)

## Commands and tool versions
- Simulation / Lint / Synthesis: `NOT_RUN` (architecture documentation task only; no RTL exists).

## Results and evidence paths
- Peripheral design proposal: `docs/architecture/PERIPHERAL_REGISTER_PROPOSAL.md`
- Draft peripheral register-map contract: `docs/interface_contracts/PERIPHERAL_REGISTER_MAP_CONTRACT.md`

## Assumptions / unresolved questions
Five explicit human decisions required (detailed in `PERIPHERAL_REGISTER_PROPOSAL.md` Section 6):
1. **Decision #P1 (Cross-Peripheral `PSLVERR` Policy):** Approve strict Option P-ERR1 (unimplemented offsets, `RO` writes, `WO` reads, and `UART_BAUD_DIV < 2` assert `PSLVERR = 1`; reserved bits read `0`/ignore writes) vs. Option P-ERR2 (permissive `RO`/`WO`).
2. **Decision #P2 (UART Baud Divider):** Approve 24-bit bit-period divider (`BAUD_DIV = 434` default -> `+0.0064%` error @ 50 MHz, mid-bit start sampling `BAUD_DIV >> 1`, valid `>= 2`) vs. 16x oversampling (`27`, `+0.469%` error).
3. **Decision #P3 (UART Buffering & TX-Busy Write):** Approve 1-entry TX/RX holding registers (TX/RX enabled at reset, polling `TX_EMPTY`/`RX_VALID`, ignore write while `TX_BUSY == 1`) vs. FIFO or `PSLVERR` on TX-busy write.
4. **Decision #P4 (GPIO Register Set):** Approve minimal 3-register map (`GPIO_DATA_IN`, `GPIO_DATA_OUT`, `GPIO_DIR`) with 2-FF `gpio_i` synchronizer vs. adding `OUT_SET`/`OUT_CLR`.
5. **Decision #P5 (Timer Register Set & Match Semantics):** Approve 4-register map (`TIMER_CTRL`, `TIMER_STATUS`, `TIMER_COUNTER`, `TIMER_COMPARE` reset `32'hFFFF_FFFF`) with `AUTO_RELOAD` (`COMPARE + 1` period), `CLR_CNT`, and `W1C` `MATCH`/`OVF`.

## Recommended next action
1. **Main Orchestrator:** Present `ARCH-PROP-002` (Decisions `#P1`–`#P5`) and `CON-PERIPH-001` to the human for review and approval.
2. **Verification Engineer:** Upon human approval of `CON-PERIPH-001`, complete the peripheral portion of the independent verification plan, SVA, and verification firmware.
