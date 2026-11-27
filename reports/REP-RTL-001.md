# Task Report

- Report ID: `REP-RTL-001`
- Date/time: `2026-11-27 15:02 (+02:00)`
- Agent/role: RTL Designer Agent
- Task: `RTL-001` — Gates 2 & 3 (Synthesizable SystemVerilog RTL Implementation, Verilator Lint, and Yosys Generic Synthesis)
- Status: `PASS`
- Relevant spec/interface revision:
  - `docs/specifications/SOC_SPECIFICATION_DRAFT.md` (Draft 0.3)
  - `CON-ADDR-001` v1.1 (`ADDRESS_MAP_CONTRACT.md`)
  - `CON-MEM-001` v1.1 (`LOCAL_MEMORY_INTERFACE_CONTRACT.md`)
  - `CON-APB3-001` v1.1 (`APB3_BRIDGE_CONTRACT.md`)
  - `CON-FLT-RST-001` v1.1 (`FAULT_AND_RESET_CONTRACT.md`)
  - `CON-TOP-001` v1.1 (`SOC_TOP_HIERARCHY_CONTRACT.md`)
  - `CON-PERIPH-001` v1.0 (`PERIPHERAL_REGISTER_MAP_CONTRACT.md`)
  - Approved Decisions: `DEC-ARCH-BASELINE-001`, `DEC-ARCH-BASELINE-002`, `DEC-CPU-APB-WAIT-001`, `DEC-ARCH-CORE-001`, `DEC-ARCH-CORE-002`, `DEC-ARCH-PERIPH-001`
- Git branch/commit: `dev/gate2-4-rtl-and-verif` (branched from `main` checkpoint `85dcd83`, `UNCOMMITTED`)

## Work performed

Implemented clean, synthesizable SystemVerilog RTL under `rtl/` for all 10 approved modules, a shared constants/encodings package (`rtl/soc_pkg.sv`), and a synthesis/lint filelist (`rtl/rtl.f`), strictly derived from the six frozen interface contracts and six approved human decisions:

1. `rtl/soc_pkg.sv`: Defines `fault_code_e` (`4'h0`–`4'hA`), `dmem_size_e` (`2'b00`–`2'b10`), and top-level address prefixes (`IROM_BASE_PREFIX`, `DRAM_BASE_PREFIX`, `APB_UART_PREFIX`, `APB_GPIO_PREFIX`, `APB_TIMER_PREFIX`).
2. `rtl/rst_sync.sv`: 2-FF asynchronous-assert (`negedge rst_n`), synchronous-deassert (`posedge clk`) reset synchronizer (`Option RST-A`). Includes a documented `/* verilator lint_off SYNCASYNCNET */` waiver on `sync_ff2` (`sys_rst_n`), because `sys_rst_n` drives async-reset registers across CPU/peripherals while `dram_local`'s 32 KB storage array intentionally omits a hardware async reset tree (`CON-MEM-001` §2.6) and gates writes synchronously with `sys_rst_n`.
3. `rtl/rv32i_cpu.sv`: Single-cycle RV32I core (`LUI`, `AUIPC`, `JAL`, `JALR`, `BEQ`/`BNE`/`BLT`/`BGE`/`BLTU`/`BGEU`, `LB`/`LH`/`LW`/`LBU`/`LHU`, `SB`/`SH`/`SW`, `ADDI`/`SLTI`/`SLTIU`/`XORI`/`ORI`/`ANDI`/`SLLI`/`SRLI`/`SRAI`, `ADD`/`SUB`/`SLL`/`SLT`/`SLTU`/`XOR`/`SRL`/`SRA`/`OR`/`AND`, `FENCE` single-cycle NOP after prior memory completion, `ECALL`, `EBREAK`). Implements `PC=0` and `x1..x31=0` reset (`x0` hardwired `0`), `dmem_stall` hold / exactly-once commit gating, IF/decode/data fault capture in strict contract priority order (`CON-FLT-RST-001` §1.2), and sticky halt state until external reset.
4. `rtl/irom_local.sv`: 32 KB (`8192 x 32`) dual-port Modified Harvard ROM: Port A 0-cycle combinational fetch (`irom_en` gated), Port B 1-cycle synchronous read-only data port (`irom_dreq`/`irom_drdata` reset to `0`), and `INIT_FILE` `$readmemh` initialization defaulting unprogrammed words to `32'h0` guarded under `` `ifndef SYNTHESIS `` so Yosys generic synthesis handles `INIT_FILE == ""` cleanly.
5. `rtl/dram_local.sv`: 32 KB (`8192 x 32`) local RAM (`Option RAM-B`): 1-cycle synchronous read (`dram_rdata` reset to `32'h0`) and 1-cycle synchronous byte-enabled write (`dram_be[3:0]`), with no hardware `rst_n`/`sys_rst_n` reset tree on the 32 KB storage array (`CON-MEM-001` §2.6).
6. `rtl/data_bus_decode.sv`: Modified Harvard data decoder across `IROM` (RO), `DRAM` (RW), populated `APB3` slots `0..2`, and unmapped space; enforces priority-ordered pre-check faults (`FAULT_DATA_UNMAPPED`, `FAULT_DATA_RO_WRITE`, `FAULT_DATA_SIZE_UNSUP`, `FAULT_DATA_MISALIGNED`); implements the 2-cycle `local_rd_valid` / `local_read_stall` handshake for `IROM` Port B and `DRAM` reads; performs little-endian `dram_be` and lane placement with `0` in unmasked lanes; muxes `dmem_rdata`, `dmem_stall`, and `dmem_fault_*` (`FAULT_APB_SLVERR`).
7. `rtl/apb3_bridge.sv`: Strict ARM `IHI0024E` APB3 Requester (`Design 4A`, no APB4/APB5 signals) with `IDLE -> SETUP -> ACCESS` FSM, registered `PADDR`/`PSEL_UART`/`PSEL_GPIO`/`PSEL_TIMER`/`PENABLE`/`PWRITE`/`PWDATA`, wait-state hold on `PREADY=0`, and `PSLVERR` sampled only on `ACCESS && PREADY`.
8. `rtl/uart_apb.sv`: `CON-PERIPH-001` §2 8N1 UART (`UART_CTRL` reset `32'h3`, `UART_STATUS` reset `32'h2` with `W1C` `RX_FRAME_ERR`/`RX_OVERRUN`, `UART_TX_DATA` `WO`, `UART_RX_DATA` `RO` read-clear `RX_VALID`, `UART_BAUD_DIV` 24-bit default `434` requiring `>= 2`), 2-FF `uart_rx_i` synchronizer reset to `1'b1`, mid-bit start sampling at `(BAUD_DIV >> 1) - 1` cycles after start-edge capture (supporting all valid `BAUD_DIV >= 2`), `PREADY=1'b1`, and strict `PSLVERR`.
9. `rtl/gpio_apb.sv`: `CON-PERIPH-001` §3 8-bit GPIO (`GPIO_DATA_IN` with 2-FF `gpio_i` synchronizer, `GPIO_DATA_OUT`, `GPIO_DIR`, reset `0`), `PREADY=1'b1`, and strict `PSLVERR`.
10. `rtl/timer_apb.sv`: `CON-PERIPH-001` §4 32-bit timer (`TIMER_CTRL` with `EN`/`AUTO_RELOAD`/`CLR_CNT`, `TIMER_STATUS` with `W1C` `MATCH`/`OVF`, `TIMER_COUNTER`, `TIMER_COMPARE` reset `32'hFFFF_FFFF`), exact counter next-state precedence (`TIMER_COUNTER` write > `CLR_CNT` > `AUTO_RELOAD` match > `EN` increment) and hardware-event precedence over concurrent `W1C`, `PREADY=1'b1`, and strict `PSLVERR`.
11. `rtl/soc_top.sv`: Top-level structural integration matching `CON-TOP-001` §3 port list (`clk`, `rst_n`, `uart_rx_i`, `uart_tx_o`, `gpio_i`, `gpio_o`, `gpio_oe_o`, `fault_o`, `fault_code_o`, `fault_pc_o`, `fault_addr_o`, `fault_insn_o`) and parameter `IROM_INIT_FILE` passed to `u_irom_local`.

### Design Notes for Yosys Compatibility
- Untyped string parameters (`parameter IROM_INIT_FILE = ""`, `parameter INIT_FILE = ""`) and explicit `soc_pkg::` scope resolution inside module bodies (rather than `import soc_pkg::*;` in module headers/bodies) were used so the RTL compiles cleanly in both Verilator 5.032 and Yosys 0.52 `read_verilog -sv`.

## Files created/changed

- Created:
  - [soc_pkg.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/soc_pkg.sv)
  - [rst_sync.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/rst_sync.sv)
  - [rv32i_cpu.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/rv32i_cpu.sv)
  - [irom_local.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/irom_local.sv)
  - [dram_local.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/dram_local.sv)
  - [data_bus_decode.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/data_bus_decode.sv)
  - [apb3_bridge.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/apb3_bridge.sv)
  - [uart_apb.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/uart_apb.sv)
  - [gpio_apb.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/gpio_apb.sv)
  - [timer_apb.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/timer_apb.sv)
  - [soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/soc_top.sv)
  - [rtl.f](file:///mnt/e/PB/Projects/Microcontroller/rtl/rtl.f)
  - [REP-RTL-001.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-RTL-001.md)

## Commands and tool versions

- Tool versions:
  - `Verilator 5.032 2025-01-01 rev (Debian 5.032-1)` (`verilator --version`)
  - `Yosys 0.52 (git sha1 fee39a3284c90249e1d9684cf6944ffbbcbb8f90)` (`yosys -V`)

- Gate 3a — Verilator Lint (run after final RTL edit):
  ```bash
  verilator --lint-only -Wall --top-module soc_top -f rtl/rtl.f
  ```
  - Exit code: `0` (0 warnings, 0 errors).

- Gate 3b — Yosys Generic Synthesis (run after final RTL edit; temporary log written to `/tmp/yosys_soc.log` and deleted after inspection):
  ```bash
  yosys -p "read_verilog -sv rtl/soc_pkg.sv rtl/rst_sync.sv rtl/irom_local.sv rtl/dram_local.sv rtl/data_bus_decode.sv rtl/apb3_bridge.sv rtl/uart_apb.sv rtl/gpio_apb.sv rtl/timer_apb.sv rtl/rv32i_cpu.sv rtl/soc_top.sv; hierarchy -check -top soc_top; proc; opt; check; synth -top soc_top; stat"
  ```
  - Exit code: `0`.

## Results and evidence paths

### Verilator Lint Summary
- **Result:** `PASS` (`EXIT=0`, 0 warnings, 0 errors across all 12 modules/packages).
- **Waiver:** `SYNCASYNCNET` waived on `rst_sync.sync_ff2` (`sys_rst_n`) with inline rationale (async-reset CPU/peripheral FFs vs. synchronous write gating without async reset tree on the 32 KB `dram_local` array).
- **Waivers for intentionally unused upper/lower slice bits:** `UNUSEDSIGNAL` waived on `irom_addr[1:0]`, `irom_daddr[1:0]`, `dram_addr[1:0]`, `PADDR[31:12]` (peripherals), `PWDATA[31:24]` (`uart_apb`), and `PWDATA[31:8]` (`gpio_apb`).

### Yosys Generic Synthesis Summary
- **Result:** `PASS` (`EXIT=0`).
- **Inferred latches:** `0` (`0` `$_DLATCH_*` cells).
- **Check passes:** `Found and reported 0 problems.` across all pre- and post-synth `check` passes; `0` hierarchy/multi-driver errors.
- **Warnings (1 unique, 1 total):**
  - `Warning: Replacing memory \regfile with list of registers. See rtl/rv32i_cpu.sv:390` (expected, because `x1..x31` have explicit synchronous/async reset to `0` per `DEC-ARCH-CORE-001` Option RST-A).
- **Generic Cell / FF Statistics (`synth -top soc_top`):**

| Module | Cells | Key Sequential Elements / Notes |
|---|---:|---|
| `soc_top` (total hierarchy) | 578,845 | 263,587 FFs total (`262,144` `$_DFFE_PP_` + `1,345` `$_DFFE_PN0P_` + `48` `$_DFFE_PN1P_` + `46` `$_DFF_PN0_` + `2` `$_DFF_PN1_` + `2` `$_DFFE_PN0N_`), 0 latches |
| `dram_local` | 565,510 | `262,144` `$_DFFE_PP_` (32 KB array, no reset tree) + `32` `$_DFFE_PN0P_` (`dram_rdata`) |
| `irom_local` | 0 | Synthesized with `INIT_FILE=""` (`$readmemh` guarded by `` `ifndef SYNTHESIS ``), so empty unprogrammed ROM optimizes to `0` |
| `rv32i_cpu` | 10,322 | `1,122` `$_DFFE_PN0P_` + `1` `$_DFF_PN0_` (`fault_valid`) (Note: `pc[0]` and `fault_pc[0]` constant-folded to `0`) |
| `uart_apb` | 1,423 | `70` `$_DFFE_PN0P_` + `16` `$_DFFE_PN1P_` + `26` `$_DFF_PN0_` + `2` `$_DFF_PN1_` |
| `data_bus_decode` | 544 | `1` `$_DFF_PN0_` (`local_rd_valid`) |
| `timer_apb` | 532 | `34` `$_DFFE_PN0P_` + `32` `$_DFFE_PN1P_` (`TIMER_COMPARE=32'hFFFF_FFFF`) + `2` `$_DFFE_PN0N_` |
| `apb3_bridge` | 386 | `71` `$_DFFE_PN0P_` (FSM + registered APB3 outputs) |
| `gpio_apb` | 126 | `16` `$_DFFE_PN0P_` + `16` `$_DFF_PN0_` (2-FF `gpio_i` synchronizer + `gpio_o`/`gpio_oe_o`) |
| `rst_sync` | 2 | `2` `$_DFF_PN0_` (`sync_ff1`, `sync_ff2`) |

*(Note per `rtl-synthesis` skill: generic synthesis statistics are an implementation-quality check only, not FPGA resource usage, ASIC area, or physical timing closure.)*

- **Evidence:**
  - RTL sources and filelist under [rtl/](file:///mnt/e/PB/Projects/Microcontroller/rtl/)
  - This report: [REP-RTL-001.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-RTL-001.md)

## Assumptions / unresolved questions

- **None (no specification ambiguities encountered).** All 10 modules mapped unambiguously from the six frozen contracts (`CON-ADDR-001`, `CON-MEM-001`, `CON-APB3-001`, `CON-FLT-RST-001`, `CON-TOP-001`, `CON-PERIPH-001`) and approved human decisions.
- Note on `irom_local` in generic synthesis: because `IROM_INIT_FILE` defaults to `""` and `$readmemh` is guarded by `` `ifndef SYNTHESIS ``, Yosys generic synthesis folds the uninitialized ROM module (`irom_local`) to 0 cells when synthesizing `soc_top` standalone with default `IROM_INIT_FILE=""`, while keeping `rv32i_cpu` intact (10,322 cells) across the unflattened module boundary.

## Recommended next action

1. Human / Orchestrator review of Gate 2–3 RTL implementation and [REP-RTL-001.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-RTL-001.md).
2. Proceed to Gate 4 / Gate 5 independent verification and simulation against `SOC_VB_001` / `SOC_VB_002` (owned by Independent Verification Engineer).
