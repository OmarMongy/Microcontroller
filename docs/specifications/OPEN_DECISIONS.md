# Remaining Architecture and Interface Details

**Status:** Top-level decisions D1-D8 are approved. Detailed proposals and human approval are still required before RTL implementation.

## Approved and closed
- Full RV32I, single-cycle CPU for ordinary instructions; no pipeline/privilege/interrupt scope initially.
- Harvard organization: 32 KB instruction ROM and 32 KB data RAM.
- Reset vector `0x0000_0000`.
- ROM and RAM use dedicated local interfaces; APB3 is only for memory-mapped peripherals.
- Architect proposes top-level address regions; human approves them.
- Peripheral register maps are deferred to a later focused task.
- Verification Engineer authors verification firmware; separate demo firmware is a later software task.
- Invalid/misaligned accesses, illegal instruction/ECALL/EBREAK, and APB `PSLVERR` set visible fault status and halt.
- Shared 50 MHz clock; active-low asynchronous external reset.
- APB wait states hold the current instruction; transfer side effects/CPU commit happen exactly once.

## Immediate Architect assignment (address regions and architecture contracts)
1. **Top-level address map:** propose separate, non-overlapping regions for instruction ROM (must include reset address zero), data RAM, and APB peripheral window; allocate UART/GPIO/timer subranges inside APB. Include base, inclusive/exclusive end convention, size, alignment, access permissions, decode granularity, and unmapped response. Explain instruction-vs-data path decode for Harvard architecture. Human approval required.
2. **Local instruction ROM interface:** signal contract, read latency, reset/fetch behavior, initialization file format and word ordering. Do not route fetches over APB.
3. **Local data RAM interface:** signal contract, read latency, write timing, byte enables, little-endian semantics, access widths, alignment and range checks. Recommend fixed latency compatible with single-cycle operation; if not feasible, quantify added wait-state implications and ask for approval.
4. **APB3 bridge and CPU stall:** cycle-accurate FSM, stable signals during wait states, PREADY completion, PSLVERR capture, PC/instruction hold, exactly-once read/write commit. Refer to the human-supplied ARM APB specification.
5. **Fault interface:** fault codes, visible status, captured PC/instruction/address, priority, halt and reset recovery.
6. **Reset contract:** reset values and safe release behavior for CPU, local memories/control, bridge and peripherals.
7. **Module hierarchy/integration:** block diagram, module responsibilities, interfaces and integration dependencies.

### Explicitly deferred from this assignment
Do not finalize UART/GPIO/timer register offsets, bit fields, register reset values, FIFO policy, or detailed peripheral register semantics. Only reserve the peripheral address subranges and explain the peripheral decode boundary. These register-level contracts will be a later task after the top-level map is approved.

## Later focused architecture assignment: peripheral register maps
- UART: offsets/access permissions, baud divisor, TX busy behavior, RX valid/overrun, status/control, reset values, buffering policy.
- GPIO: input/output/direction offsets, reset values, input sampling assumptions and output update behavior.
- Timer: counter/compare/status/control offsets, enable/reset, sticky match/clear semantics, wrap behavior.

## Later software/verification decisions
- Toolchain, compiler/assembler version and flags, linker script, startup code, ELF-to-HEX/MEM flow and image reproducibility.
- Verification Engineer proposes firmware test structure, test IDs, expected outcomes, and test-to-requirement traceability after contracts are approved.
- Demo firmware is a separate software deliverable, not a prerequisite for verification firmware.

## Rule
The Architect may recommend and explain alternatives but must label all unapproved choices as proposals. The human approves address regions and interface contracts. No RTL implementation before approval.
