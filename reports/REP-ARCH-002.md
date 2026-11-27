# Task Report

- Report ID: `REP-ARCH-002`
- Date/time: `2026-11-27T13:06:00+02:00`
- Agent/role: Architect Agent
- Task: `ARCH-002` — Update Architecture Proposal & Interface Contracts per Approved [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md)
- Status: `REVIEW_REQUIRED`
- Relevant spec/interface revision: `docs/specifications/SOC_SPECIFICATION_DRAFT.md` (Draft 0.3); `ARCH-PROP-001` V1.1; `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1 (`APPROVED`), `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1
- Git branch/commit: `main` / `5562d37` (with uncommitted workspace changes)

## Work performed
1. Read [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) approving Decisions #1–#7 (Modified Harvard, Option RAM-B, Top-Level Address Map & APB3 4 KB slots, Option APB-W1, Design 4A, Option RST-A, split GPIO + full fault observability pinout).
2. Updated all five draft interface contracts under `docs/interface_contracts/` to `v1.1`:
   - `CON-ADDR-001` (`ADDRESS_MAP_CONTRACT.md`): Updated `IROM` data permission to read-only (`LB/LBU/LH/LHU/LW`; `STORE` faults with `FAULT_DATA_RO_WRITE`) and added `data_in_irom` decode logic.
   - `CON-MEM-001` (`LOCAL_MEMORY_INTERFACE_CONTRACT.md`): Added `irom_local` Port B (`clk`, `sys_rst_n`, `irom_dreq`, `irom_daddr[14:0]`, `irom_drdata[31:0]`) with 1-cycle synchronous read timing (keeping Port A 0-cycle combinational); promoted `Option RAM-B` (1-cycle synchronous read = 2 cycles total per load, 1-cycle synchronous byte-enabled write) to the primary `dram_local` contract with cycle-accurate timing diagram and `local_rd_valid` / `local_read_stall` handshake.
   - `CON-APB3-001` (`APB3_BRIDGE_CONTRACT.md`): Updated status to `APPROVED (DEC-ARCH-CORE-001)` and clarified `dmem_stall = (local_read_stall || apb_stall) && !fault_valid` coexistence.
   - `CON-FLT-RST-001` (`FAULT_AND_RESET_CONTRACT.md`): Added `4'hA` `FAULT_DATA_RO_WRITE` in the fault code table and priority list, and updated `irom_local` Port B / `dram_local` synchronous read output register reset values.
   - `CON-TOP-001` (`SOC_TOP_HIERARCHY_CONTRACT.md`): Updated block diagram, module table, approved `soc_top` port list (`gpio_i`/`gpio_o`/`gpio_oe_o` and `fault_*_o`), and `dmem_stall` / `dmem_fault_code` descriptions.
3. Updated `docs/architecture/ARCHITECTURE_PROPOSAL_V1.md` to `V1.1` with a clear `DEC-ARCH-CORE-001` approval banner, updated Modified Harvard + RAM-B baseline, and a concise list of 3 remaining quick confirmation items.
4. Verified no RTL files or verification/regression assets were created or modified.

## Files created/changed
- Modified: [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md) (`V1.1`)
- Modified: [ADDRESS_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/ADDRESS_MAP_CONTRACT.md) (`CON-ADDR-001` `v1.1`)
- Modified: [LOCAL_MEMORY_INTERFACE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/LOCAL_MEMORY_INTERFACE_CONTRACT.md) (`CON-MEM-001` `v1.1`)
- Modified: [APB3_BRIDGE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/APB3_BRIDGE_CONTRACT.md) (`CON-APB3-001` `v1.1` — `APPROVED`)
- Modified: [FAULT_AND_RESET_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/FAULT_AND_RESET_CONTRACT.md) (`CON-FLT-RST-001` `v1.1`)
- Modified: [SOC_TOP_HIERARCHY_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/SOC_TOP_HIERARCHY_CONTRACT.md) (`CON-TOP-001` `v1.1`)
- Created: [REP-ARCH-002.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-ARCH-002.md)

## Commands and tool versions
- Simulation / Lint / Synthesis: `NOT_RUN` (architecture documentation task only; no RTL exists).

## Results and evidence paths
- Updated proposal: `docs/architecture/ARCHITECTURE_PROPOSAL_V1.md`
- Updated contracts:
  - `docs/interface_contracts/ADDRESS_MAP_CONTRACT.md`
  - `docs/interface_contracts/LOCAL_MEMORY_INTERFACE_CONTRACT.md`
  - `docs/interface_contracts/APB3_BRIDGE_CONTRACT.md` (`APPROVED`)
  - `docs/interface_contracts/FAULT_AND_RESET_CONTRACT.md`
  - `docs/interface_contracts/SOC_TOP_HIERARCHY_CONTRACT.md`

## Assumptions / unresolved questions
Three quick confirmation items remain (detailed in `ARCHITECTURE_PROPOSAL_V1.md` Section 8):
1. Confirm **1-cycle synchronous read** on `irom_local` Port B (uniform with `dram_local` `Option RAM-B`, 2 cycles per `.rodata` load) vs. 0-cycle combinational Port B read.
2. Confirm fault code **`4'hA` `FAULT_DATA_RO_WRITE`** for `SB`/`SH`/`SW` stores targeting read-only `IROM`.
3. Confirm treating RV32I **`FENCE`** as a valid single-cycle `NOP`.

*(Note: Individual UART, GPIO, and Timer register offsets, bit fields, reset values, and FIFO policies remain deferred to the next focused architecture task.)*

## Recommended next action
1. **Main Orchestrator / Human:** Confirm the 3 minor sub-details above (or authorize the deferred peripheral register-map architecture task `ARCH-003` for `uart_apb`, `gpio_apb`, and `timer_apb`).
2. **Verification Engineer:** Begin planning independent directed verification tests and SVA properties against `CON-APB3-001` (`APPROVED`) and the updated `v1.1` core contracts once confirmed.
