# Human Engineering Decision — Addressing, Memory Interface, and Verification Ownership

- Decision ID: `DEC-ARCH-BASELINE-002`
- Status: `APPROVED_DIRECTION; DETAILED CONTRACTS PENDING`
- Topic: Address-map ownership, local memory interfaces, and verification firmware

## Decisions recorded
1. Architect proposes the top-level address regions for instruction ROM, data RAM, and the APB peripheral window, including UART/GPIO/timer subranges. Human approval is required before freezing the map.
2. Individual UART/GPIO/timer register maps are deferred to a later focused task. The current architecture task reserves peripheral subranges only.
3. Instruction ROM and data RAM use dedicated local interfaces, not APB. APB3 is used only for memory-mapped peripherals.
4. Architect must recommend local memory timing/latency compatible with the single-cycle CPU and explain any required wait-state trade-offs. Exact contracts remain pending human approval.
5. Verification Engineer authors assembly/C firmware used as verification stimuli and owns associated expected outcomes/test IDs. Separate demonstration firmware is a later software task.

## Not yet approved
- Exact address bases/sizes for each region.
- ROM/RAM signal-level contracts and latency.
- APB bridge cycle-level implementation.
- Peripheral subrange sizes beyond the high-level allocation proposal.
- Peripheral register offsets and bit-level semantics.
- Firmware toolchain and linker/image details.
