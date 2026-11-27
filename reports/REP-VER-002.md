# Task Report

- Report ID: `REP-VER-002`
- Date/time: `2026-11-27T15:13:00+02:00`
- Agent/role: Independent Verification Engineer Agent
- Task: `VER-002` & `VER-003` (`SOC_VB_002` Peripheral Verification Extension, Gate 4 Testbench/SVA Infrastructure, and RTL/TB/SVA Integration Alignment)
- Status: `REVIEW_REQUIRED` (`SOC_VB_002` deliverables and Gate 4 `tb/`/`sva/` authored, aligned to `rtl/` ports, and verified via integrated Verilator lint + C++ compilation/elaboration with 0 warnings/0 errors; firmware compilation & Gate 5 simulation `NOT_RUN` — RISC-V GNU toolchain required as Gate 5 prerequisite; `SOC_VB_002` `PROPOSED — PENDING HUMAN APPROVAL`)
- Relevant spec/interface revision: `SOC_SPECIFICATION_DRAFT.md` (Draft 0.3); `DEC-ARCH-BASELINE-001`, `DEC-ARCH-BASELINE-002`, `DEC-CPU-APB-WAIT-001`, `DEC-ARCH-CORE-001`, `DEC-ARCH-CORE-002`, `DEC-ARCH-PERIPH-001`, `DEC-VER-BASELINE-001` (`SOC_VB_001` frozen); `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1 (+ `ARM IHI 0024E` APB3 / Issue B), `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1, `CON-PERIPH-001` v1.0
- Git branch/commit: `dev/gate2-4-rtl-and-verif` (branched from `main` checkpoint `85dcd83`, with uncommitted `VER-002` changes)

## Work performed
1. Read [DEC-ARCH-PERIPH-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-PERIPH-001.md), [DEC-VER-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-001.md), and [PERIPHERAL_REGISTER_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/PERIPHERAL_REGISTER_MAP_CONTRACT.md) (`CON-PERIPH-001` v1.0). Strictly avoided inspecting or modifying anything under `rtl/` and preserved all immutable `SOC_VB_001` files untouched.
2. Authored `SOC_VB_002` verification plans (`PROPOSED — PENDING HUMAN APPROVAL`):
   - `docs/verification_plans/VERIFICATION_PLAN_V2.md` (extends `SOC_VB_001` with `uart_apb`, `gpio_apb`, `timer_apb`, integrated peripheral test traceability, BFM handshake protocol, and Gate 4 infrastructure).
   - `docs/verification_plans/SVA_SPECIFICATION_V2.md` (adds `SVA-UART-001..008`, `SVA-GPIO-001..005`, `SVA-TIMER-001..008`, `COV-SVA-011..019`, and splits `SVA-CPU-006` into clean IEEE 1800-2017 / Verilator-safe `p_cpu_fence_ctrl` and `p_cpu_fence_pc_step`).
   - `docs/verification_plans/COVERAGE_PLAN_V2.md` (adds `CG-UART-REG`, `CG-GPIO-REG`, `CG-TIMER-REG`, and `CG-PERIPH-INT`).
3. Authored peripheral verification firmware under `verification/firmware/`:
   - `include/periph_regs.inc`, `src/crt0_periph.S` (preserving immutable `crt0.S`), `TEST_MANIFEST_V2.md`, and appended `SOC_VB_002` targets to `Makefile` without altering existing `SOC_VB_001` targets.
   - `VER_UART_001.S` (reset defaults, `BAUD_DIV`, `TX_EN=0`, `TX_BUSY`/`TX_EMPTY`, write-while-busy ignored, reserved bits, RX reception & `RX_VALID` read-clear, `RX_OVERRUN` sticky + `W1C`, `RX_FRAME_ERR` sticky + `W1C`).
   - `VER_UART_002.S` (`PSLVERR` subcases `0..4`: read `WO` `UART_TX_DATA`, write `RO` `UART_RX_DATA`, `BAUD_DIV=1/0`, unimplemented `0x014`).
   - `VER_GPIO_001.S` (reset defaults, reserved bits, `GPIO_DIR`/`GPIO_DATA_OUT` walking-1/0, 2-FF `gpio_i` echo sampling).
   - `VER_GPIO_002.S` (`PSLVERR` subcases `0..2`: write `RO` `GPIO_DATA_IN`, unimplemented `0x00C`/`0xFFC`).
   - `VER_TIMER_001.S` (reset defaults `COMPARE=0xFFFF_FFFF`, `EN=0` pause, free-running `MATCH` + `W1C`, `CLR_CNT` `WO/SC`, `AUTO_RELOAD=1`, direct `COUNTER` write while `EN=1`, `0xFFFF_FFFF` wrap `OVF` + `W1C`).
   - `VER_TIMER_002.S` (`PSLVERR` subcases `0..1`: unimplemented `0x010`/`0xFFC`).
   - `VER_PERIPH_INT_001.c` (bare-metal C integrated Timer + GPIO + UART test using `DRAM` verification mailbox).
4. Authored Gate 4 testbench & SVA modules (`tb/` and `sva/`) derived strictly from the six frozen contracts:
   - `tb/tb_pkg.sv`, `tb/mock_apb_completer.sv`, `tb/rv32i_golden_iss.sv` (independent behavioral RV32I + Modified Harvard + APB3 reference model/scoreboard), `tb/tb_cov_collector.sv`, `tb/tb_core_bus.sv`, `tb/tb_soc_top.sv` (with UART 8N1 & GPIO BFMs).
   - `sva/sva_apb3_if.sv`, `sva/sva_mem_if.sv`, `sva/sva_cpu_fault_rst.sv`, `sva/sva_periph_if.sv`, `sva/sva_binds.sv` (Part A port-boundary binds separated from `SVA_ENABLE_INTERNAL_BINDS`-guarded Part B binds).
5. Ran standalone `verilator --lint-only --assert` on all standalone `sva/` and `tb/` modules, resolving Verilator 5.032 SVA sequence limitations via clocked auxiliary shadow state so all 10 lint invocations exited `0`.
6. **Task `VER-003` Integration Alignment:** Inspected `rtl/rtl.f` and module port/parameter declarations under `rtl/` (without modifying `rtl/`) and aligned:
   - `tb/tb_soc_top.sv`: Updated `soc_top` parameter binding from `.INIT_FILE(INIT_FILE)` to `.IROM_INIT_FILE(INIT_FILE)`.
   - `tb/tb_core_bus.sv`: Updated `data_bus_decode` port from `.fault_valid(fault_valid)` to `.cpu_fault_valid(fault_valid)`, and wired all 9 individual completer ports (`PREADY_UART/GPIO/TIMER`, `PRDATA_UART/GPIO/TIMER`, `PSLVERR_UART/GPIO/TIMER`) directly to `apb3_bridge` (retaining TB-local mux only for `rv32i_golden_iss` and `tb_cov_collector`).
   - `sva/sva_binds.sv`: Updated `u_sva_apb3` bind on `apb3_bridge` to drive `.PREADY_mux`, `.PRDATA_mux`, and `.PSLVERR_mux` via pure port expressions over `PSEL_*` and `{PREADY,PRDATA,PSLVERR}_{UART,GPIO,TIMER}`, and removed nonexistent `.dram_wdata` from the `SVA_ENABLE_INTERNAL_BINDS` `sva_mem_if` bind.
   - `tb/rv32i_golden_iss.sv`: Refined PC check to validate `dut_pc[14:0] == gold_pc[14:0]` while `is_in_irom(gold_pc)` and check full 32-bit `dut_fault_pc` on halt (preventing false 15-bit truncation mismatch on `FAULT_IF_UNMAPPED` jumps outside `IROM`).
7. Verified integrated Verilator strict lint (`--lint-only --assert --timing`) AND C++ compilation/elaboration (`verilator --binary --assert --timing`, no simulation run) for both `tb_core_bus` and `tb_soc_top` (including `-DSVA_ENABLE_INTERNAL_BINDS`), then removed temporary `obj_dir_core_bus` and `obj_dir_soc_top` directories.

## Files created/changed
- Created: [VERIFICATION_PLAN_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V2.md) (`SOC_VB_002` — `PROPOSED`)
- Created: [SVA_SPECIFICATION_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V2.md) (`PROPOSED`)
- Created: [COVERAGE_PLAN_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/COVERAGE_PLAN_V2.md) (`PROPOSED`)
- Created: [periph_regs.inc](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/include/periph_regs.inc), [crt0_periph.S](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/src/crt0_periph.S), [TEST_MANIFEST_V2.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TEST_MANIFEST_V2.md)
- Created: `VER_UART_001.S`, `VER_UART_002.S`, `VER_GPIO_001.S`, `VER_GPIO_002.S`, `VER_TIMER_001.S`, `VER_TIMER_002.S`, `VER_PERIPH_INT_001.c` under `verification/firmware/src/`
- Updated (appended `SOC_VB_002` targets only): [Makefile](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/Makefile)
- Created & Aligned (`VER-003`): [tb_pkg.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_pkg.sv), [mock_apb_completer.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/mock_apb_completer.sv), [rv32i_golden_iss.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/rv32i_golden_iss.sv), [tb_cov_collector.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_cov_collector.sv), [tb_core_bus.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_core_bus.sv), [tb_soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_soc_top.sv)
- Created & Aligned (`VER-003`): [sva_apb3_if.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_apb3_if.sv), [sva_mem_if.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_mem_if.sv), [sva_cpu_fault_rst.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_cpu_fault_rst.sv), [sva_periph_if.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_periph_if.sv), [sva_binds.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_binds.sv)
- Created & Updated: [REP-VER-002.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-VER-002.md)

## Commands and tool versions
- Tool version: `Verilator 5.032 2025-01-01 rev (Debian 5.032-1)`
- Standalone SVA & TB lint (`verilator --lint-only --assert`): all 10 standalone checks exited `0`.
- Integrated strict lint (`VER-003`, 0 warnings/0 errors):
  - `verilator --lint-only --assert --timing --top-module tb_core_bus -f rtl/rtl.f tb/tb_pkg.sv tb/mock_apb_completer.sv tb/rv32i_golden_iss.sv tb/tb_cov_collector.sv tb/tb_core_bus.sv sva/sva_apb3_if.sv sva/sva_mem_if.sv sva/sva_cpu_fault_rst.sv sva/sva_periph_if.sv sva/sva_binds.sv` -> exit `0` (`25 modules`)
  - `verilator --lint-only --assert --timing -DSVA_ENABLE_INTERNAL_BINDS --top-module tb_soc_top -f rtl/rtl.f tb/tb_pkg.sv tb/tb_soc_top.sv sva/sva_apb3_if.sv sva/sva_mem_if.sv sva/sva_cpu_fault_rst.sv sva/sva_periph_if.sv sva/sva_binds.sv` -> exit `0` (`22 modules`)
- Integrated C++ compilation & elaboration (`VER-003`, `--binary` build only, **NOT RUN**):
  - `verilator --binary --assert --timing -j 4 --Mdir obj_dir_core_bus --top-module tb_core_bus -f rtl/rtl.f tb/tb_pkg.sv tb/mock_apb_completer.sv tb/rv32i_golden_iss.sv tb/tb_cov_collector.sv tb/tb_core_bus.sv sva/sva_apb3_if.sv sva/sva_mem_if.sv sva/sva_cpu_fault_rst.sv sva/sva_periph_if.sv sva/sva_binds.sv` -> exit `0` (linked `Vtb_core_bus`)
  - `verilator --binary --assert --timing -DSVA_ENABLE_INTERNAL_BINDS -j 4 --Mdir obj_dir_soc_top --top-module tb_soc_top -f rtl/rtl.f tb/tb_pkg.sv tb/tb_soc_top.sv sva/sva_apb3_if.sv sva/sva_mem_if.sv sva/sva_cpu_fault_rst.sv sva/sva_periph_if.sv sva/sva_binds.sv` -> exit `0` (linked `Vtb_soc_top`)
  - Cleaned up `obj_dir_core_bus` and `obj_dir_soc_top`.
- Firmware compilation & Gate 5 simulation execution: `NOT_RUN` (RISC-V bare-metal GNU toolchain not installed; Gate 5 not yet authorized).

## Results and evidence paths
- `SOC_VB_002` plans: `docs/verification_plans/VERIFICATION_PLAN_V2.md`, `SVA_SPECIFICATION_V2.md`, `COVERAGE_PLAN_V2.md`
- Peripheral firmware & manifest: `verification/firmware/TEST_MANIFEST_V2.md`, `verification/firmware/src/`
- Gate 4 TB & SVA: `tb/`, `sva/`

## Assumptions / unresolved questions
1. **Gate 5 Prerequisite (RISC-V Toolchain):** Install `gcc-riscv64-unknown-elf` + `binutils-riscv64-unknown-elf` (or `riscv32-unknown-elf-gcc`) before Gate 5 so `make all-v2` can compile `.mem` images and record SHA-256 digests.
2. **Gate 5 Build-Time Image Selection Note:** `irom_local.sv` uses compile-time parameter `INIT_FILE` (`IROM_INIT_FILE` on `soc_top`). In Verilator `--binary`, pass `-GINIT_FILE=\"...\"` at elaboration/build time (or use runtime `$readmemh` helper if single-binary multi-test dispatch is desired in Gate 5). Also, `tb_core_bus.sv` currently ties `dut_rf_we` to `1'b0` on `rv32i_golden_iss` (port-only hook) and can optionally be connected to `u_cpu` writeback signals in Gate 5 without changing any expected results.
3. **Human Approval Required for `SOC_VB_002`:** Human review/approval is required to promote `SOC_VB_002` (`VERIFICATION_PLAN_V2.md`, `SVA_SPECIFICATION_V2.md`, `COVERAGE_PLAN_V2.md`, `TEST_MANIFEST_V2.md`, peripheral firmware) from `PROPOSED` to `APPROVED` alongside immutable `SOC_VB_001`.

## Recommended next action
1. **Human / Main Orchestrator:** Review and approve `SOC_VB_002` (`REP-VER-002`) and install the RISC-V bare-metal GNU toolchain (`gcc-riscv64-unknown-elf` + `binutils-riscv64-unknown-elf`).
2. **Gate 5 Simulation (upon human authorization):** Compile `SOC_VB_001` + `SOC_VB_002` firmware images (`make all-v2`), link `tb/` + `sva/` against `rtl/`, and execute full Gate 5 simulation regression.
