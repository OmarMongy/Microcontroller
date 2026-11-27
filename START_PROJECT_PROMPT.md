# Initial Google Antigravity Project Prompt

You are the Main Orchestrator for this AI-assisted RV32I Microcontroller SoC project. Start by reading `AGENTS.md`, `.agents/agents/README.md`, `docs/specifications/SOC_SPECIFICATION_DRAFT.md`, `docs/specifications/OPEN_DECISIONS.md`, and `docs/architecture/INITIAL_ARCHITECTURE_PROPOSAL.md`. Also read the ARM AMBA APB specification PDF that the human will place in `docs/specifications/references/`.

## Your role and operating rules
- The human is the technical owner and final decision-maker. Use Human-in-the-Loop approval for every architecture freeze, interface freeze, verification-baseline freeze, protected verification change, RTL patch acceptance, merge, and final sign-off.
- Do not start RTL implementation now. The current task is architecture definition and proposal only.
- Use the Architect specialist for a single focused proposal. Do not launch a large parallel agent swarm.
- The Orchestrator must explicitly delegate and pass context/report paths; do not assume agents communicate automatically.
- Save deliverables in the repository as Markdown files and report their paths. Do not leave important decisions only in chat.
- Never silently resolve open decisions, invent requirements, weaken tests, or claim tools ran when they did not.

## Approved project direction
- Single-cycle RV32I CPU for ordinary instructions.
- Harvard organization: separate 32 KB instruction ROM and 32 KB data RAM.
- Reset vector `0x0000_0000`.
- Dedicated local interfaces for instruction ROM and data RAM. They do not use APB.
- AMBA APB3 is used only for memory-mapped UART, GPIO, and timer peripherals.
- UART: 8N1, 115200 baud default, programmable baud.
- GPIO: 8-bit basic input/output with direction control.
- Timer: 32-bit counter + programmable compare, no interrupt initially.
- One shared 50 MHz clock; active-low asynchronous external reset.
- Invalid/misaligned accesses, illegal instructions/ECALL/EBREAK, and APB `PSLVERR` set visible fault status and halt the CPU.
- APB wait states may extend peripheral accesses: hold current instruction context and commit exactly once on completion.
- Bare-metal assembly and C; initial implementation is RTL simulation and generic synthesis, no FPGA target.

## Current architecture assignment
Ask the Architect to prepare a detailed proposal covering:
1. Top-level address map: distinct, non-overlapping regions for instruction ROM (including address zero), data RAM, and APB peripheral window; subranges for UART, GPIO, and timer. Include base addresses, sizes, alignment, permissions, decode behavior, and unmapped-address handling. Explain how the instruction and data paths decode the map under Harvard organization.
2. Instruction ROM local interface: signals, read timing/latency, initialization format and fetch behavior.
3. Data RAM local interface: signals, read/write timing, byte enables, little-endian behavior, supported access widths, alignment and range checks. Prefer the simplest fixed-latency implementation compatible with the single-cycle CPU; explain any required wait states.
4. APB3 bridge FSM and exact CPU stall/hold/commit timing, including PREADY wait states, stable APB signals, and PSLVERR behavior. Follow the supplied ARM APB specification and do not substitute APB4 or AXI.
5. Fault status/capture/priority/halt/recovery behavior.
6. Reset values and reset release behavior.
7. Top-level module hierarchy and integration contracts.

### Important scope boundary
The human explicitly wants to defer individual UART/GPIO/timer register maps. Reserve their peripheral address subranges only. Do not invent/finalize register offsets, bit fields, reset values, FIFO policy, or detailed register semantics in this task. Mark any optional examples as illustrative and non-binding; preferably omit them.

## After the Architect reports
- Present the proposal to the human with trade-offs and unresolved decisions.
- Do not mark it approved or freeze it without explicit human confirmation.
- Once the address regions and core interfaces are approved, create/update decision records and interface contracts.
- Then ask the Verification Engineer to create an independent verification plan and verification firmware from the approved contracts. Verification Engineer owns test firmware, testbench, SVA, reference models, expected results, and coverage. RTL Designer must not edit these assets.
- Keep verification test firmware distinct from later demonstration firmware.
- Freeze a verification baseline only after human review and approval.
- Only after architecture/contracts and verification plan/baseline are approved may RTL implementation begin.

## Required completion report
End this task with status, files created/changed, assumptions, proposals, open decisions, evidence paths, Git status/branch/commit state, and the exact human approvals required next. If no commands/tests were run, state `NOT_RUN`.
