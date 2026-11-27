# Task Report & Verification Change Proposal

- Report ID: `REP-VER-003`
- Proposal ID: `VCP-VER-001` (Verification Change Proposal for `SOC_VB_001` / `Makefile`)
- Date/time: `2026-11-27T15:42:00+02:00`
- Agent/role: Independent Verification Engineer Agent
- Task: `VER-004` — `VER_CORE_003.S` Assembler Defect Diagnosis & Change Proposal
- Status: `REVIEW_REQUIRED` (`PENDING` human approval; neither `VER_CORE_003.S` nor `Makefile` has been edited)
- Relevant spec/interface revision: `SOC_VB_001` (`DEC-VER-BASELINE-001.md` — `APPROVED` / immutable), `SOC_VB_002` (`PROPOSED`), `CON-ADDR-001` v1.1, `CON-APB3-001` v1.1
- Git branch/commit: `dev/gate2-4-rtl-and-verif` (with uncommitted `VER-002`/`VER-003` work; no Git commands run)

---

## Work performed

1. Inspected [VER_CORE_003.S](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/src/VER_CORE_003.S) and [Makefile](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/Makefile).
2. Reproduced the assembler failure directly using the newly installed `riscv64-unknown-elf-gcc` (`14.2.0`) / GNU assembler (`2.45.50`).
3. Verified the root cause of both the `VER_CORE_003.S` assembly failure and the GNU Make intermediate `.elf` deletion affecting `.sha256` manifest integrity.
4. Prepared the formal Verification Change Proposal below without modifying any protected `SOC_VB_001` file or `Makefile`.

---

## Change Proposal (`VCP-VER-001`) — Human Approval Status: `PENDING`

### 1. Root Cause and Evidence

#### Issue A — `VER_CORE_003.S` Signed 12-Bit Offset Overflow (`VERIFICATION_DEFECT_CONFIRMED` — Infrastructure/ISA Encoding)
- **Failure observed:**
  - `verification/firmware/src/VER_CORE_003.S:33: Error: illegal operands 'sw t3,0xFFC(s0)'`
  - `verification/firmware/src/VER_CORE_003.S:34: Error: illegal operands 'lw t4,0xFFC(s0)'`
  - `verification/firmware/src/VER_CORE_003.S:47: Error: illegal operands 'sw t3,0xFFC(s2)'`
  - `verification/firmware/src/VER_CORE_003.S:48: Error: illegal operands 'lw t4,0xFFC(s2)'`
  - `verification/firmware/src/VER_CORE_003.S:61: Error: illegal operands 'sw t3,0xFFC(s3)'`
  - `verification/firmware/src/VER_CORE_003.S:62: Error: illegal operands 'lw t4,0xFFC(s3)'`
- **Root cause:** In the RV32I base ISA, `LW` (I-type) and `SW` (S-type) encode a **signed 12-bit** byte offset (`-2048` .. `+2047`, i.e., `-0x800` .. `+0x7FF`). The top-of-slot offset `0xFFC` (`+4092`) exceeds `+0x7FF` and cannot be encoded directly as an immediate offset in `sw`/`lw`.

#### Issue B — GNU Make Intermediate `.elf` Deletion (`BUILD_INFRASTRUCTURE_DEFECT`)
- **Failure observed:** `build/<test>.sha256` records SHA-256 digests for three artifacts (`<test>.elf`, `<test>.bin`, `<test>.mem`), generated in `$(BUILD_DIR)/%.mem: $(BUILD_DIR)/%.elf bin2mem.py` (lines 87–91 of `Makefile`).
- **Root cause:** For targets built via the implicit pattern rule `$(BUILD_DIR)/%.elf: src/%.S ...` (lines 47–48: `VER_CORE_001`, `VER_CORE_002`, `VER_CORE_003`, `VER_UART_001`, `VER_GPIO_001`, `VER_TIMER_001`), GNU Make treats the `.elf` file as an intermediate file and deletes it upon completion because `.PRECIOUS` (or `.SECONDARY`) is absent. Consequently, `sha256sum -c build/<test>.sha256` fails for those targets due to the missing `.elf`.

---

### 2. Proposed Files and Minimal Exact Patch

#### File 1: `verification/firmware/src/VER_CORE_003.S` (`SOC_VB_001` protected asset)
Compute each `+0xFFC` effective address into scratch register `t5` (confirmed unused throughout `VER_CORE_003.S`) using `li t5, 0xFFC` + `add t5, <base>, t5`, then issue `sw t3, 0(t5)` / `lw t4, 0(t5)`:

```diff
--- a/verification/firmware/src/VER_CORE_003.S
+++ b/verification/firmware/src/VER_CORE_003.S
@@ -30,8 +30,10 @@
     bne     t2, t1, fail
 
     li      t3, 0xA5A55A5A
-    sw      t3, 0xFFC(s0)
-    lw      t4, 0xFFC(s0)
+    li      t5, 0xFFC
+    add     t5, s0, t5
+    sw      t3, 0(t5)
+    lw      t4, 0(t5)
     bne     t4, t3, fail
     ori     s1, s1, 0x1
 
@@ -44,8 +46,10 @@
     bne     t2, t1, fail
 
     li      t3, 0x0F0F0F0F
-    sw      t3, 0xFFC(s2)
-    lw      t4, 0xFFC(s2)
+    li      t5, 0xFFC
+    add     t5, s2, t5
+    sw      t3, 0(t5)
+    lw      t4, 0(t5)
     bne     t4, t3, fail
     ori     s1, s1, 0x2
 
@@ -58,8 +62,10 @@
     bne     t2, t1, fail
 
     li      t3, 0x55AA33CC
-    sw      t3, 0xFFC(s3)
-    lw      t4, 0xFFC(s3)
+    li      t5, 0xFFC
+    add     t5, s3, t5
+    sw      t3, 0(t5)
+    lw      t4, 0(t5)
     bne     t4, t3, fail
     ori     s1, s1, 0x4
```

#### File 2: `verification/firmware/Makefile`
Add `.PRECIOUS: $(BUILD_DIR)/%.elf $(BUILD_DIR)/%.bin` so GNU Make preserves all `.elf` and `.bin` artifacts referenced in `build/*.sha256`:

```diff
--- a/verification/firmware/Makefile
+++ b/verification/firmware/Makefile
@@ -15,6 +15,7 @@
 
 BUILD_DIR := build
+.PRECIOUS: $(BUILD_DIR)/%.elf $(BUILD_DIR)/%.bin
 
 CORE_ASM_TESTS := VER_CORE_001 VER_CORE_002 VER_CORE_003
```

---

### 3. Proposed Behavior Change & Side Effects
- **Expected behavior / test intent:** **Zero change** to test intent, target APB3 bus addresses (`0x4000_0FFC`, `0x4000_1FFC`, `0x4000_2FFC`), `MBOX_TESTID_ADDR` (`0x0000_0003`), `MBOX_DETAIL_ADDR` (`0x0000_001F`), `MBOX_STATUS_ADDR` (`0xCAFE_0001`), or completion fault (`FAULT_EBREAK` `4'h5`).
- **Side effects:**
  - `VER_CORE_003.S` executes 3 additional non-memory RV32I instructions (`lui`, `addi`, `add`) per `+0xFFC` access (`0x4000_0FFC`, `0x4000_1FFC`, `0x4000_2FFC`), shifting the link-time address of `ver_core_003_pass_ebreak` / `ver_core_003_fail_ebreak` (which `TEST_MANIFEST.md` references symbolically as `sym(ver_core_003_pass_ebreak)`).
  - Retaining `.elf` files under `verification/firmware/build/` increases `build/` size slightly (~few KB per ELF) while ensuring `sha256sum -c build/*.sha256` passes cleanly.
- **Baseline governance note:** Since `VER_CORE_003.S` is part of frozen `SOC_VB_001` (`DEC-VER-BASELINE-001.md`), human approval is required to authorize the patch (either as an approved erratum `SOC_VB_001.1` / `DEC-VER-BASELINE-002` or folded into `SOC_VB_002`).

---

## Files created/changed
- Created: [REP-VER-003.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-VER-003.md)
- Untouched (awaiting human approval): `verification/firmware/src/VER_CORE_003.S`, `verification/firmware/Makefile`

## Commands and tool versions
- `riscv64-unknown-elf-gcc --version | head -n 2`: `riscv64-unknown-elf-gcc (14.2.0+19) 14.2.0`
- `riscv64-unknown-elf-as --version | head -n 1`: `GNU assembler (2.45.50.20251209-1ubuntu1+7build1) 2.45.50.20251209`
- `riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -nostartfiles -fno-builtin -mcmodel=medlow -x assembler-with-cpp -Iverification/firmware/include -c verification/firmware/src/VER_CORE_003.S -o /dev/null`: reproduced all 6 `Error: illegal operands` lines at `33, 34, 47, 48, 61, 62`.

## Results and evidence paths
- Change proposal report: `reports/REP-VER-003.md`
- Affected files (pending approval): `verification/firmware/src/VER_CORE_003.S`, `verification/firmware/Makefile`

## Assumptions / unresolved questions
1. Should the approved patch update `SOC_VB_001` via a recorded erratum (`DEC-VER-BASELINE-002`, e.g., `SOC_VB_001.1`) or be recorded under `SOC_VB_002`?

## Recommended next action
1. **Human / Main Orchestrator:** Review and approve `VCP-VER-001` in `reports/REP-VER-003.md`.
2. **Verification Engineer (upon explicit approval):** Apply the two patches to `VER_CORE_003.S` and `Makefile`, run `make -C verification/firmware clean all-v2`, verify 60/60 `.mem` images and `sha256sum -c build/*.sha256` pass, and proceed with Gate 5 simulation when authorized.
