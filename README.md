# AI-Assisted RV32I Microcontroller SoC

Educational RTL design and verification project for a single-cycle RV32I-based microcontroller SoC.

## Current approved direction
- Single-cycle 32-bit RV32I CPU.
- Harvard organization: 32 KB instruction ROM and 32 KB data RAM.
- Dedicated local interfaces for instruction ROM and data RAM; APB3 is reserved for memory-mapped peripherals.
- APB3 peripheral window containing UART, 8-bit GPIO, and 32-bit timer.
- 50 MHz shared clock; active-low asynchronous external reset.
- Bare-metal C and assembly; verification test firmware owned by the Verification Engineer.
- RTL simulation and generic synthesis initially; directed tests and SVA; no initial FPGA target.

## Start here
1. Read `AGENTS.md` and `.agents/agents/README.md`.
2. Read `docs/specifications/SOC_SPECIFICATION_DRAFT.md` and `docs/specifications/OPEN_DECISIONS.md`.
3. Add the official ARM AMBA APB specification downloaded by the human under `docs/specifications/references/` (see its README). Do not include a copyrighted copy in generated project packages unless the human chooses to add it locally.
4. Use `START_PROJECT_PROMPT.md` as the initial prompt in Google Antigravity.
5. Complete the architecture proposal and obtain human approval before interface freeze or RTL implementation.
6. Have the Verification Engineer prepare independent tests and verification firmware from the approved contracts. Freeze a baseline only after human approval.
7. Follow the nine engineering gates in `AGENTS.md`.

## Important boundaries
- The Architect proposes the top-level address regions now. The human approves them.
- UART/GPIO/timer register offsets and bit-level semantics are deferred to a later task; do not invent them in the address-region proposal.
- Instruction ROM/data RAM do not use APB. Their local interface timing must be specified separately.
- Verification test firmware is distinct from later demo firmware.
- This repository contains workflow/specification material, not completed CPU/SoC RTL. Do not claim implementation or test results without evidence.
