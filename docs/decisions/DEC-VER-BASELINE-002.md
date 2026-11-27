# Human Engineering Decision — Verification Baseline `SOC_VB_002`

- Decision ID: `DEC-VER-BASELINE-002`
- Date: 2026-11-27
- Topic: Approval and freeze of Verification Baseline `SOC_VB_002` (extending `SOC_VB_001` with peripheral verification)
- Related report/proposal: [VERIFICATION_PLAN_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V2.md), [REP-VER-002.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-VER-002.md)
- Status: `APPROVED`

## Options considered

1. Freeze `VERIFICATION_PLAN_V2.md`, `SVA_SPECIFICATION_V2.md`, `COVERAGE_PLAN_V2.md`, `TEST_MANIFEST_V2.md`, and the peripheral verification firmware (`VER_UART_001/002`, `VER_GPIO_001/002`, `VER_TIMER_001/002`, `VER_PERIPH_INT_001`) as baseline **`SOC_VB_002`** while keeping `SOC_VB_001` immutable.
2. Defer `SOC_VB_002` freeze further.

## Decision

**Baseline `SOC_VB_002` is `APPROVED` and `FROZEN`:**
- [VERIFICATION_PLAN_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V2.md) (`VER-PLAN-002` V2.0)
- [SVA_SPECIFICATION_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V2.md) (`SVA-SPEC-002` V2.0)
- [COVERAGE_PLAN_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/COVERAGE_PLAN_V2.md) (`COV-PLAN-002` V2.0)
- [TEST_MANIFEST_V2.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TEST_MANIFEST_V2.md) (`VER-MANIFEST-002`)
- Peripheral verification firmware under `verification/firmware/` (`include/periph_regs.inc`, `src/crt0_periph.S`, `src/VER_UART_001.S`, `src/VER_UART_002.S`, `src/VER_GPIO_001.S`, `src/VER_GPIO_002.S`, `src/VER_TIMER_001.S`, `src/VER_TIMER_002.S`, `src/VER_PERIPH_INT_001.c`).

Core baseline **`SOC_VB_001`** (`*_V1.md`, `TEST_MANIFEST.md`, `TOOLCHAIN_AND_BUILD.md`, `VER_CORE_001..004`, `VER_FAULT_001..011`) remains preserved and immutable per `DEC-VER-BASELINE-001`.

## Rationale

- `SOC_VB_002` derives all peripheral register assertions, functional coverage, testbenches, and verification firmware strictly from frozen contract `CON-PERIPH-001` v1.0 (`DEC-ARCH-PERIPH-001`) and passes integrated Verilator lint/elaboration (`REP-VER-002`).

## Scope / files affected

- [VERIFICATION_PLAN_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V2.md)
- [SVA_SPECIFICATION_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V2.md)
- [COVERAGE_PLAN_V2.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/COVERAGE_PLAN_V2.md)
- [TEST_MANIFEST_V2.md](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/TEST_MANIFEST_V2.md)

## Follow-up actions

1. Build and SHA-256-hash all `SOC_VB_001` and `SOC_VB_002` firmware `.elf`/`.mem` images using the installed RV32I GNU toolchain.
2. Execute Gate 5 simulation regression against `SOC_VB_001` + `SOC_VB_002` upon explicit human authorization.
