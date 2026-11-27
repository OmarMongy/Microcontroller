# Task Report

- Report ID: `REP-ARCH-001`
- Date/time: `2026-11-27T12:44:32+02:00`
- Agent/role: Architect Agent
- Task: `ARCH-001` — Initial Architecture Proposal & Draft Interface Contracts (Address Map, Local Memory Interfaces, APB3 Bridge & Stall/Commit Timing, Fault Handling, Reset Behavior, Top-Level Hierarchy)
- Status: `REVIEW_REQUIRED`
- Relevant spec/interface revision: `docs/specifications/SOC_SPECIFICATION_DRAFT.md` (Draft 0.3); Draft Contracts `CON-ADDR-001`, `CON-MEM-001`, `CON-APB3-001`, `CON-FLT-RST-001`, `CON-TOP-001` (`PROPOSED`)
- Git branch/commit: `main` / `5562d37` (with uncommitted workspace changes)

## Work performed
1. Reviewed project rules (`AGENTS.md`, `.agents/agents/architect.md`), Draft 0.3 specification (`docs/specifications/SOC_SPECIFICATION_DRAFT.md`), open decisions (`docs/specifications/OPEN_DECISIONS.md`), initial proposal (`docs/architecture/INITIAL_ARCHITECTURE_PROPOSAL.md`), and approved decisions (`DEC-ARCH-BASELINE-001`, `DEC-ARCH-BASELINE-002`, `DEC-CPU-APB-WAIT-001`).
2. Read the human-supplied ARM AMBA APB specification PDF (`docs/specifications/references/IHI0024E_amba_apb_architecture_spec.pdf`) focusing on APB3 (Issue B / v1.0) signals (`Table B-1`), transfer phases (`Chapter 3`), operating states (`Chapter 4`), and signal validity rules (`Appendix A`).
3. Authored `docs/architecture/ARCHITECTURE_PROPOSAL_V1.md` and five draft interface contracts under `docs/interface_contracts/` covering all 7 required areas while preserving Harvard separation, keeping local memories off APB, excluding APB4/APB5 signals, and deferring individual peripheral register offsets/bit fields/reset values.
4. Verified no RTL files or verification/regression assets were created or modified.

### External Protocol Reference Metadata (per `docs/specifications/references/README.md`)
- **Exact document title:** `AMBA® APB Protocol Specification` (`ARM IHI 0024E`, `ID022823`)
- **Revision / version:** Issue E (document revision E); project applies **AMBA 3 APB Specification (Issue B / v1.0)**
- **Publication date:** 28 February 2023 (Issue E); APB3 Issue B release date shown in Change History is 17 August 2004
- **Source URL:** Direct download URL is not shown inside the PDF (the PDF references the Arm documentation portal `https://developer.arm.com/documentation` on p. ix and `http://www.arm.com` on p. iv)
- **Local filename:** `docs/specifications/references/IHI0024E_amba_apb_architecture_spec.pdf`
- **Applicable APB3 protocol version/features:** **APB3 (Issue B / v1.0)** per `Table B-1` (`PCLK`, `PRESETn`, `PADDR`, `PSELx`, `PENABLE`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`, `PSLVERR`). APB4 signals (`PPROT`, `PSTRB`) and APB5 signals (`PNSE`, `PWAKEUP`, `PAUSER`, `PWUSER`, `PRUSER`, `PBUSER`, `*CHK`) are marked `N` for APB3 in `Table B-1`/`B-2` and are strictly excluded.

## Files created/changed
- Created: [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md)
- Created: [ADDRESS_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/ADDRESS_MAP_CONTRACT.md)
- Created: [LOCAL_MEMORY_INTERFACE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/LOCAL_MEMORY_INTERFACE_CONTRACT.md)
- Created: [APB3_BRIDGE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/APB3_BRIDGE_CONTRACT.md)
- Created: [FAULT_AND_RESET_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/FAULT_AND_RESET_CONTRACT.md)
- Created: [SOC_TOP_HIERARCHY_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/SOC_TOP_HIERARCHY_CONTRACT.md)
- Created: [REP-ARCH-001.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-ARCH-001.md)

## Commands and tool versions
- Simulation / Lint / Synthesis: `NOT_RUN` (architecture documentation task only; no RTL exists).
- Workspace inspection commands run: `ls -la`, `git status --short`, `git branch -a`, `git log -1 --oneline`.

## Results and evidence paths
- Architecture proposal: `docs/architecture/ARCHITECTURE_PROPOSAL_V1.md`
- Draft contracts (`DRAFT / PROPOSED — PENDING HUMAN APPROVAL`):
  - `docs/interface_contracts/ADDRESS_MAP_CONTRACT.md` (`CON-ADDR-001`)
  - `docs/interface_contracts/LOCAL_MEMORY_INTERFACE_CONTRACT.md` (`CON-MEM-001`)
  - `docs/interface_contracts/APB3_BRIDGE_CONTRACT.md` (`CON-APB3-001`)
  - `docs/interface_contracts/FAULT_AND_RESET_CONTRACT.md` (`CON-FLT-RST-001`)
  - `docs/interface_contracts/SOC_TOP_HIERARCHY_CONTRACT.md` (`CON-TOP-001`)

## Assumptions / unresolved questions
Seven explicit human decisions are required (detailed in `docs/architecture/ARCHITECTURE_PROPOSAL_V1.md` Section 8):
1. **Strict Harvard vs. `.rodata` in C:** Whether data loads targeting `IROM` (`0x0000_0000`–`0x0000_7FFF`) fault (`FAULT_DATA_UNMAPPED`) or whether a read-only `IROM` data port (Modified Harvard) is desired for bare-metal C `.rodata`.
2. **Local `DRAM` Read Latency:** Approve Option RAM-A (0-cycle combinational read, pure 1-cycle local instructions) or Option RAM-B (1-cycle synchronous read, +1 wait state on `DRAM` loads for shorter generic synthesis critical path).
3. **Address Map & APB3 Subranges:** Approve `IROM` (`0x0000_0000`–`0x0000_7FFF`), `DRAM` (`0x2000_0000`–`0x2000_7FFF`), `APB3` (`0x4000_0000`–`0x4000_FFFF` with 4 KB slots for UART/GPIO/Timer and fault on reserved slots `0x4000_3000`–`0x4000_FFFF`).
4. **APB3 Sub-Word / Unaligned Policy:** Approve Option APB-W1 (32-bit aligned `LW`/`SW` only on APB3; sub-word/unaligned APB accesses fault, avoiding `PSTRB` absence hazards).
5. **APB3 Bridge Timing:** Approve Design 4A (registered APB3 outputs, 3-cycle minimum 0-wait transfer) over Design 4B (combinational `SETUP`, 2-cycle minimum).
6. **Reset Synchronizer & RF/DRAM Reset:** Approve Option RST-A (2-FF async-assert / sync-deassert reset synchronizer), reset of `x1..x31` to `0`, and no hardware reset tree on the 32 KB `DRAM` array.
7. **Top-Level Pinout:** Approve split `gpio_i`/`gpio_o`/`gpio_oe_o` (vs `inout`) and exposing `fault_pc_o`/`fault_addr_o`/`fault_insn_o` alongside `fault_o` and `fault_code_o[3:0]` on `soc_top`.

## Recommended next action
1. **Main Orchestrator:** Present `ARCHITECTURE_PROPOSAL_V1.md` (Section 8 decision list) and draft contracts to the human for Gate 1 review and decision recording under `docs/decisions/`.
2. **Architect (after human approval of top-level regions):** Execute the deferred peripheral register-map architecture task for `uart_apb`, `gpio_apb`, and `timer_apb`.
