# Task Report

- Report ID: `REP-VER-004`
- Date/time: `2026-11-27T18:05:00+02:00`
- Agent/role: Independent Verification Engineer Agent
- Task: `VER-005` — Apply Approved `VCP-VER-001` & Execute Gate 5 Simulation Regression
- Status: `FAIL` (Firmware build `PASS` **60/60** + `sha256sum -c` `PASS` **180/180**; Gate 5 simulation **67/68 PASS, 1 FAIL: `VER-GPIO-001`**, `0` SVA property errors; `VER-GPIO-001` diagnosed as TB GPIO BFM stimulus defect in `tb/tb_soc_top.sv` per `INV-GATE5-001.md` — fix proposed below awaiting human approval)
- Relevant spec/interface revision: `SOC_SPECIFICATION_DRAFT.md` (Draft 0.3); `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1 (`IHI0024E` Issue B), `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1, `CON-PERIPH-001` v1.0; `DEC-VER-BASELINE-003` (`SOC_VB_001.1`), `SOC_VB_002` (`PROPOSED`)
- Git branch/commit: `dev/gate2-4-rtl-and-verif` (branched from `main` checkpoint `85dcd83`, with uncommitted `VER-002`–`VER-005` verification changes; zero `rtl/` edits)

## Work performed
1. Applied approved `VCP-VER-001` (`DEC-VER-BASELINE-003.md`):
   - Updated [VER_CORE_003.S](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/src/VER_CORE_003.S) to compute `base + 0xFFC` into scratch register `t5` (`0x4000_0FFC`, `0x4000_1FFC`, `0x4000_2FFC`).
   - Added `.PRECIOUS: $(BUILD_DIR)/%.elf $(BUILD_DIR)/%.bin` to [Makefile](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/Makefile).
2. Rebuilt all firmware images via `make -C verification/firmware clean all-v2` (**60 / 60** `.mem` images built cleanly, exit `0`) and verified `(cd verification/firmware && sha256sum -c build/*.sha256)` (**180 / 180** files `OK`, exit `0`).
3. Hardened [tb_core_bus.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_core_bus.sv) and [tb_soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_soc_top.sv) to call `$fatal(1, ...)` on failure, support `+MEM_FILE=` runtime loading while `rst_n == 0`, instantiate `rv32i_golden_iss` and `tb_cov_collector` on `tb_soc_top` as well, and verify exact `EXP_PC_HEX` / `EXP_ADDR_HEX` / `EXP_INSN_HEX` / `EXP_STATUS_HEX`.
4. Authored reproducible Gate 5 runner [run_gate5.py](file:///mnt/e/PB/Projects/Microcontroller/tb/run_gate5.py) and executed all **68** simulation runs using `Verilator 5.032 --binary --assert --timing --public-flat-rw` (with `-DSVA_ENABLE_INTERNAL_BINDS` on `tb_soc_top`).
5. Recorded `RUN-GATE5-001` in [RUN-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-001.md), [RUN-GATE5-001.log](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-001.log), and [regression_history.csv](file:///mnt/e/PB/Projects/Microcontroller/regression/regression_history.csv).
6. Investigated the sole failure (`VER-GPIO-001`) following the required `AGENTS.md` failure workflow (without silently patching `tb_soc_top.sv`) and filed [INV-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/investigations/INV-GATE5-001.md).

## Files created/changed
- Updated (`VCP-VER-001` approved): [VER_CORE_003.S](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/src/VER_CORE_003.S), [Makefile](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/Makefile)
- Updated (Gate 5 testbench hardening): [tb_core_bus.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_core_bus.sv), [tb_soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_soc_top.sv)
- Created: [run_gate5.py](file:///mnt/e/PB/Projects/Microcontroller/tb/run_gate5.py)
- Created: [RUN-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-001.md), [RUN-GATE5-001.log](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-001.log), [INV-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/investigations/INV-GATE5-001.md), [REP-VER-004.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-VER-004.md)
- Appended: [regression_history.csv](file:///mnt/e/PB/Projects/Microcontroller/regression/regression_history.csv)

## Commands and tool versions
- `riscv64-unknown-elf-gcc (14.2.0+19) 14.2.0` / `GNU assembler 2.45.50`:
  - `make -C verification/firmware clean all-v2` -> exit `0` (`60` `.mem` files)
  - `(cd verification/firmware && sha256sum -c build/*.sha256)` -> exit `0` (`180/180 OK`)
- `Verilator 5.032 2025-01-01 rev (Debian 5.032-1)`:
  - `python3 tb/run_gate5.py` -> exit `1` (`PASSED=67, FAILED=1 [VER-GPIO-001], SVA_property_errors=0, TOTAL=68`; temporary `obj_dir_gate5_*` cleaned)

## Results and evidence paths
- Run report: `regression/runs/RUN-GATE5-001.md`
- Run log: `regression/runs/RUN-GATE5-001.log`
- Regression tracker CSV: `regression/regression_history.csv`
- Failure investigation: `regression/investigations/INV-GATE5-001.md`

## Proposed Fix Pending Human Approval (`tb/tb_soc_top.sv`)
To resolve `INV-GATE5-001` (`VERIFICATION_DEFECT_SUSPECTED` — confirmed TB GPIO BFM defect), authorize the following 1-line fix in `tb/tb_soc_top.sv` line 117 so `ECHO_INV` only drives `{~gpio_o[3:0], gpio_o[3:0]}` once `gpio_oe_o == 8'h0F` (keeping `gpio_i = 8'h00` when `gpio_oe_o == 8'h00` in Step 1):
```diff
--- a/tb/tb_soc_top.sv
+++ b/tb/tb_soc_top.sv
@@ -114,7 +114,7 @@
   always_comb begin
     if (!rst_n) begin
       gpio_i = 8'h00;
-    end else if (gpio_mode == 1) begin
+    end else if (gpio_mode == 1 && gpio_oe_o == 8'h0F) begin
       gpio_i = {~gpio_o[3:0], gpio_o[3:0]};
     end else begin
       gpio_i = 8'h00;
```
*(Also note: in `tb/run_gate5.py`, separate Verilator `$fatal` counting from SVA `sva_*` property error counting, and optionally print aggregated `tb_cov_collector` coverage totals at the end of `run_gate5.py` so `RUN-GATE5-002` produces a single aggregated coverage summary.)*

## Assumptions / unresolved questions
1. **Human Approval Needed:** Approve the `tb/tb_soc_top.sv` GPIO BFM fix in `INV-GATE5-001.md` (and `SOC_VB_002` baseline freeze if not yet finalized) and authorize Gate 5 rerun `RUN-GATE5-002`.

## Recommended next action
1. **Human / Main Orchestrator:** Review [INV-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/investigations/INV-GATE5-001.md) and approve patching `tb/tb_soc_top.sv` (`gpio_mode == 1 && gpio_oe_o == 8'h0F`) for `RUN-GATE5-002`.
