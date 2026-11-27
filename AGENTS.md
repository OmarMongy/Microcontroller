# Project Instructions — AI-Assisted RV32I Microcontroller SoC

## Mission
Design, implement, verify, and evaluate a small educational microcontroller SoC based on a single-cycle RV32I CPU. Keep the design intentionally simple. The human is the technical owner and final decision-maker.

## Current approved direction
- CPU: single-cycle, 32-bit RV32I for ordinary instructions.
- Memory organization: Harvard, with separate instruction ROM and data RAM; each is 32 KB.
- Reset vector: `0x0000_0000`; instruction ROM must cover this address.
- Program image: instruction ROM initialized from `.hex` or `.mem`.
- Peripheral interconnect: AMBA APB3; UART, 8-bit GPIO, and 32-bit timer.
- APB peripheral accesses may wait for multiple cycles; CPU holds the current instruction until completion and commits exactly once.
- Local instruction ROM and data RAM use dedicated simple local memory interfaces, NOT APB. APB3 is for memory-mapped peripherals.
- Clock: one shared 50 MHz clock for CPU, memories, APB bridge, and peripherals.
- External reset: active-low asynchronous; internal reset-release behavior remains to be specified.
- Fault policy: invalid/misaligned accesses, illegal instructions/ECALL/EBREAK, and APB `PSLVERR` produce visible fault status and halt the CPU. This is not privileged RISC-V trap support.
- Firmware: bare-metal assembly and C. Verification firmware/test programs are authored and owned by the Verification Engineer; separate demonstration firmware may be developed later as a software/demo task.
- Initial implementation: RTL simulation and generic synthesis; no FPGA target initially. Directed verification and SVA.

## Specification authority and reference documents
- Read `docs/specifications/SOC_SPECIFICATION_DRAFT.md` and `docs/specifications/OPEN_DECISIONS.md` first.
- The human may add the downloaded official ARM AMBA APB specification under `docs/specifications/references/`. Treat the exact document/version supplied by the human as the protocol reference for APB behavior. Do not silently substitute APB4/AXI or assume features not present in APB3.
- Read `docs/architecture/INITIAL_ARCHITECTURE_PROPOSAL.md` as a proposal, not a frozen contract.
- Do not begin RTL until the human approves the detailed architecture/interface contracts and the verification plan/baseline.

## Address map and register-map policy
- Architect must propose separate, non-overlapping address regions for instruction ROM, data RAM, and the APB peripheral window, plus UART/GPIO/timer peripheral subranges.
- The address-region proposal is in the current architecture task and requires explicit human approval.
- Individual UART/GPIO/timer register offsets and bit-level register semantics are deliberately deferred to a later focused task. Do not invent or freeze them in the initial address-region proposal.
- The Architect may optionally include clearly marked illustrative register-map examples, but they are not binding and should be omitted unless useful.
- Harvard means separate instruction-fetch and data-access paths. Do not casually convert the design to a unified Von Neumann memory interface. Explain any proposal that changes this.

## Memory-interface policy
- Instruction ROM: dedicated local instruction-fetch interface; propose its read timing and initialization behavior.
- Data RAM: dedicated local data-memory interface with byte-write enables; propose read latency, write timing, little-endian behavior, and alignment rules.
- APB3: used only for memory-mapped peripherals through the APB bridge.
- The Architect must recommend the simplest local memory timing compatible with the approved single-cycle CPU behavior and generic synthesis goals. Do not assume inferred FPGA block-RAM behavior or a particular ASIC SRAM macro.
- Any proposal that introduces extra CPU wait states for local RAM must explain the impact and request human approval.

## Agent roles
1. Main Orchestrator: decomposes work, assigns tasks, manages dependencies, collects reports, and presents decisions to the human.
2. Architect: proposes microarchitecture, module hierarchy, address regions, and interface contracts. Does not implement RTL unless explicitly assigned.
3. RTL Designer: implements only approved RTL contracts. Does not edit protected verification assets.
4. Independent Verification Engineer: derives verification from approved requirements/contracts and owns verification test firmware, testbench, reference models, SVA, and coverage.

## Firmware ownership
- Verification Engineer writes small assembly and/or bare-metal C programs used as verification stimuli, including expected outcomes and test IDs. These are verification assets and must be stored separately from product/demo firmware (recommended `verification/firmware/` or an explicitly agreed equivalent).
- The verification program author must derive expected results from the approved specification, not from observed RTL behavior. Record compiler/assembler version, flags, linker script, image-conversion command, and generated image hash/path.
- Verification firmware is not automatically a complete user demonstration suite. Separate demo applications can be authored later under a separate software task and reviewed by the human.
- RTL Designer must not modify verification firmware, testbench, SVA, reference models, expected-result data, or coverage assets.
- If a firmware test exposes an ambiguity, stop and report `SPECIFICATION_AMBIGUITY`; do not resolve it by changing the expected result.

## Communication and reporting protocol
Agents do not communicate automatically merely because their prompts say so. The Orchestrator must explicitly delegate, attach report content/paths, and collect the response using supported Antigravity orchestration features.

### Required failure workflow
1. Verification Engineer runs the approved baseline and records commands, tool versions, test IDs, logs, and results.
2. On failure, it creates a detailed report under `regression/investigations/`.
3. It reports to the Orchestrator; it does not change RTL or silently redefine expected behavior.
4. Orchestrator presents report and evidence to the human.
5. Only after explicit human authorization may Orchestrator forward the report/evidence to RTL Designer.
6. RTL Designer investigates and submits diagnosis/proposed patch; it does not edit verification assets.
7. Human reviews and approves/rejects the patch.
8. After approved integration, Orchestrator requests a rerun against the same frozen baseline.
9. Preserve the earlier failure record even if the rerun passes.

### Failure classification
Use: `RTL_DEFECT`, `VERIFICATION_DEFECT_SUSPECTED`, `SPECIFICATION_AMBIGUITY`, `INFRASTRUCTURE_ERROR`, `INCONCLUSIVE`, or `NOT_CLASSIFIED`. Do not claim a suspected cause is confirmed without evidence.

### Required reports
- Task report: `reports/`
- Verification run report: `regression/runs/`
- Failure investigation: `regression/investigations/`
- RTL change proposal: `reports/`
- Human decision record: `docs/decisions/`
Use `docs/templates/`. Every report identifies report ID/date, agent role, task/scope, spec/interface revision, Git commit or `UNCOMMITTED`, baseline ID where relevant, commands/tool versions, evidence paths, status, unresolved questions, and next owner/action.

## Human approval gates
Human approval is required before freezing/changing specification, architecture, address map, interface contracts, verification baseline, protected verification assets, RTL patches, merges to `main`, or final sign-off. Approval for one action does not imply approval for later actions.

## Verification independence and protection
- Verification derives from approved requirements/contracts, not implementation details; plan and expected behavior before inspecting RTL wherever practical.
- Baseline IDs are immutable (e.g. `SOC_VB_001`). A changed approved baseline gets a new ID.
- A failing test is not permission to weaken/delete/bypass it. Any suspected verification defect requires evidence and a human-approved change proposal.

## Nine engineering gates
1. Specification & Architecture
2. RTL Implementation
3. Lint & Compilation
4. Verification Development
5. Simulation
6. Synthesis
7. Debugging & Fixes
8. Regression Rerun
9. Final Review

Do not skip gates or claim a gate passed without evidence.

## Git and file ownership
- `main` contains human-approved integrated states; use feature branches where practical.
- Review `git status`, `git diff`, and `git diff --staged` before commits.
- Never run destructive Git commands or force-push without explicit approval.
- Commit source, specs, contracts, verification assets, scripts, and curated reports; exclude generated builds, caches, and large waveforms by default.
- Do not claim GitHub push, tests, lint, or synthesis succeeded unless verified.

## Efficiency and completion report
Use the fewest agents needed; avoid parallel work with unresolved dependencies. Each task ends with status, changed files, commands/results (or `NOT_RUN`), evidence paths, Git state, unresolved questions, and next action.
