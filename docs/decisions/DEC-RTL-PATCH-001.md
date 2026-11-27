# Human Engineering Decision — RTL Change Proposal `RCP-RTL-001` (`irom_local.sv`)

- Decision ID: `DEC-RTL-PATCH-001`
- Date: 2026-11-27
- Topic: Approval of `RCP-RTL-001` (`rtl/irom_local.sv` `` `ifndef SYNTHESIS `` scope fix for Yosys ROM initialization)
- Related report/proposal: [REP-RTL-002.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-RTL-002.md)
- Status: `APPROVED`

## Options considered

1. **Approve `RCP-RTL-001`:** Move `` `ifndef SYNTHESIS `` inside the single `initial` block in `rtl/irom_local.sv` so only the `8192`-word `for`-loop zeroing is simulation-only, while `if (INIT_FILE != "") $readmemh(INIT_FILE, mem);` runs for both simulation and Yosys synthesis.
2. **Reject `RCP-RTL-001`:** Keep `$readmemh` inside `` `ifndef SYNTHESIS ``, causing Yosys to fold `irom_local` to `0` cells even when `IROM_INIT_FILE` is set.

## Decision

**`RCP-RTL-001` is `APPROVED`.**

## Rationale

- Empirical Yosys `0.52` investigation (`REP-RTL-002`) proved that Yosys defines `SYNTHESIS` during `read_verilog -sv` and assigns `for`-loop `$meminit` writes higher priority than `$readmemh`. Keeping only the `for` loop under `` `ifndef SYNTHESIS `` inside the single `initial` block preserves race-free zero-defaulting of unprogrammed words in simulation while enabling Yosys synthesis to infer and retain non-empty ROM contents (`$mem_v2` pre-map / ROM logic post-map).

## Scope / files affected

- [irom_local.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/irom_local.sv) (lines 34–43)

## Follow-up actions

1. RTL Designer applies `RCP-RTL-001` to `rtl/irom_local.sv`.
2. RTL Designer re-runs Verilator `--lint-only -Wall` and Yosys generic synthesis (`IROM_INIT_FILE=""` and sample non-empty `.mem` check) and records results in `reports/REP-RTL-003.md`.
