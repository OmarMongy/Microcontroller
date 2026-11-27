# Fault Handling and Reset Interface Contract

- **Contract ID:** `CON-FLT-RST-001`
- **Version:** `v1.1`
- **Status:** `APPROVED (DEC-ARCH-CORE-001, DEC-ARCH-CORE-002)`
- **Date:** 2026-11-27
- **Parent Proposal:** [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md)
- **Approved Decisions:** [DEC-ARCH-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-BASELINE-001.md), [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) (Decisions #1, #2, #6, #7), [DEC-ARCH-CORE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-002.md) (`IROM` Port B sync read, `FAULT_DATA_RO_WRITE`, `FENCE`), [SOC_SPECIFICATION_DRAFT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/specifications/SOC_SPECIFICATION_DRAFT.md) Sections 8–9.

---

## 1. Fault-and-Halt Architecture

This platform implements an educational **fault-and-halt** policy (not RISC-V privileged traps/`mtvec`). Any fatal fault captures diagnostic context, sets visible fault status outputs, suppresses architectural mutation for the faulting instruction, and halts execution until external reset (`rst_n == 0`).

### 1.1 Fault Code Encoding (`fault_code[3:0]`)

| Code | Symbolic Name | Status | Trigger Condition | `fault_pc` | `fault_insn` | `fault_addr` |
|---|---|---|---|---|---|---|
| `4'h0` | `FAULT_NONE` | `APPROVED` | Normal execution (no fault latched) | `32'h0` | `32'h0` | `32'h0` |
| `4'h1` | `FAULT_IF_MISALIGNED` | `APPROVED` | `pc[1:0] != 2'b00` (e.g. misaligned `JAL`/`JALR`/branch target) | `pc` | `32'h0` | `pc` |
| `4'h2` | `FAULT_IF_UNMAPPED` | `APPROVED` | `pc` outside `IROM` (`0x0000_0000`–`0x0000_7FFF`) | `pc` | `32'h0` | `pc` |
| `4'h3` | `FAULT_ILLEGAL_INSN` | `APPROVED` | Instruction word not in RV32I base integer ISA (includes `CSRR*`, `MRET`/`WFI`, `M`/`C`/`F` opcodes, `0x0000_0000`, `0xFFFF_FFFF`). Note: `FENCE` (`opcode 7'b0001111, funct3 3'b000`) is a valid single-cycle `NOP`, provided all preceding memory transactions have completed before retirement. | `pc` | `insn` | `32'h0` |
| `4'h4` | `FAULT_ECALL` | `APPROVED` | `insn == 32'h0000_0073` (`ECALL`) | `pc` | `insn` | `32'h0` |
| `4'h5` | `FAULT_EBREAK` | `APPROVED` | `insn == 32'h0010_0073` (`EBREAK`) | `pc` | `insn` | `32'h0` |
| `4'h6` | `FAULT_DATA_MISALIGNED` | `APPROVED` | `LH`/`LHU` with `daddr[0] != 0` or `LW` with `daddr[1:0] != 0` in `IROM`/`DRAM`/`APB3`; or `SH` with `daddr[0] != 0` or `SW` with `daddr[1:0] != 0` in `DRAM`/`APB3` | `pc` | `insn` | `daddr` |
| `4'h7` | `FAULT_DATA_UNMAPPED` | `APPROVED` | `LOAD`/`STORE` effective address outside `IROM`, `DRAM`, and populated `APB3` slots (including reserved APB slots `0x4000_3000`–`0x4000_FFFF`) | `pc` | `insn` | `daddr` |
| `4'h8` | `FAULT_DATA_SIZE_UNSUP` | `APPROVED` | `LB`/`LBU`/`LH`/`LHU`/`SB`/`SH` targeting populated `APB3` window (`Option APB-W1`) | `pc` | `insn` | `daddr` |
| `4'h9` | `FAULT_APB_SLVERR` | `APPROVED` | APB3 transfer completes (`PSELx && PENABLE && PREADY`) with `PSLVERR == 1` | `pc` | `insn` | `daddr` |
| `4'hA` | `FAULT_DATA_RO_WRITE` | `APPROVED` | `STORE` (`SB`/`SH`/`SW`) targeting read-only `IROM` (`0x0000_0000`–`0x0000_7FFF`) under Modified Harvard (`DEC-ARCH-CORE-001`, `DEC-ARCH-CORE-002`) | `pc` | `insn` | `daddr` |
| `4'hB..4'hF` | *Reserved* | — | Unused | — | — | — |

### 1.2 Priority Order (When Multiple Conditions Could Apply in One Cycle)
Evaluation proceeds strictly in architectural stage order (highest priority first):
1. `FAULT_IF_UNMAPPED` (Priority 1 — invalid instruction address stops fetch/decode)
2. `FAULT_IF_MISALIGNED` (Priority 2 — misaligned instruction address stops fetch/decode)
3. `FAULT_ECALL` / `FAULT_EBREAK` / `FAULT_ILLEGAL_INSN` (Priority 3 — mutually exclusive decode encodings)
4. `FAULT_DATA_UNMAPPED` (Priority 4 — evaluated only for valid `LOAD`/`STORE` opcodes)
5. `FAULT_DATA_RO_WRITE` (Priority 5 — evaluated when `STORE` targets `IROM`; checked before size/alignment so any write attempt to ROM clearly reports read-only write violation)
6. `FAULT_DATA_SIZE_UNSUP` (Priority 6 — evaluated only for valid `LOAD`/`STORE` in populated `APB3` slots)
7. `FAULT_DATA_MISALIGNED` (Priority 7 — evaluated only for valid `LOAD`/`STORE` in valid region, permitted access direction, & supported size)
8. `FAULT_APB_SLVERR` (Priority 8 — evaluated at APB3 `ACCESS && PREADY` completion edge)

### 1.3 Visible Fault Status & Captured Context Signals (`APPROVED — DEC-ARCH-CORE-001`)

| Signal | Width | Direction (from `rv32i_cpu`) | Reset Value | Description |
|---|---:|---|---|---|
| `fault_valid` | 1 | Output | `1'b0` | Sticky active-HIGH halt/fault status (`1` = CPU faulted and halted). Exposed as `fault_o` at `soc_top`. |
| `fault_code` | 4 | Output | `4'h0` | Sticky 4-bit fault code from Section 1.1. Exposed as `fault_code_o` at `soc_top`. |
| `fault_pc` | 32 | Output | `32'h0000_0000` | Sticky `PC` of the faulting instruction. Exposed as `fault_pc_o` at `soc_top`. |
| `fault_insn` | 32 | Output | `32'h0000_0000` | Sticky 32-bit instruction word (`32'h0` on IF faults). Exposed as `fault_insn_o` at `soc_top`. |
| `fault_addr` | 32 | Output | `32'h0000_0000` | Sticky faulting address (`pc` on IF faults; `daddr` on Data/APB faults; `32'h0` on decode faults). Exposed as `fault_addr_o` at `soc_top`. |

### 1.4 Halt State Guarantees & Recovery
On the `posedge clk` where `!fault_valid && fault_detect`:
- **Capture:** `fault_valid <= 1'b1` and `fault_code/pc/insn/addr` latch the highest-priority fault context.
- **No State Corruption:** `PC` does **not** advance (remains frozen at `fault_pc`); `RF` writeback is suppressed (`rf_we = 0`); `DRAM` write is suppressed (`dram_req = 0`); `irom_dreq = 0`; no new APB transfer is started.
- **While Halted (`fault_valid == 1`):**
  - `fault_*` registers are **sticky** (first fault wins; never overwritten by subsequent cycles).
  - `PC` stays frozen; `irom_en = 0`, `irom_dreq = 0`, `dram_req = 0`, `apb_req_valid = 0`, `rf_we = 0`.
  - APB3 bridge remains in `IDLE` (`PSELx = 0`, `PENABLE = 0`).
- **Recovery:** Only asserting external reset (`rst_n == 0`) clears `fault_valid` and restarts execution from `PC = 0x0000_0000`.

---

## 2. Reset Architecture & Reset Values (`APPROVED — DEC-ARCH-CORE-001`)

### 2.1 External Reset & Safe Internal Reset Release (`Option RST-A — APPROVED`)
- **External Input:** `rst_n` (active-LOW asynchronous external reset).
- **Reset Synchronizer (`rst_sync`):** 2-stage flip-flop synchronizer with **asynchronous assertion** and **synchronous deassertion** on `posedge clk` (50 MHz):
  - When `rst_n == 0`: `sync_ff1` and `sync_ff2` asynchronously clear to `1'b0` immediately, asserting `sys_rst_n = 1'b0` (and `PRESETn = 1'b0`).
  - When `rst_n` transitions `0 -> 1`: `sync_ff1` samples `1'b1` on the first `posedge clk`, and `sync_ff2` (`sys_rst_n`) releases to `1'b1` cleanly on the second `posedge clk`.
  - **Minimum External Pulse Width:** `rst_n` should be held LOW for at least 1 `clk` period (or asynchronous pulse sufficient to clear synchronizer FFs); synchronous release guarantees zero reset-recovery metastability across CPU, local memories, bridge, and peripherals.

### 2.2 Reset Values Across All Subsystems (`APPROVED — DEC-ARCH-CORE-001`)

| Subsystem | State Element | Reset Value (`sys_rst_n == 0` / `PRESETn == 0`) | Notes |
|---|---|---|---|
| **`rv32i_cpu`** | `PC` | `32'h0000_0000` | Approved reset vector (`D1`). First instruction fetched after `sys_rst_n` releases to `1`. |
| **`rv32i_cpu`** | Register File `x0` | Hardwired `32'h0000_0000` | Always reads `0`; writes ignored. |
| **`rv32i_cpu`** | Register File `x1..x31` | `32'h0000_0000` | Explicit reset to `0` for deterministic educational simulation. |
| **`rv32i_cpu`** | `fault_valid`, `fault_code`, `fault_pc`, `fault_insn`, `fault_addr` | `0` | Cleared on reset. |
| **`data_bus_decode`** | `local_rd_valid` | `1'b0` | Ensures no stale 2-cycle local read completion on reset release. |
| **`irom_local`** | ROM array | Retained (loaded from `.hex`/`.mem`) | Read-only memory; unaffected by `rst_n`. `irom_en` and `irom_dreq` gated to `0` during reset. |
| **`irom_local`** | Port B `irom_drdata` | `32'h0000_0000` | Synchronous read output register resets to `0` (valid only when `local_rd_valid == 1`). |
| **`dram_local`** | Control / write enable | Writes suppressed (`dram_req` gated off) | Prevents spurious writes during reset assertion/release. |
| **`dram_local`** | `dram_rdata` | `32'h0000_0000` | Synchronous read output register resets to `0` (valid only when `local_rd_valid == 1`). |
| **`dram_local`** | 32 KB storage array | **No hardware reset tree** (`0` at sim time-0) | Software `.bss` init handles warm-reset RAM clearing; avoids 262,144-FF reset tree in synthesis. |
| **`apb3_bridge`** | FSM state | `IDLE` | `PSELx = 0`, `PENABLE = 0`, `PWRITE = 0`, `PADDR = 32'h0`, `PWDATA = 32'h0`. |
| **`uart_apb`** | High-level peripheral state | Idle, TX line HIGH (`1`), 8N1 @ 115200 baud default | Exact register bit reset values deferred to peripheral register-map task. |
| **`gpio_apb`** | High-level peripheral state | All 8 pins configured as inputs (`gpio_oe_o = 8'h00`), `gpio_o = 8'h00` | Safe high-Z / non-driving reset state; exact register map deferred. |
| **`timer_apb`** | High-level peripheral state | Disabled/stopped, 32-bit counter = `32'h0000_0000` | Exact register map deferred. |
