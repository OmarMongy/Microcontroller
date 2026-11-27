# Human Engineering Decision — Core Verification Baseline `SOC_VB_001`

- Decision ID: `DEC-VER-BASELINE-001`
- Date: 2026-11-27
- Topic: Approval and freeze of Core Verification Baseline `SOC_VB_001`
- Related report/proposal: [VERIFICATION_PLAN_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V1.md), [REP-VER-001.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-VER-001.md)
- Status: `APPROVED`

## Options considered

1. Freeze `VERIFICATION_PLAN_V1.md`, `SVA_SPECIFICATION_V1.md`, `COVERAGE_PLAN_V1.md`, and the core `verification/firmware/` suite + `DRAM` signature mailbox (`0x2000_7F00`–`0x2000_7FFF`) as immutable verification baseline **`SOC_VB_001`** (with peripheral register-level items deferred to `SOC_VB_002`).
2. Hold baseline freeze until peripheral register-map tests are merged into one combined baseline.

## Decision

**Baseline `SOC_VB_001` is `APPROVED` and `FROZEN`:**
- [VERIFICATION_PLAN_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V1.md) (`VER-PLAN-001` V1.0)
- [SVA_SPECIFICATION_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V1.md) (`SVA-SPEC-001` V1.0)
- [COVERAGE_PLAN_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/COVERAGE_PLAN_V1.md) (`COV-PLAN-001` V1.0)
- Core verification firmware & build specification under `verification/firmware/` ([TEST_MANIFEST.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TEST_MANIFEST.md), [TOOLCHAIN_AND_BUILD.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TOOLCHAIN_AND_BUILD.md), `link.ld`, `bin2mem.py`, `Makefile`, `include/verif_mailbox.inc`, `src/VER_CORE_001.S`–`004.c`, `src/crt0.S`, `src/VER_FAULT_001.S`–`011.S`) and `DRAM` signature mailbox convention (`0x2000_7F00`–`0x2000_7FFF`).

## Rationale

- Freezing `SOC_VB_001` establishes an immutable, RTL-independent verification baseline derived strictly from frozen core contracts (`CON-ADDR-001`, `CON-MEM-001`, `CON-APB3-001`, `CON-FLT-RST-001`, `CON-TOP-001`).
- Now that `CON-PERIPH-001` is also approved (`DEC-ARCH-PERIPH-001`), peripheral register-level verification will be added cleanly as successor baseline **`SOC_VB_002`** without mutating `SOC_VB_001`.

## Scope / files affected

- [VERIFICATION_PLAN_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V1.md)
- [SVA_SPECIFICATION_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V1.md)
- [COVERAGE_PLAN_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/COVERAGE_PLAN_V1.md)
- [TEST_MANIFEST.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TEST_MANIFEST.md)
- [TOOLCHAIN_AND_BUILD.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TOOLCHAIN_AND_BUILD.md)

## Follow-up actions

1. Treat `SOC_VB_001` and all `verification/firmware/` assets as protected verification assets (RTL Designer must not modify them).
2. Upon human authorization, Verification Engineer extends `SOC_VB_001` into `SOC_VB_002` against `CON-PERIPH-001` and builds the SV testbench/harnesses; install a RISC-V bare-metal GNU toolchain (`gcc-riscv64-unknown-elf` + `binutils-riscv64-unknown-elf`) prior to Gate 4/5 firmware compilation.
