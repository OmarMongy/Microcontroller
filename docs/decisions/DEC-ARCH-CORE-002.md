# Human Engineering Decision — Modified Harvard Port B Timing, ROM Write Fault, and FENCE Ordering

- Decision ID: `DEC-ARCH-CORE-002`
- Date: 2026-11-27
- Topic: Final confirmation of core architecture sub-details (`IROM` Port B timing, `FAULT_DATA_RO_WRITE`, and `FENCE`)
- Related report/proposal: [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md), [REP-ARCH-002.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-ARCH-002.md)
- Status: `APPROVED`

## Options considered

1. **`irom_local` Port B Read Latency:** 1-cycle synchronous read (uniform with `dram_local` `Option RAM-B`) vs. 0-cycle combinational read.
2. **Fault Code for Stores to `IROM`:** Distinct fault code `4'hA` (`FAULT_DATA_RO_WRITE`) vs. reusing `FAULT_DATA_UNMAPPED`.
3. **RV32I `FENCE` Instruction Handling:** Valid single-cycle `NOP` (with preceding memory-transaction completion guarantee) vs. illegal instruction fault.

## Decision

1. **`IROM` Port B (`irom_local` Read-Only Data Port):** Approved as **1-cycle synchronous read**, matching `DRAM` `Option RAM-B` timing (2 cycles total per `.rodata` load; Port A instruction fetch remains 0-cycle combinational).
2. **`IROM` Store Attempts (`SB`, `SH`, `SW`):** Approved to raise **`FAULT_DATA_RO_WRITE`**, code **`4'hA`**, prioritized after `FAULT_DATA_UNMAPPED` and before size/alignment checks, suppressing all writes and halting the CPU.
3. **RV32I `FENCE`:** Approved as a **valid single-cycle `NOP`**, provided all preceding memory transactions (`DRAM`, `IROM` Port B, and `APB3`) have completed before retirement. *(Under the single-cycle in-order stall-on-wait architecture in `DEC-CPU-APB-WAIT-001` and `CON-MEM-001`/`CON-APB3-001`, every prior load/store completes before `PC` advances to fetch/retire `FENCE`.)*

## Rationale

- Matching `IROM` Port B and `DRAM` read timing keeps all local memory loads uniform (2 cycles) and prevents reintroducing a 32 KB combinational read mux into the single-cycle data critical path.
- Dedicated code `4'hA` (`FAULT_DATA_RO_WRITE`) makes ROM write violations immediately distinguishable from unmapped address faults during verification and debugging.
- Treating `FENCE` as a NOP after prior memory completion preserves full RV32I base-ISA compatibility for bare-metal C/assembly code without unnecessary traps/faults.

## Scope / files affected

- [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md)
- [ADDRESS_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/ADDRESS_MAP_CONTRACT.md) (`CON-ADDR-001`)
- [LOCAL_MEMORY_INTERFACE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/LOCAL_MEMORY_INTERFACE_CONTRACT.md) (`CON-MEM-001`)
- [FAULT_AND_RESET_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/FAULT_AND_RESET_CONTRACT.md) (`CON-FLT-RST-001`)
- [SOC_TOP_HIERARCHY_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/SOC_TOP_HIERARCHY_CONTRACT.md) (`CON-TOP-001`)

## Follow-up actions

1. Freeze `CON-ADDR-001`, `CON-MEM-001`, `CON-APB3-001`, `CON-FLT-RST-001`, and `CON-TOP-001` as `APPROVED`.
2. Task A (Architect): Prepare the detailed peripheral register-map proposals for `uart_apb`, `gpio_apb`, and `timer_apb`.
3. Task B (Independent Verification Engineer): Begin independent verification planning, SVA specification, coverage plan, and core verification firmware against the frozen core contracts (keeping peripheral-register verification `BLOCKED` until peripheral register maps are approved).
