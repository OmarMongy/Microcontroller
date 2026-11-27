# Human Engineering Decision — Core Architecture, Address Map, Memory Timing, and Top-Level Pinout

- Decision ID: `DEC-ARCH-CORE-001`
- Date: 2026-11-27
- Topic: Approval of core architecture selections (Decisions #1–#7 from `ARCH-PROP-001`)
- Related report/proposal: [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md), [REP-ARCH-001.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-ARCH-001.md)
- Status: `APPROVED`

## Options considered

1. **Harvard Mode (Decision #1):** Strict Harvard (`IROM` inaccessible on data path) vs. **Modified Harvard** (read-only data port on `IROM` for `.rodata` loads).
2. **Local `DRAM` Read Timing (Decision #2):** Option RAM-A (0-cycle combinational read) vs. **Option RAM-B** (1-cycle synchronous read, +1 wait state on `DRAM` loads).
3. **Top-Level Address Map & APB3 Subranges (Decision #3):** `IROM` (`0x0000_0000`–`0x0000_7FFF`), `DRAM` (`0x2000_0000`–`0x2000_7FFF`), `APB3` (`0x4000_0000`–`0x4000_FFFF` with 4 KB slots for UART `0x4000_0000`, GPIO `0x4000_1000`, Timer `0x4000_2000`, and reserved `0x4000_3000`–`0x4000_FFFF` faulting).
4. **APB3 Sub-Word / Unaligned Access Policy (Decision #4):** **Option APB-W1** (32-bit aligned `LW`/`SW` only on APB3) vs. APB-W2 / APB-W3.
5. **APB3 Bridge Timing (Decision #5):** **Design 4A** (registered APB3 outputs, 3-cycle minimum 0-wait transfer) vs. Design 4B (combinational `SETUP`).
6. **Reset Synchronizer & RF/DRAM Reset (Decision #6):** **Option RST-A** (2-FF async-assert / sync-deassert reset synchronizer, `x1..x31` reset to `0`, no hardware `rst_n` tree on 32 KB `DRAM` array) vs. Option RST-B.
7. **Top-Level Pinout (Decision #7):** Split `gpio_i[7:0]`, `gpio_o[7:0]`, `gpio_oe_o[7:0]` vs. `inout`, and exposing `fault_o`, `fault_code_o`, `fault_pc_o`, `fault_addr_o`, `fault_insn_o` on `soc_top`.

## Decision

1. **Modified Harvard approved:** Add a read-only data access path to `IROM` (`0x0000_0000`–`0x0000_7FFF`) so bare-metal C programs can load `.rodata` constants; stores (`SB`/`SH`/`SW`) to `IROM` remain forbidden and must fault.
2. **Option RAM-B approved:** Use **1-cycle synchronous read** (1 wait state = 2 cycles total per `DRAM` load) and 1-cycle synchronous byte-enabled write on `dram_local`.
3. **Top-Level Address Map & APB3 Subranges approved:** Freeze `IROM` (`0x0000_0000`–`0x0000_7FFF`), `DRAM` (`0x2000_0000`–`0x2000_7FFF`), and `APB3` (`0x4000_0000`–`0x4000_FFFF` with 4 KB slots for UART, GPIO, Timer; slots 3–15 fault).
4. **Option APB-W1 approved:** Only 32-bit aligned `LW`/`SW` are valid on APB3; sub-word or unaligned APB3 accesses fault prior to initiating an APB transfer.
5. **Design 4A approved:** Registered APB3 bridge (`IDLE -> SETUP -> ACCESS`, 3-cycle minimum 0-wait transfer) with `cpu_stall` hold and single commit on `ACCESS && PREADY`.
6. **Option RST-A approved:** 2-FF asynchronous-assert / synchronous-deassert reset synchronizer (`sys_rst_n` / `PRESETn`), `x1..x31` reset to `0`, no hardware reset tree on the 32 KB `DRAM` array.
7. **Top-Level Pinout approved:** Use split `input logic [7:0] gpio_i`, `output logic [7:0] gpio_o`, `output logic [7:0] gpio_oe_o` (instead of `inout`), and expose `fault_o`, `fault_code_o`, `fault_pc_o`, `fault_addr_o`, `fault_insn_o` at `soc_top`.

## Rationale

- Modified Harvard enables standard bare-metal C `.rodata` placement in ROM without duplicating read-only constants into RAM.
- Option RAM-B avoids an 8192:1 combinational 32 KB read mux on the single-cycle critical path during generic synthesis, at a controlled +1 wait-state cost on `DRAM` loads.
- Option APB-W1, Design 4A, and Option RST-A prioritize strict APB3 compliance (no `PSTRB`), glitch-free registered bus outputs, and safe reset release.
- Split GPIO ports avoid bidirectional `inout` complications in generic synthesis/simulation, and full fault observability simplifies directed verification and SVA.

## Scope / files affected

- [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md)
- [ADDRESS_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/ADDRESS_MAP_CONTRACT.md) (`CON-ADDR-001`)
- [LOCAL_MEMORY_INTERFACE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/LOCAL_MEMORY_INTERFACE_CONTRACT.md) (`CON-MEM-001`)
- [APB3_BRIDGE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/APB3_BRIDGE_CONTRACT.md) (`CON-APB3-001`)
- [FAULT_AND_RESET_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/FAULT_AND_RESET_CONTRACT.md) (`CON-FLT-RST-001`)
- [SOC_TOP_HIERARCHY_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/SOC_TOP_HIERARCHY_CONTRACT.md) (`CON-TOP-001`)

## Follow-up actions

1. Architect updates `ARCHITECTURE_PROPOSAL_V1.md` and `CON-*-001` contracts to reflect **Modified Harvard** (`irom_local` read-only data port + store-to-ROM fault) and **Option RAM-B** (1-cycle synchronous `DRAM` read + 1-cycle stall timing), and locks approved Decisions #3–#7.
2. Architect prepares the deferred peripheral register-map specification (`uart_apb`, `gpio_apb`, `timer_apb`) upon human authorization.
3. Verification Engineer develops the independent verification plan, verification firmware, and SVA from the approved contracts before RTL begins.
