# Initial Architecture Proposal — Pending Human Approval

## Proposed high-level structure

```text
                     +--------------------------+
                     | Single-cycle RV32I CPU   |
                     | PC / Decoder / ALU / RF  |
                     +-----------+--------------+
                                 |
                  +--------------+-------------------+
                  |                                  |
           Instruction fetch                  Data access
                  |                                  |
        +---------v---------+               +--------v---------+
        | Instruction ROM   |               | Data address     |
        | 32 KB, local port  |               | decode           |
        +-------------------+               +---+-----------+--+
                                                |           |
                                         +------v---+   +---v----------+
                                         | Data RAM |   | APB3 bridge  |
                                         | 32 KB    |   +---+----------+
                                         | local    |       |
                                         +----------+   +---+---+---+
                                                       |   |   |
                                                      UART GPIO Timer
```

This reflects the approved Harvard organization: a distinct instruction-fetch path and data-access path. The diagram is conceptual; exact signals and timing remain to be proposed.

## Interface partition (approved direction)
- Instruction ROM: dedicated local instruction interface, not APB.
- Data RAM: dedicated local data interface, not APB.
- APB3 bridge: peripheral accesses only.
- One shared 50 MHz clock across all blocks.

## Local memory recommendation to evaluate
Prefer simple fixed-latency local interfaces. The Architect must define whether instruction ROM and data RAM can return data within the single-cycle CPU timing model and whether a synchronous read adds a wait state. Do not claim a specific inferred-memory implementation is portable across FPGA/ASIC flows. The final choice needs human approval.

## APB peripheral wait-state behavior
1. CPU decodes a load/store and computes the effective address.
2. Data address decode selects local RAM or APB peripheral window.
3. For APB, bridge performs SETUP then ACCESS.
4. If `PREADY=0`, it holds required APB signals stable and keeps the CPU instruction pending.
5. When ACCESS is active and `PREADY=1`, the transfer completes.
6. Read data or write completion is consumed once; CPU commits and advances PC once.

During APB wait:
- PC and current instruction context remain stable.
- No premature register write-back.
- No duplicate APB write side effects.
- Bridge does not restart SETUP while remaining in ACCESS.

The cycle-level CPU/bridge contract must be proposed and approved before RTL.

## Address-map task
Architect proposes distinct, non-overlapping regions for instruction ROM, data RAM and APB peripheral window, plus UART/GPIO/timer subranges. Instruction ROM includes reset vector `0x0000_0000`. Human approval is required. Peripheral register offsets are deliberately deferred to a later task.

## Approved platform decisions
- Reset vector `0x0000_0000`.
- Invalid/misaligned accesses: visible fault status and halt.
- Illegal instructions, `ECALL`, `EBREAK`: visible fault status and halt.
- APB `PSLVERR`: visible bus fault and halt.
- One shared 50 MHz clock.
- Harvard ROM/RAM local interfaces; APB only for peripherals.

Fault-and-halt is a platform policy, not privileged trap support.
