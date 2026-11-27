# Human Engineering Decision — Verification TB Fix `INV-GATE5-001` (`tb/tb_soc_top.sv`)

- Decision ID: `DEC-VER-PATCH-001`
- Date: 2026-11-27
- Topic: Approval of `tb/tb_soc_top.sv` GPIO BFM fix (`INV-GATE5-001`), `tb/run_gate5.py` reporting cleanup, and Gate 8 regression rerun `RUN-GATE5-002`
- Related report/proposal: [INV-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/investigations/INV-GATE5-001.md), [RUN-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-001.md), [REP-VER-004.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-VER-004.md)
- Status: `APPROVED`

## Options considered

1. **Approve `INV-GATE5-001` Fix:** Gate `ECHO_INV` (`gpio_mode == 1`) in `tb/tb_soc_top.sv` on `gpio_oe_o == 8'h0F` so `gpio_i` stays `8'h00` while `GPIO_DIR == 0x00` (reset / Step 1 of `VER_GPIO_001.S`), and update `tb/run_gate5.py` to separate Verilator `$fatal` counting from SVA `sva_*` property errors and aggregate `tb_cov_collector` coverage counters.
2. Modify `VER_GPIO_001.S` expected initial input check.

## Decision

1. **Approved 1-line GPIO BFM fix in `tb/tb_soc_top.sv` (`gpio_mode == 1 && gpio_oe_o == 8'h0F`)** and `tb/run_gate5.py` reporting/coverage aggregation cleanup.
2. **Authorized Gate 8 Regression Rerun (`RUN-GATE5-002`)** across all 68 tests while preserving `RUN-GATE5-001.md`, `RUN-GATE5-001.log`, and `INV-GATE5-001.md` intact.

## Rationale

- `gpio_apb` RTL behaved strictly per `CON-PERIPH-001` §3.3; driving `8'hF0` before `gpio_oe_o == 8'h0F` was a testbench stimulus defect in `tb/tb_soc_top.sv`.

## Scope / files affected

- [tb_soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_soc_top.sv)
- [run_gate5.py](file:///mnt/e/PB/Projects/Microcontroller/tb/run_gate5.py)

## Follow-up actions

1. Verification Engineer applies the approved fix and executes `RUN-GATE5-002` against `SOC_VB_001.1` + `SOC_VB_002`.
2. Present `RUN-GATE5-002` results and Gate 9 final review / merge readiness to the human.
