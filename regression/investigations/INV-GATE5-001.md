# Failure Investigation Report

- Report ID: `INV-GATE5-001`
- Date/time: `2026-11-27T18:04:00+02:00`
- Author/agent: Independent Verification Engineer Agent
- Run ID: `RUN-GATE5-001`
- Verification baseline: `SOC_VB_001.1` (`DEC-VER-BASELINE-003`) & `SOC_VB_002` (`PROPOSED`)
- Specification revision: `SOC_SPECIFICATION_DRAFT.md` (Draft 0.3)
- Interface-contract revision: `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1, `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1, `CON-PERIPH-001` v1.0
- RTL commit/branch: `dev/gate2-4-rtl-and-verif` (branched from `main` checkpoint `85dcd83`, with approved Gate 2/3/4 files)
- Status: `FAIL` (`REVIEW_REQUIRED` — testbench GPIO BFM fix proposed, awaiting human approval before rerun)

## Failure summary
In `RUN-GATE5-001`, 67 of 68 Gate 5 tests passed with 0 SVA property errors and 0 Golden ISS mismatches. One test, `VER-GPIO-001`, failed in Step 1 (`MBOX_STATUS = 0xDEAD_0001`, branching to `ver_gpio_001_fail_ebreak` at `0x0000_0160` instead of `ver_gpio_001_pass_ebreak` at `0x0000_0124`).

Root-cause diagnosis confirms a **testbench BFM stimulus mismatch** in `tb/tb_soc_top.sv` (NOT an RTL defect): when `+GPIO_MODE=1` (`ECHO_INV`) is enabled, `tb_soc_top.sv` drives `gpio_i = {~gpio_o[3:0], gpio_o[3:0]} = 8'hF0` immediately after `rst_n` releases while `gpio_oe_o == 8'h00`, whereas `VER_GPIO_001.S` Step 1 reads `GPIO_DATA_IN` expecting `8'h00` before `GPIO_DIR` is enabled.

## Failing test(s) and assertion(s)
- **Failing Test ID:** `VER-GPIO-001` (`verification/firmware/src/VER_GPIO_001.S` on `tb_soc_top`)
- **Fatal Message:**
  `[690] %Fatal: tb_soc_top.sv:284: Assertion failed in tb_soc_top: [TB_SOC_TOP] FAIL: Expected fault_pc_o=00000124 got=00000160`
- **Diagnostic Re-run Without `+EXP_PC_HEX`:**
  `[690] %Fatal: tb_soc_top.sv:296: Assertion failed in tb_soc_top: [TB_SOC_TOP] FAIL: MBOX_STATUS=dead0001 (expected=cafe0001), detail=00000000`
- **SVA Protocol Assertions:** `0` SVA property failures (`sva_soc_fault_rst_if`, `sva_apb3_if`, `sva_mem_if`, `sva_gpio_apb_if`, etc. all passed).

## Expected behavior
Per `VER_GPIO_001.S` lines 18–34 (Step 1) and `CON-PERIPH-001` §3:
1. After reset release, `GPIO_DIR == 0x00` (`gpio_oe_o == 8'h00`) and `GPIO_DATA_OUT == 0x00` (`gpio_o == 8'h00`).
2. Step 1 reads `GPIO_DATA_IN` expecting external `gpio_i` to be `8'h00` initially (`lw t1, 0x000(s0); bnez t1, fail`).
3. Only in Step 4 (after `GPIO_DIR = 0x0F`, i.e., `gpio_oe_o == 8'h0F`) does `VER_GPIO_001.S` expect the BFM to echo `gpio_i = {~gpio_o[3:0], gpio_o[3:0]}`.

## Actual behavior
In `tb/tb_soc_top.sv` lines 113–122:
```systemverilog
  always_comb begin
    if (!rst_n) begin
      gpio_i = 8'h00;
    end else if (gpio_mode == 1) begin
      gpio_i = {~gpio_o[3:0], gpio_o[3:0]};
    end else begin
      gpio_i = 8'h00;
    end
  end
```
As soon as `rst_n` deasserted to `1'b1` (with `gpio_o == 8'h00` and `gpio_oe_o == 8'h00`), `tb_soc_top` drove `gpio_i = 8'hF0`. After 2 `PCLK` synchronizer stages (`CON-PERIPH-001` §3.3), `gpio_apb` accurately sampled `0xF0` into `GPIO_DATA_IN`. Consequently, `VER_GPIO_001.S` Step 1 (`t0 = 1`, `PC = 0x0000_0020`) read `0xF0 != 0` and branched to `fail` (`MBOX_STATUS = 0xDEAD_0001`, `ver_gpio_001_fail_ebreak = 0x0000_0160`) at `t = 690 ns`.

## Reproduction
- Tool/version: `Verilator 5.032 2025-01-01 rev (Debian 5.032-1)`
- Command:
  `python3 tb/run_gate5.py` (or `Vtb_soc_top +MEM_FILE=verification/firmware/build/VER_GPIO_001.mem +GPIO_MODE=1 +EXP_FAULT=5 +EXP_PC_HEX=00000124 +EXP_STATUS_HEX=CAFE0001`)
- Seed: Deterministic directed test (no random seed)
- First failure timestamp/transaction: `t = 690 ns` (`VER_GPIO_001.S` Step 1, `PC = 0x0000_001C` read `GPIO_DATA_IN` returned `0xF0`)

## Evidence
- Log: [RUN-GATE5-001.log](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-001.log)
- Disassembly: [VER_GPIO_001.dis](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/build/VER_GPIO_001.dis)
- Source: [VER_GPIO_001.S](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/src/VER_GPIO_001.S), [tb_soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_soc_top.sv)

## Classification
`VERIFICATION_DEFECT_SUSPECTED` (**Confirmed testbench GPIO BFM stimulus defect in `tb/tb_soc_top.sv`; zero RTL defect**)

Evidence:
- `gpio_apb` RTL behaved strictly per `CON-PERIPH-001` §3.3 (reset `gpio_o=0`, `gpio_oe_o=0`, 2-FF `gpio_i` sync returning `0xF0` when `tb_soc_top` drove `gpio_i = 8'hF0`).
- `VER-PERIPH-INT-001` (which skips Step 1 initial-zero check and immediately writes `GPIO_DIR = 0x0F`) passed with `+GPIO_MODE=1`.
- `VER_GPIO_001.S` Step 1 explicitly documents `/* GPIO_DATA_IN (TB drives 0 initially) */` while `GPIO_DIR == 0x00`.

## Recommended next action
Request human approval to update `tb/tb_soc_top.sv` GPIO BFM `ECHO_INV` condition so it drives `8'h00` when `gpio_oe_o != 8'h0F` (i.e. while `GPIO_DIR` is `0x00` at reset/Step 1 and `0xFF` in Step 3) and drives `{~gpio_o[3:0], gpio_o[3:0]}` only when `gpio_oe_o == 8'h0F` (Step 4 of `VER_GPIO_001.S` and Step 2 of `VER_PERIPH_INT_001.c`):
```diff
-    end else if (gpio_mode == 1) begin
+    end else if (gpio_mode == 1 && gpio_oe_o == 8'h0F) begin
```
Upon human approval, apply this 1-line fix to `tb/tb_soc_top.sv` and execute rerun `RUN-GATE5-002` while preserving `RUN-GATE5-001` and `INV-GATE5-001`.

## Human decision
- Decision: `APPROVED` (`DEC-VER-PATCH-001.md` — approved `tb/tb_soc_top.sv` GPIO BFM fix `gpio_mode == 1 && gpio_oe_o == 8'h0F` and rerun `RUN-GATE5-002`)
- Approved owner: Human Engineering Owner
- Date: 2026-11-27
