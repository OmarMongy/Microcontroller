# Master Verification Plan V1 — Single-Cycle RV32I Microcontroller SoC

- **Document ID:** `VER-PLAN-001`
- **Baseline ID:** `SOC_VB_001`
- **Version:** `V1.0`
- **Status:** `APPROVED / FROZEN (DEC-VER-BASELINE-001)`
- **Date:** 2026-11-27
- **Approved Decision:** [DEC-VER-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-001.md)
- **Author:** Independent Verification Engineer Agent
- **Specification Baseline:** [SOC_SPECIFICATION_DRAFT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/specifications/SOC_SPECIFICATION_DRAFT.md) (Draft 0.3), [OPEN_DECISIONS.md](file:///mnt/e/PB/Projects/Microcontroller/docs/specifications/OPEN_DECISIONS.md)
- **Approved Decisions Referenced:**
  - [DEC-ARCH-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-BASELINE-001.md) (`APPROVED`)
  - [DEC-ARCH-BASELINE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-BASELINE-002.md) (`APPROVED_DIRECTION`)
  - [DEC-CPU-APB-WAIT-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-CPU-APB-WAIT-001.md) (`APPROVED`)
  - [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) (`APPROVED`)
  - [DEC-ARCH-CORE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-002.md) (`APPROVED`)
- **Frozen Core Contracts Referenced:**
  - [ADDRESS_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/ADDRESS_MAP_CONTRACT.md) (`CON-ADDR-001` v1.1 — `APPROVED`)
  - [LOCAL_MEMORY_INTERFACE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/LOCAL_MEMORY_INTERFACE_CONTRACT.md) (`CON-MEM-001` v1.1 — `APPROVED`)
  - [APB3_BRIDGE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/APB3_BRIDGE_CONTRACT.md) (`CON-APB3-001` v1.1 — `APPROVED`)
  - [FAULT_AND_RESET_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/FAULT_AND_RESET_CONTRACT.md) (`CON-FLT-RST-001` v1.1 — `APPROVED`)
  - [SOC_TOP_HIERARCHY_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/SOC_TOP_HIERARCHY_CONTRACT.md) (`CON-TOP-001` v1.1 — `APPROVED`)
- **External Protocol Reference:** `AMBA® APB Protocol Specification` (`ARM IHI 0024E / ID022823`, Issue E, 28 February 2023 — **APB3 / Issue B / v1.0** subset ONLY), stored at [IHI0024E_amba_apb_architecture_spec.pdf](file:///mnt/e/PB/Projects/Microcontroller/docs/specifications/references/IHI0024E_amba_apb_architecture_spec.pdf)
- **Companion Verification Documents:**
  - [SVA_SPECIFICATION_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V1.md)
  - [COVERAGE_PLAN_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/COVERAGE_PLAN_V1.md)
  - [TEST_MANIFEST.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TEST_MANIFEST.md)
  - [TOOLCHAIN_AND_BUILD.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TOOLCHAIN_AND_BUILD.md)

> **Independence & Baseline Freeze Notice:**
> All test cases, expected outcomes, assertions, and firmware signatures in this plan are derived strictly from the approved specification and frozen core contracts above prior to RTL implementation. Baseline `SOC_VB_001` is **`PROPOSED`** and must not be treated as frozen until explicitly approved by the human owner. Peripheral register-level verification (`uart_apb`, `gpio_apb`, `timer_apb`) is explicitly marked **`BLOCKED (awaiting approved peripheral register-map contract)`** and will be added in a successor baseline (`SOC_VB_002`) once the peripheral register-map contract is approved.

---

## 1. Verification Scope

### 1.1 In-Scope Core Verification (Unblocked by Frozen Core Contracts)
1. **RV32I Base Integer ISA (`rv32i_cpu`):**
   - All 40 RV32I base integer instructions (`LUI`, `AUIPC`, `JAL`, `JALR`, `BEQ/BNE/BLT/BGE/BLTU/BGEU`, `LB/LH/LW/LBU/LHU`, `SB/SH/SW`, `ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI`, `ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND`, `FENCE`, `ECALL`, `EBREAK`).
   - `x0` hardwired-zero immutability (`x0` as destination and source).
   - Single-cycle execution for non-load, non-APB instructions; `FENCE` single-cycle NOP after completion of all preceding memory transactions (`DEC-ARCH-CORE-002`).
2. **Modified Harvard Address Decode & Local Memories (`CON-ADDR-001`, `CON-MEM-001`):**
   - Full 32-bit non-aliased decode for `IROM` (`0x0000_0000`–`0x0000_7FFF`), `DRAM` (`0x2000_0000`–`0x2000_7FFF`), and `APB3` populated slots (`0x4000_0000`–`0x4000_2FFF`).
   - `irom_local` Port A (0-cycle combinational IF read, `$readmemh` initialization, unprogrammed word `32'h0` behavior).
   - `irom_local` Port B (1-cycle synchronous `.rodata` read = 2 cycles total via `local_rd_valid`, `LB/LBU/LH/LHU/LW`, read-only enforcement).
   - `dram_local` (`Option RAM-B`): 1-cycle synchronous byte-enabled write (`SB/SH/SW` with `dram_be[3:0]`), 1-cycle synchronous read (2 cycles total per load via `local_rd_valid`), little-endian byte-lane preservation, `local_read_stall` vs `apb_stall` mutual exclusion.
3. **APB3 Bridge & CPU Stall/Commit Contract (`CON-APB3-001`, `DEC-CPU-APB-WAIT-001`, `IHI0024E` Issue B):**
   - Strict APB3 signal subset (`PCLK`, `PRESETn`, `PADDR`, `PSEL_UART`, `PSEL_GPIO`, `PSEL_TIMER`, `PENABLE`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`, `PSLVERR`); zero APB4/APB5 signals.
   - Registered FSM (`IDLE -> SETUP -> ACCESS`), 3-cycle minimum 0-wait transfer, multi-cycle `PREADY=0` wait states (`1, 2, 5+` cycles), stability of `PADDR`/`PWRITE`/`PWDATA`/`PSELx`/`PENABLE` during `SETUP -> ACCESS` and wait states.
   - `Option APB-W1` strict 32-bit aligned `LW`/`SW` enforcement (sub-word `FAULT_DATA_SIZE_UNSUP`, unaligned `FAULT_DATA_MISALIGNED`, reserved slots `0x4000_3000`–`0x4000_FFFF` `FAULT_DATA_UNMAPPED` rejected prior to `apb_req_valid`).
   - CPU `PC`/instruction hold during `dmem_stall`, exactly-once `RF` writeback / peripheral transfer commit, and `PSLVERR` suppression + halt.
   - Validated at the `apb3_bridge` / `soc_top` bus boundary using **Testbench Mock APB3 Completers** for Slots 0, 1, and 2 prior to peripheral RTL/register-map approval.
4. **Fault-and-Halt Policy & Reset Architecture (`CON-FLT-RST-001`):**
   - All fault codes `4'h0` (`FAULT_NONE`) through `4'hA` (`FAULT_DATA_RO_WRITE`).
   - Strict 8-level fault priority order when simultaneous fault conditions occur.
   - Sticky capture of `fault_valid`, `fault_code`, `fault_pc`, `fault_insn`, `fault_addr` on `rv32i_cpu` and `soc_top` (`fault_*_o`).
   - Zero architectural mutation (`PC`, `RF`, `DRAM`, `APB3`) on faulting instruction and while halted.
   - `rst_sync` 2-FF asynchronous-assert / synchronous-deassert reset behavior (`rst_n` -> `sys_rst_n` / `PRESETn`), reset recovery from halted/stalled states, and subsystem reset values.
5. **Top-Level Integration (`CON-TOP-001`):**
   - `soc_top` port connectivity (`clk`, `rst_n`, `uart_rx_i`, `uart_tx_o`, `gpio_i`, `gpio_o`, `gpio_oe_o`, `fault_o`, `fault_code_o`, `fault_pc_o`, `fault_addr_o`, `fault_insn_o`).
   - Reset-state pin checks (`uart_tx_o == 1'b1`, `gpio_oe_o == 8'h00`, `gpio_o == 8'h00`, `fault_o == 1'b0`, `fault_code_o == 4'h0`).

### 1.2 Explicitly Out-of-Scope / `BLOCKED` Items
1. **BLOCKED (awaiting approved peripheral register-map contract):**
   - `uart_apb` register offsets, baud divisor programming, 8N1 TX/RX frame generation/sampling, RX overrun/valid flags, and internal `PSLVERR` conditions.
   - `gpio_apb` register offsets, per-bit `gpio_oe_o` / `gpio_o` control, `gpio_i` input synchronizer latency/sampling, and internal `PSLVERR` conditions.
   - `timer_apb` register offsets, 32-bit counter increment/wrap, programmable compare match sticky/clear semantics, enable/reset bits, and internal `PSLVERR` conditions.
   - Bare-metal C/assembly peripheral functional firmware tests (GPIO loop, UART TX/RX, Timer polling delay, combined peripheral demo).
2. **Out of Scope by Specification (`SOC_SPECIFICATION_DRAFT.md` Section 12):**
   - UVM/class-based verification, caches, pipeline/branch-prediction, M/F/C/A/Zicsr extensions, privileged traps/interrupts, AXI/APB4/APB5 features.

---

## 2. Verification Strategy & Architecture

### 2.1 Four-Pillar Verification Approach
1. **Directed Verification Firmware (`verification/firmware/`):**
   - Self-checking RV32I assembly (`.S`) and bare-metal C stimuli compiled to 32-bit word `.mem` images for `$readmemh` loading into `irom_local`.
   - Uses a contract-derived `DRAM` signature mailbox (`0x2000_7F00`–`0x2000_7FFF`) + `EBREAK` (`fault_code_o == 4'h5`) for deterministic pass/fail termination on normal tests, and pre-fault markers + unexecuted sentinel writes for fault tests.
2. **Directed SystemVerilog Testbench Harnesses (`tb/` — to be implemented in Gate 4):**
   - **TB-CORE-BUS (`apb3_bridge` + `data_bus_decode` + `rv32i_cpu` + `irom_local` + `dram_local`):** Subsystem & core-SoC harness using **Mock APB3 Completers** attached to `PSEL_UART`, `PSEL_GPIO`, `PSEL_TIMER` to inject `0, 1, 2, 5, 16` wait states (`PREADY=0`), deterministic `PRDATA`, and `PSLVERR=1` on demand without depending on peripheral register maps.
   - **TB-SOC-TOP (`soc_top`):** Full-chip testbench driving `clk` (50 MHz, 20 ns period), `rst_n` (asynchronous pulse/glitch/recovery waveforms), `uart_rx_i`, `gpio_i`, and checking `soc_top` outputs (`fault_*_o`, `uart_tx_o`, `gpio_o`, `gpio_oe_o`). Core firmware tests (`VER-CORE-001`, `VER-CORE-002`, `VER-FAULT-001..007`, `VER-FAULT-009` on local memories) run directly on `soc_top` even while peripheral functional tests are blocked; `VER-CORE-003`, `VER-FAULT-008`, `VER-FAULT-010` run on `TB-CORE-BUS` with Mock APB3 Completers (and later on `soc_top` once peripheral register maps are approved).
3. **SystemVerilog Assertions (`SVA_SPECIFICATION_V1.md`):**
   - Non-intrusive `bind` assertion modules covering APB3 protocol (`IHI0024E` Issue B), local memory timing (`CON-MEM-001`), CPU stall/commit (`CON-APB3-001`), fault-and-halt & reset (`CON-FLT-RST-001`), and `cover property` protocol milestones.
4. **Independent Golden Reference Model & Scoreboard:**
   - A cycle-aware RV32I behavioral reference model in the testbench (independent of RTL internals) initialized with the exact `.mem` image loaded into `irom_local`.
   - On every non-stalled instruction retirement edge (`!dmem_stall && !fault_valid && sys_rst_n`), the scoreboard compares committed architectural state (`PC`, `rd` write value, `DRAM` byte-level shadow memory, `APB3` transaction count/payload) and fault capture (`fault_valid`, `fault_code`, `fault_pc`, `fault_addr`, `fault_insn`) against the golden reference model.

### 2.2 Mock APB3 Completer Design (Pre-Peripheral-RTL Bus Verification)
To test `CON-APB3-001` and `DEC-CPU-APB-WAIT-001` before `uart_apb`/`gpio_apb`/`timer_apb` register maps exist, the testbench provides three configurable Mock APB3 Completers (`mock_apb_completer`) wired to `PSEL_UART`, `PSEL_GPIO`, and `PSEL_TIMER`:
- **Slot Register Scratchpad:** Each mock holds an internal array indexed by `PADDR[11:2]` (reset to `32'h0000_0000` on `PRESETn == 0`), allowing real write-then-read verification (`SW` followed by `LW` returns written data) without assuming any peripheral register semantics.
- **Programmable Wait-State Profile:** Driven by testbench configuration per slot or per address offset (e.g., `wait_cycles = 0, 1, 2, 5, 16`), holding `PREADY = 0` for `N` cycles in `ACCESS` before asserting `PREADY = 1` for 1 cycle.
- **Programmable `PSLVERR` Injection:** Configurable error trigger (e.g., specific magic offset or testbench force flag) returning `PREADY = 1, PSLVERR = 1` on the final `ACCESS` cycle.
- **Spurious-Access Detector:** Counts every `PSELx && PENABLE && PREADY` completion per slot and flags an immediate error if a single CPU `LW`/`SW` produces `!= 1` APB3 transfer, or if a faulted/sub-word/unaligned access initiates `PSELx`.

### 2.3 Pass/Fail Criteria (For Gates 4, 5, and 8)
A verification regression (`SOC_VB_001`) passes if and only if:
1. All unblocked test cases (`VER-CORE-*`, `VER-FAULT-*`, `VER-RST-*`, `VER-BUS-*`) compile cleanly and pass with `0` scoreboard mismatches and `0` signature errors.
2. Zero SVA assertion failures (`assert property`) across all simulation runs, including negative fault tests (fault tests must satisfy fault-capture assertions without violating protocol invariants).
3. 100% of unblocked functional coverage goals defined in `COVERAGE_PLAN_V1.md` are hit.
4. No RTL defect, infrastructure error, or unexplained warning remains open in `regression/REGRESSION_TRACKER.md`.

---

## 3. Requirement-to-Test Traceability Matrix

### 3.1 Core & Unblocked Requirements

| Req / Contract ID | Requirement Summary | Verification Method | Test ID(s) | SVA ID(s) | Coverage ID(s) | Status |
|---|---|---|---|---|---|---|
| `SPEC A1`, `CPU §3` | Full RV32I base integer ISA; `x0 == 0`; single-cycle ordinary execution | Firmware + Golden ISS + SVA | `VER-CORE-001`, `VER-CORE-002` | `SVA-CPU-001`, `SVA-CPU-002` | `CG-RV32I-OPS`, `CG-RV32I-HAZARD` | `READY` |
| `SPEC A2`, `CPU §3` | No M/F/C/privileged/CSRR; illegal opcodes halt with `FAULT_ILLEGAL_INSN` | Firmware + TB + SVA | `VER-FAULT-003` | `SVA-FLT-001..004` | `CG-FAULT-CODES` | `READY` |
| `DEC-ARCH-CORE-002 #3` | `FENCE` (`opcode=7'b0001111, funct3=3'b000`) executes as valid 1-cycle NOP after memory completion | Firmware + TB cycle check + SVA | `VER-CORE-001`, `VER-CORE-003` | `SVA-CPU-006` | `CG-RV32I-OPS` | `READY` |
| `CON-ADDR-001 §2, §4.1` | `IROM` `0x0000_0000`–`0x0000_7FFF`; reset vector `0x0`; no aliasing; IF outside `IROM` -> `FAULT_IF_UNMAPPED`; misaligned `PC` -> `FAULT_IF_MISALIGNED` | Firmware + TB + SVA | `VER-CORE-001`, `VER-FAULT-001`, `VER-FAULT-002` | `SVA-MEM-001`, `SVA-FLT-002` | `CG-ADDR-REGIONS`, `CG-FAULT-CODES` | `READY` |
| `CON-ADDR-001 §3, §4.2` | `DRAM` `0x2000_0000`–`0x2000_7FFF`; `APB3` slots `0..2` (`0x4000_0000..2FFF`); reserved slots `3..15` (`0x4000_3000..FFFF`) -> `FAULT_DATA_UNMAPPED`; unmapped gaps -> `FAULT_DATA_UNMAPPED` | Firmware + TB + SVA | `VER-CORE-002`, `VER-CORE-003`, `VER-FAULT-006` | `SVA-DEC-001`, `SVA-APB-003` | `CG-ADDR-REGIONS`, `CG-FAULT-CODES` | `READY` |
| `DEC-ARCH-CORE-001 #1`, `DEC-ARCH-CORE-002 #1,#2`, `CON-MEM-001 §1` | Modified Harvard `irom_local`: Port A 0-cycle IF; Port B 1-cycle sync `.rodata` load (2 cycles total); stores to `IROM` -> `FAULT_DATA_RO_WRITE` (`4'hA`); `$readmemh` word order | Firmware + TB timing check + SVA | `VER-CORE-002`, `VER-FAULT-007` | `SVA-MEM-001..004`, `SVA-MEM-008` | `CG-IROM-PORTB`, `CG-FAULT-CODES` | `READY` |
| `DEC-ARCH-CORE-001 #2`, `CON-MEM-001 §2` | `dram_local` (`Option RAM-B`): 1-cycle sync byte-enabled write (`SB/SH/SW`), 2-cycle sync read (`LB/LBU/LH/LHU/LW`), little-endian byte-lane preservation, `local_rd_valid` | Firmware + TB timing check + SVA | `VER-CORE-002` | `SVA-MEM-005..009` | `CG-DRAM-ACCESS` | `READY` |
| `CON-APB3-001 §1, §3, §4`, `IHI0024E` | Strict APB3 Issue B signals; `IDLE->SETUP->ACCESS`; 1-cycle `SETUP`; signal stability on `PREADY=0`; one-hot `PSELx`; `PSLVERR` sampled only in `ACCESS && PREADY` | TB (`TB-CORE-BUS`) + Mock APB3 + SVA | `VER-CORE-003`, `VER-BUS-001`, `VER-FAULT-010` | `SVA-APB-001..010` | `CG-APB3-PROTO` | `READY` |
| `CON-APB3-001 §2` | `Option APB-W1`: `LW`/`SW` 4B aligned only on APB3; sub-word -> `FAULT_DATA_SIZE_UNSUP` (`4'h8`); unaligned -> `FAULT_DATA_MISALIGNED` (`4'h6`); zero APB bus activity on rejection | Firmware + TB + SVA | `VER-FAULT-008`, `VER-FAULT-009` | `SVA-APB-009`, `SVA-DEC-002` | `CG-APB3-PROTO`, `CG-FAULT-CODES` | `READY` |
| `DEC-CPU-APB-WAIT-001`, `CON-APB3-001 §5` | CPU holds `PC`/insn on `dmem_stall`; `RF` written once; single APB transfer per instruction; `PSLVERR` suppresses `RF` write & halts (`4'h9`) | Firmware + TB + SVA | `VER-CORE-003`, `VER-FAULT-010` | `SVA-CPU-003..005`, `SVA-DEC-003` | `CG-APB3-PROTO` | `READY` |
| `CON-FLT-RST-001 §1` | Fault codes `4'h0`–`4'hA`, 8-level priority, sticky `fault_*` capture, zero state mutation, reset-only recovery | Firmware + TB + SVA | `VER-FAULT-001..011` | `SVA-FLT-001..007` | `CG-FAULT-CODES`, `CG-FAULT-PRIO` | `READY` |
| `CON-FLT-RST-001 §2` | `rst_sync` 2-FF async-assert / sync-deassert; reset values (`PC=0`, `x1..x31=0`, `fault_*=0`, `local_rd_valid=0`, `dram_rdata/irom_drdata=0`, `apb=IDLE`); reset during stall & fault | TB directed waveform + SVA | `VER-RST-001`, `VER-RST-002` | `SVA-RST-001..006` | `CG-RESET` | `READY` |
| `CON-TOP-001 §3` | `soc_top` port connectivity & reset outputs (`uart_tx_o=1`, `gpio_oe_o=0`, `gpio_o=0`, `fault_o=0`) | TB (`TB-SOC-TOP`) + SVA | `VER-RST-001`, `VER-CORE-001`, `VER-CORE-002` | `SVA-RST-005`, `SVA-FLT-001` | `CG-RESET` | `READY` |

### 3.2 `BLOCKED` Peripheral Register-Map Requirements

| Req / Contract ID | Deferred / Blocked Scope | Blocked Test IDs | Blocking Dependency |
|---|---|---|---|
| `SPEC D1, D2`, `CON-TOP-001 §2` | `uart_apb` register offsets, baud divisor programming, 8N1 TX/RX frame timing, RX status/overrun, `PSLVERR` on invalid offset/access | `VER-UART-001..N` (`BLOCKED`) | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `SPEC E1, E2`, `CON-TOP-001 §2` | `gpio_apb` register offsets, 8-bit direction (`gpio_oe_o`), output (`gpio_o`), input (`gpio_i`) sampling/synchronization, `PSLVERR` conditions | `VER-GPIO-001..N` (`BLOCKED`) | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `SPEC F1`, `CON-TOP-001 §2` | `timer_apb` register offsets, 32-bit counter enable/reset/wrap, compare match sticky/clear semantics, `PSLVERR` conditions | `VER-TIMER-001..N` (`BLOCKED`) | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `SPEC H2` | Combined peripheral integration verification scenario (Timer + GPIO + UART register interaction) | `VER-PERIPH-INT-001` (`BLOCKED`) | `BLOCKED (awaiting approved peripheral register-map contract)` |

---

## 4. Detailed Verification Test Suite Catalog (`SOC_VB_001`)

### 4.1 Firmware-Driven Core & Fault Tests (Specified in `verification/firmware/`)
- **`VER-CORE-001`:** RV32I ALU, shifts (`SLL/SRL/SRA/SLLI/SRLI/SRAI`), signed/unsigned comparisons (`SLT/SLTU/SLTI/SLTIU`), upper immediates (`LUI/AUIPC`), all 6 branch conditions (taken & untaken, forward & backward), `JAL`/`JALR` (including bit-0 masking), `x0` write-ignore & read-zero, read-after-write data dependencies, and `FENCE` single-cycle NOP completion.
- **`VER-CORE-002`:** Modified Harvard `irom_local` Port B `.rodata` loads (`LB/LBU/LH/LHU/LW` across offsets `0..3` / `0,2`, sign-extension of negative bytes/halfwords vs zero-extension, boundary words at `0x0000_0000` and `0x0000_7FFC`, 2-cycle read-use latency) AND `dram_local` `Option RAM-B` stores/loads (`SB/SH/SW` + `LB/LBU/LH/LHU/LW`, unmasked neighbor-byte preservation, boundary accesses at `0x2000_0000` and `0x2000_7FFC`, store-followed-by-load and load-followed-by-store).
- **`VER-CORE-003`:** APB3 bus-level `SW`/`LW` to Slot 0 (`0x4000_0000`), Slot 1 (`0x4000_1000`), and Slot 2 (`0x4000_2000`) plus upper slot words (`+0xFFC`) executed against TB Mock APB3 Completers with `0, 1, 2, 5` wait states. Verifies readback integrity, back-to-back APB3 transfers, `FENCE` after APB3, and single-commit semantics (no duplicate writes/reads). *(Uses Mock APB3 scratchpad; does NOT assume real peripheral register maps.)*
- **`VER-FAULT-001` (`FAULT_IF_UNMAPPED` `4'h2`):** `JALR` to `0x0000_8000` (first byte past `IROM`), `0x2000_0000` (`DRAM` non-executable), and `0x4000_0000` (`APB3` non-executable). Checks `fault_pc == target`, `fault_addr == target`, `fault_insn == 32'h0`, zero fetch on Port A, zero mutation.
- **`VER-FAULT-002` (`FAULT_IF_MISALIGNED` `4'h1`):** `JALR` to `IROM` address with `pc[1:0] == 2'b10` (e.g., `0x0000_0202`). Checks `fault_pc == 0x0000_0202`, `fault_addr == 0x0000_0202`, `fault_insn == 32'h0`.
- **`VER-FAULT-003` (`FAULT_ILLEGAL_INSN` `4'h3`):** Directed subcases for `32'h0000_0000`, `32'hFFFF_FFFF`, `CSRRW` (`0x3000_9073`), `MRET` (`0x3020_0073`), `MUL` (`0x0220_80B3`), and `FENCE.I` (`0x0000_100F`). Checks `fault_pc`, `fault_insn == opcode`, `fault_addr == 32'h0`.
- **`VER-FAULT-004` (`FAULT_ECALL` `4'h4`):** Executes `ECALL` (`0x0000_0073`) and verifies halt + sentinel protection.
- **`VER-FAULT-005` (`FAULT_EBREAK` `4'h5`):** Executes `EBREAK` (`0x0010_0073`) and verifies halt + sentinel protection.
- **`VER-FAULT-006` (`FAULT_DATA_UNMAPPED` `4'h7`):** Directed subcases for unmapped gap addresses (`0x0000_8000`, `0x1FFF_FFFC`, `0x2000_8000`, `0x4001_0000`) AND reserved APB3 slots (`0x4000_3000`, `0x4000_FFFC`). Verifies zero `apb_req_valid` / `dram_req` / `irom_dreq`.
- **`VER-FAULT-007` (`FAULT_DATA_RO_WRITE` `4'hA`):** Directed subcases for `SW`, `SH`, `SB` targeting `IROM` (`0x0000_0000`–`0x0000_7FFF`). Verifies ROM intact, `fault_code == 4'hA`.
- **`VER-FAULT-008` (`FAULT_DATA_SIZE_UNSUP` `4'h8`):** Directed subcases for `LB`, `LBU`, `LH`, `LHU`, `SB`, `SH` targeting populated APB3 slots (`0x4000_0000`, `0x4000_1000`, `0x4000_2000`). Verifies zero APB3 `PSELx` activity.
- **`VER-FAULT-009` (`FAULT_DATA_MISALIGNED` `4'h6`):** Directed subcases for `LH`/`LHU` at odd offset in `IROM`/`DRAM`, `LW` at `+1/+2/+3` in `IROM`/`DRAM`/`APB3`, `SH` at odd offset in `DRAM`, `SW` at `+1/+2/+3` in `DRAM`/`APB3`.
- **`VER-FAULT-010` (`FAULT_APB_SLVERR` `4'h9`):** Directed `LW` and `SW` to populated APB3 slots where Mock APB3 Completer returns `PREADY=1, PSLVERR=1` (both 0-wait and multi-wait). Verifies `RF[rd]` is NOT modified on `LW` `PSLVERR`, `PC` freezes at `fault_pc`, and `apb3_bridge` returns cleanly to `IDLE`.
- **`VER-FAULT-011` (Fault Priority Matrix):** Verifies all overlapping priority pairs from `CON-FLT-RST-001` §1.2:
  1. `FAULT_IF_UNMAPPED` > `FAULT_IF_MISALIGNED` (`JALR` to `0x0000_8002` -> `4'h2`).
  2. `FAULT_DATA_UNMAPPED` > `FAULT_DATA_RO_WRITE`/`SIZE_UNSUP`/`MISALIGNED` (`SH` to `0x0000_8001` and `SB` to `0x4000_3001` -> `4'h7`).
  3. `FAULT_DATA_RO_WRITE` > `FAULT_DATA_MISALIGNED` (`SW` to `0x0000_0102`, `SH` to `0x0000_0101` -> `4'hA`).
  4. `FAULT_DATA_SIZE_UNSUP` > `FAULT_DATA_MISALIGNED` (`LH` to `0x4000_0001`, `SH` to `0x4000_1003` -> `4'h8`).
  5. Sticky first-fault-wins: once halted, forcing subsequent instructions/conditions cannot overwrite `fault_code/pc/insn/addr`.

### 4.2 Testbench-Driven Reset & Bus Corner Tests
- **`VER-RST-001` (Cold Reset & `rst_sync` Release):** Asserts `rst_n = 0` asynchronously mid-cycle and across clock edges; verifies immediate `sys_rst_n == 0` / `PRESETn == 0`, exact 2-FF synchronous release after `rst_n` returns `1`, and reset state of `PC`, `x1..x31`, `fault_*_o`, `apb3_bridge`, `local_rd_valid`, `dram_rdata`, `irom_drdata`, `uart_tx_o`, `gpio_oe_o`, `gpio_o`.
- **`VER-RST-002` (Reset Recovery During Stall & Fault):**
  - Subcase A: Assert `rst_n = 0` while `apb3_bridge` is stalled in `ACCESS` (`PREADY = 0`); verify clean abort to `IDLE`, no stale completion, and deterministic restart from `0x0000_0000`.
  - Subcase B: Assert `rst_n = 0` during 2-cycle local load (`local_rd_valid == 1` or `C0`); verify `local_rd_valid` clears to `0` and no stale `RF` write occurs after release.
  - Subcase C: Assert `rst_n = 0` after CPU has halted with `fault_valid == 1`; verify `fault_*` clears to `0` and execution restarts from `0x0000_0000` (while `DRAM` retains prior values unless firmware clears it per `CON-MEM-001` §2.6).
- **`VER-BUS-001` (APB3 Wait-State Stress & Non-Target Isolation):**
  - Exercises `0, 1, 2, 5, 16` wait states across read (`LW`) and write (`SW`) on Slots 0, 1, 2, verifying `PSELx` mutual exclusion, `PSLVERR` ignored when `PREADY == 0` (Mock intentionally glitches `PSLVERR=1` while `PREADY=0` and drops it to `0` when `PREADY=1` — must NOT fault!), and `PRDATA` ignored until `PSELx && PENABLE && PREADY`.

---

## 5. Human Approval Gate to Freeze `SOC_VB_001`

To promote `SOC_VB_001` from `PROPOSED` to `APPROVED`:
1. Human reviews and approves `VERIFICATION_PLAN_V1.md`, `SVA_SPECIFICATION_V1.md`, `COVERAGE_PLAN_V1.md`, and the `verification/firmware/` core test suite & `DRAM` mailbox convention (`0x2000_7F00`–`0x2000_7FFF`).
2. Peripheral register-map tests remain `BLOCKED` under `SOC_VB_001` and will be unlocked in `SOC_VB_002` once the peripheral register-map architecture contract is approved.
