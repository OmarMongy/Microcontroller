# Microcontroller SoC Specification — Draft 0.3

**Status:** Top-level decisions approved; detailed architecture/interface contracts pending human approval  
**Project:** Educational AI-assisted RV32I Microcontroller SoC  
**CPU microarchitecture:** Single-cycle RV32I for ordinary instructions, with wait-state support for APB peripheral transactions

## 1. Project goals
Build a small, understandable microcontroller SoC from RTL. Prioritize educational value, clear interfaces, independent verification, reproducible results, and human approval over commercial-level complexity.

## 2. Approved user decisions
| ID | Area | Decision |
|---|---|---|
| A1 | ISA | Full RV32I base integer instruction set |
| A2 | Privilege/interrupt scope | Basic CPU; no external interrupts or privileged architecture initially |
| B1 | Memory organization | Harvard: separate instruction ROM and data RAM |
| B2 | Memory sizes | 32 KB instruction ROM and 32 KB data RAM |
| B3 | Program loading | Instruction ROM initialized from `.hex` or `.mem` |
| C1 | Peripheral interconnect | AMBA APB3 |
| C2 | Peripherals | UART, GPIO, timer |
| D1 | UART format | 8N1, 115200 baud default |
| D2 | UART baud | Programmable through peripheral register(s) |
| E1 | GPIO width | 8-bit |
| E2 | GPIO functionality | Basic I/O with direction configuration |
| F1 | Timer | 32-bit counter + programmable compare; no interrupt initially |
| G1 | Clock | 50 MHz |
| G2 | Reset | Active-low asynchronous external reset; internal reset-release details pending |
| H1 | Firmware | Assembly and bare-metal C |
| H2 | Demonstrations | Arithmetic/instruction test, GPIO, UART TX/RX, timer delay, combined peripheral demo |
| I1 | Initial implementation | RTL simulation and generic synthesis; no FPGA initially |
| I2 | Verification | Directed testbench + SVA |

## 3. CPU requirements
- 32-bit RISC-V base integer ISA, RV32I; `x0` always reads as zero.
- Single-cycle datapath/control for instructions completing without external wait states.
- No M extension, floating point, compressed instructions, caches, pipeline, or branch prediction initially.
- No external interrupts or privileged-mode architecture initially.
- CPU must wait for a delayed APB peripheral transaction without losing/repeating the current instruction.
- PC and architectural state update only at the correct instruction-completion point; loads/stores must not be duplicated while stalled.

**Terminology:** The CPU remains single-cycle for ordinary operations. A load/store to an APB peripheral can take multiple clocks due to APB wait states. This is a bus wait condition, not a pipeline or a general multicycle CPU redesign.

## 4. Memory organization and interfaces
- Harvard organization with physically/logically distinct instruction and data access paths.
- Instruction ROM capacity: 32 KB; initialized from `.hex` or `.mem`; reset vector is `0x0000_0000`.
- Data RAM capacity: 32 KB.
- **Instruction ROM and data RAM use dedicated local memory interfaces, not APB.**
- APB3 is reserved for memory-mapped peripheral accesses (UART/GPIO/timer).
- Architect must propose local ROM/RAM signal contracts and timing. The design should use the simplest fixed-latency local interface compatible with the approved single-cycle CPU and intended generic synthesis. Do not assume a specific FPGA BRAM or ASIC SRAM macro.
- Data RAM contract must define supported access widths, byte-write enables, little-endian byte ordering, read latency, write timing, alignment behavior, and out-of-range behavior.
- Exact address ranges and decoder behavior are proposed by the Architect and require human approval.

## 5. Address-map scope
The Architect's immediate proposal must define non-overlapping address regions for:
1. Instruction ROM (including reset address `0x0000_0000`).
2. Data RAM.
3. APB peripheral window.
4. UART, GPIO, and timer subranges within the APB window.

Define region sizes, base/end addresses, decode granularity, access permissions, and unmapped-address response. Keep instruction-fetch and data-access decode behavior consistent with Harvard organization. The human approves the map before it is frozen.

**Deferred:** Individual UART/GPIO/timer register offsets, register bit fields, reset values, and detailed peripheral register semantics are intentionally outside this first address-region task. Handle them in a later focused architecture task. Do not silently invent them now.

## 6. APB3 peripheral subsystem
- APB3 bridge/interconnect connects the CPU data-access path to the peripheral window.
- Follow the human-supplied official ARM AMBA APB specification placed under `docs/specifications/references/` as the protocol reference. Use APB3 only; do not silently substitute APB4 or AXI.
- APB setup phase is followed by access phase. While access is pending (`PREADY=0`), keep required control/address/write-data signals stable until completion.
- CPU holds the current instruction context while APB is pending; no premature PC update, register write-back, or duplicate peripheral side effect.
- Transfer completes on an active access phase with `PREADY=1`; read data/write completion is consumed exactly once.
- `PSLVERR` produces the approved visible bus-fault status and CPU halt policy.
- Architect defines cycle-accurate bridge FSM and CPU stall/commit interface before RTL.

## 7. Peripherals (functional scope only)
- UART: 8N1, 115200 baud default, programmable baud. Register details deferred.
- GPIO: 8-bit input/output with direction configuration; no interrupt initially. Register details deferred.
- Timer: 32-bit counter and programmable compare; no interrupt initially; software may poll status. Register details deferred.

## 8. Clock and reset
- One shared 50 MHz clock for CPU, instruction ROM, data RAM, APB bridge, UART, GPIO, and timer.
- External reset is active-low asynchronous.
- Architect defines reset release/synchronization, reset values, and reset behavior for all state.

## 9. Fault policy
The following are approved to set visible fault status and halt the CPU:
- Invalid or misaligned memory accesses.
- Illegal instructions, `ECALL`, and `EBREAK`.
- APB3 `PSLVERR`.

This is an educational platform fault-and-halt policy, not a RISC-V privileged trap implementation. Architect proposes fault codes, captured PC/instruction/address context, priority, and reset recovery. CPU must not silently continue after a fatal fault.

## 10. Firmware and demonstrations
- Project supports bare-metal assembly and C.
- Verification Engineer owns small assembly/C firmware programs used specifically as verification stimuli. These programs, their expected outcomes, and test IDs are verification assets and must be independent of RTL implementation.
- Verification firmware is distinct from later demonstration applications. Demo firmware may be created in a separate software task after the platform contracts/toolchain are stable.
- Software bring-up will define toolchain, compiler flags, linker script, startup code, ELF-to-HEX/MEM conversion, and reproducible image generation.
- Planned demonstration programs: RV32I arithmetic/logical test; GPIO; UART TX/RX; timer polling delay; combined peripheral demo.

## 11. Verification and implementation
- Directed simulation testbench and SVA; generic synthesis initially.
- Verification plan and expected outcomes are derived from approved requirements/contracts before implementation RTL inspection wherever practical.
- Verification Engineer writes/owns verification firmware, testbench, reference models, SVA, expected results, and coverage.
- RTL Designer must not modify verification-owned assets.
- No FPGA implementation in the initial milestone. Generic synthesis statistics are not FPGA resource usage, ASIC area, or physical timing closure.

## 12. Explicitly out of scope initially
Pipeline, caches, branch prediction, M extension, floating point, compressed ISA, external interrupts/controller, privileged architecture, OS, MMU/virtual memory, DMA, AXI, FPGA implementation, and UVM/class-based verification.

## 13. Approved additional architecture decisions
| ID | Decision | Approved behavior |
|---|---|---|
| D1 | Reset vector | `0x0000_0000` |
| D2 | Invalid/misaligned memory access | Visible fault status and halt |
| D3 | Illegal instruction, `ECALL`, `EBREAK` | Visible fault status and halt |
| D4 | APB3 `PSLVERR` | Visible bus-fault status and halt |
| D5 | Clock domains | One shared 50 MHz clock for CPU, memories, bridge, and peripherals |
| D6 | Local memory vs peripheral bus | ROM and RAM use dedicated local interfaces; APB3 is for peripherals only |
| D7 | Address map ownership | Architect proposes top-level regions; human approves; register maps deferred |
| D8 | Verification firmware ownership | Verification Engineer authors verification test programs; separate demo firmware is a later task |

## 14. Specification status
Top-level scope and decisions D1-D8 are approved. Address-region layout, local memory timing, APB bridge timing, fault interface, peripheral register contracts, reset details, and software toolchain remain proposals/open contracts. RTL implementation must not begin until the relevant contracts are explicitly approved.
