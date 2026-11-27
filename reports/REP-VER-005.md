# Task Report

- Report ID: `REP-VER-005`
- Date/time: `2026-11-27T18:10:00+02:00`
- Agent/role: Independent Verification Engineer Agent
- Task: `VER-006` — Apply Approved `INV-GATE5-001` TB Fix (`DEC-VER-PATCH-001`) & Execute Rerun `RUN-GATE5-002`
- Status: `PASS` (**68 / 68 passed**, **0 failed**, **0 SVA errors**, **0 Golden ISS mismatches**)
- Relevant spec/interface revision: `SOC_SPECIFICATION_DRAFT.md` (Draft 0.3); `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1 (`IHI0024E` Issue B), `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1, `CON-PERIPH-001` v1.0; `DEC-VER-BASELINE-002` (`SOC_VB_002` `APPROVED`), `DEC-VER-BASELINE-003` (`SOC_VB_001.1` `APPROVED`), `DEC-VER-PATCH-001` (`APPROVED`)
- Git branch/commit: `dev/gate2-4-rtl-and-verif` (branched from `main` checkpoint `85dcd83`; zero `rtl/` edits; `RUN-GATE5-001` records preserved intact)

## Work performed
1. Read [DEC-VER-PATCH-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-PATCH-001.md) and [DEC-VER-BASELINE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-002.md).
2. Applied the approved 1-line GPIO BFM fix in [tb_soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_soc_top.sv) (`else if (gpio_mode == 1 && gpio_oe_o == 8'h0F) begin`) while leaving `rtl/`, frozen contracts, and `VER_GPIO_001.S` / `SOC_VB_001.1` untouched.
3. Updated [tb_cov_collector.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_cov_collector.sv) (added `PERIPH_REGS` print line) and [run_gate5.py](file:///mnt/e/PB/Projects/Microcontroller/tb/run_gate5.py) to separate SVA `sva_*` assertion errors from testbench `$fatal` checks and aggregate `tb_cov_collector` coverage counters across all 68 runs.
4. Recorded human decision (`DEC-VER-PATCH-001.md`) at the bottom of [INV-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/investigations/INV-GATE5-001.md) while preserving `RUN-GATE5-001.md` and `RUN-GATE5-001.log` intact.
5. Executed full regression rerun `RUN-GATE5-002` (`python3 tb/run_gate5.py --log regression/runs/RUN-GATE5-002.log`), achieving **68 / 68 PASS, 0 FAIL, 0 SVA ERRORS, 0 ISS MISMATCHES**, and verified temporary `obj_dir_*` directories were cleaned up.
6. Recorded [RUN-GATE5-002.md](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-002.md), appended `RUN-GATE5-002` to [regression_history.csv](file:///mnt/e/PB/Projects/Microcontroller/regression/regression_history.csv), and wrote [REP-VER-005.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-VER-005.md).

## Files created/changed
- Updated (`DEC-VER-PATCH-001`): [tb_soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_soc_top.sv), [tb_cov_collector.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_cov_collector.sv), [run_gate5.py](file:///mnt/e/PB/Projects/Microcontroller/tb/run_gate5.py)
- Updated (`Human decision` field only): [INV-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/investigations/INV-GATE5-001.md)
- Created: [RUN-GATE5-002.md](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-002.md), [RUN-GATE5-002.log](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-002.log), [REP-VER-005.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-VER-005.md)
- Appended: [regression_history.csv](file:///mnt/e/PB/Projects/Microcontroller/regression/regression_history.csv)

## Commands and tool versions
- `Verilator 5.032 2025-01-01 rev (Debian 5.032-1)` (`--binary --assert --timing --public-flat-rw`, `-DSVA_ENABLE_INTERNAL_BINDS` on `tb_soc_top`)
- `python3 tb/run_gate5.py --log regression/runs/RUN-GATE5-002.log`: exit code `0` (`PASSED=68, FAILED=0, SVA_ERRORS=0, TOTAL=68`)

## Results and evidence paths
- Run report: `regression/runs/RUN-GATE5-002.md`
- Run log: `regression/runs/RUN-GATE5-002.log`
- History tracker: `regression/regression_history.csv` (both `RUN-GATE5-001` and `RUN-GATE5-002` preserved)
- Prior investigation closed: `regression/investigations/INV-GATE5-001.md`

## Assumptions / unresolved questions
- None for verification execution (`68/68` passing across `SOC_VB_001.1` + `SOC_VB_002`).

## Recommended next action
1. **Main Orchestrator / Human:** Proceed to Gate 9 Final Review & Merge Readiness sign-off (`SOC_VB_001.1` + `SOC_VB_002` verification regression complete at `68/68 PASS`, `0` SVA errors).
