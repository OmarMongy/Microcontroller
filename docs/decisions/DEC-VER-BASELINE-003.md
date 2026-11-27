# Human Engineering Decision — Verification Change Proposal `VCP-VER-001` (`VER_CORE_003.S` & `Makefile`)

- Decision ID: `DEC-VER-BASELINE-003`
- Date: 2026-11-27
- Topic: Approval of `VCP-VER-001` (`SOC_VB_001` erratum for `VER_CORE_003.S` signed 12-bit offset & `Makefile` `.PRECIOUS` `.elf`/`.bin` retention) and Gate 5 simulation authorization
- Related report/proposal: [REP-VER-003.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-VER-003.md), [REP-GATE5-READINESS.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-GATE5-READINESS.md)
- Status: `APPROVED`

## Options considered

1. **Approve `VCP-VER-001`:** Compute `base + 0xFFC` via unused scratch register `t5` in `verification/firmware/src/VER_CORE_003.S` (preserving exact target APB3 addresses `0x4000_0FFC`, `0x4000_1FFC`, `0x4000_2FFC` and expected outcomes) and add `.PRECIOUS: $(BUILD_DIR)/%.elf $(BUILD_DIR)/%.bin` to `verification/firmware/Makefile`, recording this as erratum `SOC_VB_001.1` alongside frozen `SOC_VB_002`.
2. Leave `VER_CORE_003.S` unbuildable.

## Decision

1. **`VCP-VER-001` is `APPROVED` (`SOC_VB_001.1` erratum).**
2. **Gate 5 simulation regression is `AUTHORIZED`** across `SOC_VB_001` (`SOC_VB_001.1`) and `SOC_VB_002`.

## Rationale

- RISC-V `SW`/`LW` immediate offsets are signed 12-bit (`-2048..+2047`), so `0xFFC(base)` is illegal RV32I assembly syntax; loading `0xFFC` via `t5` tests the exact intended top-of-slot addresses without altering test intent or expected outcomes.
- Adding `.PRECIOUS` ensures all `.elf` and `.bin` files referenced by `build/*.sha256` remain intact for `sha256sum -c` verification.

## Scope / files affected

- [VER_CORE_003.S](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/src/VER_CORE_003.S)
- [Makefile](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/Makefile)

## Follow-up actions

1. Verification Engineer applies `VCP-VER-001` (`VER_CORE_003.S` and `Makefile`), runs `make -C verification/firmware clean all-v2`, and verifies `60/60` `.mem` images and `sha256sum -c build/*.sha256`.
2. Verification Engineer executes Gate 5 simulation regression (`TB-CORE-BUS` and `TB-SOC-TOP`) with SVA (`--assert`), Golden ISS scoreboard, and coverage collection, filing `regression/runs/RUN-GATE5-001.md` (and any `regression/investigations/` failure reports if failures occur).
