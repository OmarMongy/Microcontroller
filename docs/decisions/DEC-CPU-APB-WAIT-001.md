# Human Engineering Decision — Single-Cycle CPU with APB Wait States

- Decision ID: `DEC-CPU-APB-WAIT-001`
- Topic: CPU behavior during APB3 peripheral accesses
- Status: `APPROVED`

## Decision

Retain a single-cycle RV32I CPU microarchitecture for ordinary instruction execution. APB3 peripheral operations may take more than one clock cycle. The CPU must stall/hold the current instruction until the APB3 transfer completes, then proceed to the next instruction.

## Required behavior

- Hold PC/current instruction context while APB access is pending.
- Keep APB transfer controls stable while `PREADY` is low.
- Do not duplicate writes or commit architectural side effects more than once.
- Complete the load/store and advance execution only after APB transfer completion.

## Rationale

Keep the CPU datapath simple while supporting realistic peripheral wait states through APB3.

## Follow-up

Architect must define the exact stall/commit and APB FSM interface contract. Independent Verification Engineer must create tests and assertions for wait-state behavior before RTL implementation.
