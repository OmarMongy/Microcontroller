# Gate 9 Pre-Commit Engineering Audit Report (`REP-GATE9-001`)

- **Report ID:** `REP-GATE9-001`
- **Date/time:** `2026-11-27T18:20:00+02:00`
- **Agent/role:** Independent Pre-Commit Engineering Auditor (Main Orchestrator)
- **Task:** Gate 9 Pre-Commit Engineering Audit prior to human merge/sign-off
- **Status:** `REVIEW_REQUIRED` (Audit Checks `1–4`: `PASS`; Documentation & Reproducibility Audit `5`: `PASS` with minor non-blocking doc updates recommended)
- **Specification revision:** `SOC_SPECIFICATION_DRAFT.md` (Draft 0.3)
- **Frozen Interface Contracts:** `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-APB3-001` v1.1 (`IHI0024E` Issue B), `CON-FLT-RST-001` v1.1, `CON-TOP-001` v1.1, `CON-PERIPH-001` v1.0
- **Verification Baselines:** `SOC_VB_001.1` (`DEC-VER-BASELINE-003` `APPROVED`) and `SOC_VB_002` (`DEC-VER-BASELINE-002` `APPROVED`), plus `DEC-VER-PATCH-001` (`APPROVED`)
- **Git branch/commit:** `dev/gate2-4-rtl-and-verif` (HEAD `85dcd83a0b422befc4bcebae7e555a9ac1079cd8` / `85dcd83`, `UNCOMMITTED` working tree)
- **Baseline / Gate 9 Conclusion:** **`READY_FOR_HUMAN_SIGNOFF`**

---

## Executive Summary

An independent read-only audit of Git integrity, RTL (`rtl/*`), verification & SVA (`tb/*`, `sva/*`, `verification/firmware/*`, `docs/verification_plans/*`), Gate 5 regression logs (`RUN-GATE5-001`, `RUN-GATE5-002`, `INV-GATE5-001`), and project documentation/reproducibility found **zero RTL defects, zero specification discrepancies, zero unapproved changes to frozen contracts or `SOC_VB_001` requirements, zero SVA assertion errors, and 68/68 passing regression tests** in `RUN-GATE5-002`.

| Audit Area | Status | Summary Finding |
|---|---|---|
| 1. Git & Change Integrity | `PASS` | Clean diff vs `85dcd83`; zero edits to frozen contracts/`SOC_VB_001` expected behavior; PDF untracked; build dirs ignored. |
| 2. RTL Audit (`10` modules + pkg) | `PASS` | Full conformance to all 6 frozen contracts across RV32I ISA, Harvard/RAM-B, IROM RO write fault, APB3 `4A`, peripherals, reset, and fault priority. |
| 3. Verification & Independence Audit | `PASS` | Independent contract-derived SVA, Golden ISS, mock APB3, and firmware; all 3 alignment fixes strictly on verification side. *(Residual SVA-bind/ISS-scope notes documented in §3.4.)* |
| 4. Regression Evidence Audit | `PASS` | `RUN-GATE5-001` (`67/68 PASS`, `1` TB bug preserved) -> `INV-GATE5-001` -> `DEC-VER-PATCH-001` -> `RUN-GATE5-002` (`68/68 PASS`, `0` fail, `0` SVA errors, `exit 0`). |
| 5. Documentation & Reproducibility | `PASS` *(minor notes)* | `180/180` firmware SHA-256 `OK`; single-command Gate 5 script reproducible; pre-RTL `README.md`/`docs/README.md` prose & standalone synthesis script noted for post-sign-off housekeeping. |

---

## 1. Git and Change Integrity (`PASS`)

Verified read-only on branch `dev/gate2-4-rtl-and-verif` at HEAD `85dcd83a0b422befc4bcebae7e555a9ac1079cd8` (`85dcd83`) with zero Git write/stage/commit/merge/push/clean commands executed.

### 1.1 Working Tree Inventory (`git status --short --untracked-files=all --ignored`)
- **Modified tracked files (`3` files, `40 insertions(+), 6 deletions(-)` vs `85dcd83`):**
  1. [regression_history.csv](file:///mnt/e/PB/Projects/Microcontroller/regression/regression_history.csv): appended `RUN-GATE5-001` (`FAIL`) and `RUN-GATE5-002` (`PASS`) rows.
  2. [Makefile](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/Makefile): added `.PRECIOUS: $(BUILD_DIR)/%.elf $(BUILD_DIR)/%.bin` (per approved `DEC-VER-BASELINE-003`) and `SOC_VB_002` targets (`all-v2`, `periph-images`); `SOC_VB_001` compilation rules preserved.
  3. [VER_CORE_003.S](file:///mnt/e/PB/Projects/Microcontroller/verification/firmware/src/VER_CORE_003.S): patched three `+0xFFC` negative 12-bit signed-immediate assembly errors on `s0`/`s2`/`s3` using `t5` address calculation (per approved `DEC-VER-BASELINE-003` / `VCP-VER-001`).
- **Added untracked project files prior to `REP-GATE9-001.md` (`54` files, excluding reference PDF):**
  - Decisions (`4`): `docs/decisions/DEC-RTL-PATCH-001.md`, `DEC-VER-BASELINE-002.md`, `DEC-VER-BASELINE-003.md`, `DEC-VER-PATCH-001.md`.
  - Verification V2 plans (`3`): `docs/verification_plans/VERIFICATION_PLAN_V2.md`, `SVA_SPECIFICATION_V2.md`, `COVERAGE_PLAN_V2.md`.
  - Regression records (`5`): `regression/investigations/INV-GATE5-001.md`, `regression/runs/RUN-GATE5-001.{md,log}`, `regression/runs/RUN-GATE5-002.{md,log}`.
  - Task reports (`8`, plus newly created `reports/REP-GATE9-001.md`): `reports/REP-GATE5-READINESS.md`, `REP-RTL-001.md`, `REP-RTL-002.md`, `REP-RTL-003.md`, `REP-VER-002.md`, `REP-VER-003.md`, `REP-VER-004.md`, `REP-VER-005.md`.
  - RTL (`12`): `rtl/rtl.f`, `soc_pkg.sv`, `rst_sync.sv`, `rv32i_cpu.sv`, `irom_local.sv`, `dram_local.sv`, `data_bus_decode.sv`, `apb3_bridge.sv`, `uart_apb.sv`, `gpio_apb.sv`, `timer_apb.sv`, `soc_top.sv`.
  - SVA (`5`): `sva/sva_apb3_if.sv`, `sva_binds.sv`, `sva_cpu_fault_rst.sv`, `sva_mem_if.sv`, `sva_periph_if.sv`.
  - Testbench & Runner (`7`): `tb/tb_pkg.sv`, `mock_apb_completer.sv`, `rv32i_golden_iss.sv`, `tb_cov_collector.sv`, `tb_core_bus.sv`, `tb_soc_top.sv`, `run_gate5.py`.
  - Peripheral Firmware (`10`): `verification/firmware/TEST_MANIFEST_V2.md`, `include/periph_regs.inc`, `src/crt0_periph.S`, `VER_GPIO_001.S`, `VER_GPIO_002.S`, `VER_TIMER_001.S`, `VER_TIMER_002.S`, `VER_UART_001.S`, `VER_UART_002.S`, `VER_PERIPH_INT_001.c`.
- **Deleted files:** `0`.
- **Intentionally untracked & ignored files confirmed:**
  - `?? docs/specifications/references/IHI0024E_amba_apb_architecture_spec.pdf` remains untracked.
  - `!! build/` (`build/.gitkeep`) and `!! verification/firmware/build/` (`60` test stems, including `.bin`, `.dis`, `.elf`, `.map`, `.mem`, `.sha256` files) remain ignored via `.gitignore`.
  - Temporary Verilator `obj_dir_gate5_core_bus/` and `obj_dir_gate5_soc_top/` directories are cleaned up; workspace root is clean.
- **Frozen artifact diff check (`git diff 85dcd83 -- ...`):** **Empty (`0` bytes changed, exit `0`)** across all 6 frozen `docs/interface_contracts/*.md` files, all earlier `docs/decisions/DEC-ARCH-*`/`DEC-CPU-*`/`DEC-VER-BASELINE-001.md` records, all `SOC_VB_001` plans (`VERIFICATION_PLAN_V1.md`, `SVA_SPECIFICATION_V1.md`, `COVERAGE_PLAN_V1.md`), `TEST_MANIFEST.md`, `TOOLCHAIN_AND_BUILD.md`, `link.ld`, `bin2mem.py`, `crt0.S`, `VER_CORE_001.S`, `VER_CORE_002.S`, `VER_CORE_004.c`, and `VER_FAULT_001..011.S`.

---

## 2. RTL Audit Against Approved Contracts (`PASS`)

All 12 files in `rtl/` were inspected against the 6 frozen contracts:

1. **RV32I Base ISA & Single-Cycle Execution ([rv32i_cpu.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/rv32i_cpu.sv#L100-L405)):**
   - Implements all 40 base RV32I unprivileged instructions plus `FENCE` (`opcode=7'b0001111`, `funct3=3'b000`, line 303–305) executing as a valid single-cycle NOP once no memory stall blocks retirement.
   - `JALR` correctly clears LSB (`(rs1 + imm_i) & 32'hFFFF_FFFE`, line 177), preserving misaligned-target detection (`addr[1:0] != 2'b00`) on `PC_next` (`CON-FLT-RST-001`).
   - `x0` hardwired to `32'h0`; `x1..x31` reset to `32'h0`. Register-file writeback and PC update are strictly gated by `!fault_valid && !fault_detect && !dmem_stall` so stalled or faulting instructions never commit architectural state.
   - `SYSTEM` (`ECALL`/`EBREAK`), `CSRs`, `FENCE.I`, `MRET`, and `M`-extension opcodes raise `FAULT_ECALL` (`4'h4`), `FAULT_EBREAK` (`4'h5`), or `FAULT_ILLEGAL_INSN` (`4'h3`) with zero `dmem_req` assertion (`dmem_req` gated by `!fault_valid && !if_fault && !is_ecall && !is_ebreak && !illegal_insn`).
   - **Discrepancies found:** None.

2. **Harvard Local Memory, Byte Enables & IROM RO Enforcement ([irom_local.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/irom_local.sv#L34-L61), [dram_local.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/dram_local.sv#L37-L54), [data_bus_decode.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/data_bus_decode.sv#L63-L198)):**
   - **Modified Harvard (`CON-ADDR-001` v1.1, `CON-MEM-001` v1.1):** `irom_local` (`0x0000_0000..0x0000_7FFF`, 8192 words) exposes Port A (`always_comb` 0-cycle IF when `irom_en` else `0`) and Port B (`always_ff` 1-cycle synchronous read `irom_dreq` -> `irom_drdata`). Approved `RCP-RTL-001` (`DEC-RTL-PATCH-001`) restricts `for`-loop zeroing to `` `ifndef SYNTHESIS `` while keeping `$readmemh(INIT_FILE, mem)` active for both simulation and Yosys synthesis.
   - **DRAM `Option RAM-B` (`CON-MEM-001` v1.1):** `dram_local` (`0x2000_0000..0x2000_7FFF`, 8192 words) implements synchronous byte-enabled writes (`dram_be` for `SB`/`SH`/`SW`, no hardware reset tree on 32 KB storage array) and 1-cycle synchronous reads (`dram_rdata` reset to `0`, 2-cycle `local_rd_valid` handshake in `data_bus_decode` for both `IROM` Port B and `DRAM` reads, zero wait states on `DRAM` stores).
   - **IROM RO Enforcement (`DEC-ARCH-CORE-002`):** Stores (`SB`/`SH`/`SW`) targeting `0x0000_0000..0x0000_7FFF` raise `FAULT_DATA_RO_WRITE` (`4'hA`) combinatorially in `data_bus_decode`, suppressing `irom_dreq`, `dram_req`, and `apb_req_valid`.
   - **Discrepancies found:** None. *(Generic Yosys synthesis without SRAM macro blackboxing maps `dram_local` to `565,510` generic cells including `262,144` `$_DFFE_PP_` flip-flops, which is expected and approved under Gate 1 generic synthesis rules per `REP-RTL-002`/`REP-RTL-003`.)*

3. **APB3 Bridge Timing & Wait-State Handling ([apb3_bridge.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/apb3_bridge.sv#L5-L144), [data_bus_decode.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/data_bus_decode.sv#L63-L198)):**
   - Implements `Design 4A` registered FSM (`APB_IDLE -> APB_SETUP -> APB_ACCESS`) driving strict ARM IHI 0024E Issue B APB3 signals (`PADDR`, `PSEL_UART`/`PSEL_GPIO`/`PSEL_TIMER`, `PENABLE`, `PWRITE`, `PWDATA`, `PREADY_*`, `PRDATA_*`, `PSLVERR_*`) — zero APB4/APB5 extensions (`PSTRB`/`PPROT` absent).
   - Enforces `Option APB-W1` in `data_bus_decode`: only aligned 32-bit `LW`/`SW` enter APB3; sub-word (`LB`/`LBU`/`LH`/`LHU`/`SB`/`SH`) and misaligned word (`addr[1:0] != 0`) transactions fault immediately without asserting `apb_req_valid`.
   - Supports arbitrary `PREADY=0` wait cycles (`apb_rsp_ready = (state == APB_ACCESS) && pready_mux`), ignores `PSLVERR` outside `ACCESS && PREADY`, and returns `apb_rsp_err = apb_rsp_ready && pslverr_mux` on completion while holding CPU PC and `dmem_*` request stable.
   - **Discrepancies found:** None.

4. **Peripheral Registers ([uart_apb.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/uart_apb.sv#L81-L301), [gpio_apb.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/gpio_apb.sv#L44-L103), [timer_apb.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/timer_apb.sv#L49-L156)):**
   - All three completers tie `PREADY = 1'b1`, apply strict `CON-PERIPH-001` v1.0 `PSLVERR` rules (including UART RX_DATA write, TX_DATA read, 24-bit `BAUD_DIV < 2` rejection returning `DEFAULT_BAUD_DIV = 434` intact; GPIO `DATA_IN` write; out-of-range offsets returning `PRDATA = 32'h0`), and enforce 2-FF input synchronizers on `uart_rx_i` and `gpio_i[7:0]`.
   - Timer matches `COMPARE` reset value `32'hFFFF_FFFF`, `CLR_CNT` self-clearing WO/SC behavior, counter increment/reload/overflow precedence, and W1C `STATUS`.
   - **Discrepancies found:** None.

5. **Reset & Fault Reporting / Priority ([rst_sync.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/rst_sync.sv#L1-L30), [soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/soc_top.sv#L5-L255), [rv32i_cpu.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/rv32i_cpu.sv), [data_bus_decode.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/data_bus_decode.sv)):**
   - `rst_sync` implements `Option RST-A` active-low asynchronous reset assertion, synchronous release through 2 flip-flops.
   - `soc_top` exposes exact `CON-TOP-001` v1.1 ports (`clk`, `rst_n`, `uart_rx_i`, `uart_tx_o`, `gpio_i[7:0]`, `gpio_o[7:0]`, `gpio_oe_o[7:0]`, `fault_o`, `fault_code_o[3:0]`, `fault_pc_o[31:0]`, `fault_addr_o[31:0]`, `fault_insn_o[31:0]`).
   - Exact 8-level fault priority matches `CON-FLT-RST-001` §1.2 (`IF_MISALIGNED` > `IF_UNMAPPED` > `ILLEGAL_INSN`/`ECALL`/`EBREAK` > `DATA_UNMAPPED` > `DATA_RO_WRITE` > `DATA_SIZE_UNSUP` > `DATA_MISALIGNED` > `APB_SLVERR`), sticky capture in `rv32i_cpu` holding CPU quiescent until `sys_rst_n == 0`.
   - **Discrepancies found:** None.

---

## 3. Verification Environment & Independence Audit (`PASS`)

### 3.1 Verification Architecture & Independence
- **Contract-driven design:** Plans (`VERIFICATION_PLAN_V1/V2`, `SVA_SPECIFICATION_V1/V2`, `COVERAGE_PLAN_V1/V2`), [tb_pkg.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_pkg.sv), [rv32i_golden_iss.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/rv32i_golden_iss.sv), [mock_apb_completer.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/mock_apb_completer.sv), all 5 `sva/*.sv` modules, and all `verification/firmware/` sources derive directly from the 6 frozen contracts without weakening assertions or fitting expected results to RTL.
- **Golden ISS scoreboard (`rv32i_golden_iss.sv`):** Independently loads `+MEM_FILE=`, maintains its own shadow RV32I RF/DRAM/IROM model, retires 1 instruction only when `!dut_dmem_stall && !dut_fault_valid`, compares `dut_pc`, APB3 read results, and expected `fault_code`/`fault_pc`/`fault_addr`/`fault_insn`, and enforces `sb_errors == 0`.

### 3.2 Integration Mismatch Corrections (`REP-VER-003`)
Confirmed all 3 prior Gate 4/5 integration fixes were applied **strictly on the verification side** (`rtl/` untouched):
1. **IROM parameter:** [tb_soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_soc_top.sv#L30) instantiates `soc_top #(.IROM_INIT_FILE(INIT_FILE)) u_dut` matching `rtl/soc_top.sv`.
2. **Fault port:** [tb_core_bus.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_core_bus.sv#L139) connects `.cpu_fault_valid(fault_valid)` on `data_bus_decode u_decode` matching `rtl/data_bus_decode.sv`.
3. **APB3 bridge completers:** [tb_core_bus.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_core_bus.sv#L77-L94) and [sva_binds.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_binds.sv#L20-L40) connect and mux per-completer `PSEL_{UART,GPIO,TIMER}`, `PREADY_*`, `PRDATA_*`, and `PSLVERR_*` matching `rtl/apb3_bridge.sv`.

### 3.3 SVA Bind & Runner Review
- **Bound at runtime in `RUN-GATE5-002`:**
  - `tb_core_bus` and `tb_soc_top` both bind Part A checkers: `sva_soc_fault_rst_if`, `sva_apb3_if`, `sva_uart_apb_if`, `sva_gpio_apb_if`, and `sva_timer_apb_if`.
  - `tb_soc_top` additionally compiles with `-DSVA_ENABLE_INTERNAL_BINDS` ([run_gate5.py](file:///mnt/e/PB/Projects/Microcontroller/tb/run_gate5.py#L115)), binding `sva_mem_if` to `soc_top` ([sva_binds.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_binds.sv#L85-L113)).

### 3.4 Non-Blocking Verification Scope Observations (Transparent Auditor Notes)
1. **`sva_cpu_internal` defined but not bound ([sva_cpu_fault_rst.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_cpu_fault_rst.sv#L83-L174), [sva_binds.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_binds.sv#L85-L113)):** Under `` `ifdef SVA_ENABLE_INTERNAL_BINDS ``, `sva_binds.sv` binds `sva_mem_if`, leaving `sva_cpu_internal` (`SVA-CPU-001/003/004/005/006a/006b`, `SVA-INT-001`, `SVA-FLT-004`, `SVA-RST-001/002/004`) unbound at runtime. Functional equivalence is checked by `sva_soc_fault_rst_if` + `sva_mem_if` + `rv32i_golden_iss` + `VER-CORE-001` self-checks, except the single-cycle 2-FF `rst_sync` internal staging check (`SVA-RST-002`) rests on RTL code inspection rather than active SVA binding.
2. **Golden ISS RF writeback tie-off ([tb_core_bus.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_core_bus.sv#L285-L287), [tb_soc_top.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_soc_top.sv#L100-L102)):** `.dut_rf_we(1'b0)`, `.dut_rf_waddr(5'd0)`, `.dut_rf_wdata(32'h0)` are tied off; register-value correctness is verified via firmware self-checks + DRAM mailbox + ISS PC/memory/fault checking rather than port-level RF snoop comparison.
3. **`sva_apb3_if` `dmem_fault_*` bind tie-off ([sva_binds.sv](file:///mnt/e/PB/Projects/Microcontroller/sva/sva_binds.sv#L38-L39)):** `.dmem_fault_valid(1'b0)` / `.dmem_fault_code(4'h0)` leaves the `dmem_fault` sub-clause of `a_apb_010b_no_early_slverr` unused inside `sva_apb3_if`, while `!apb_rsp_ready` remains actively asserted and `VER-BUS-001_w16_glitch` exercises wait-state `PSLVERR` suppression end-to-end.

---

## 4. Regression Evidence Audit (`PASS`)

Inspected [RUN-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-001.md), [RUN-GATE5-001.log](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-001.log), [INV-GATE5-001.md](file:///mnt/e/PB/Projects/Microcontroller/regression/investigations/INV-GATE5-001.md), [RUN-GATE5-002.md](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-002.md), [RUN-GATE5-002.log](file:///mnt/e/PB/Projects/Microcontroller/regression/runs/RUN-GATE5-002.log), and [regression_history.csv](file:///mnt/e/PB/Projects/Microcontroller/regression/regression_history.csv).

### 4.1 Historical `RUN-GATE5-001` & Investigation Integrity
- `RUN-GATE5-001` (`67 PASS`, `1 FAIL` on `VER-GPIO-001`, `exit 1` equivalent / `RUN-GATE5-001.log:62-65` `%Fatal: tb_soc_top.sv:284`) is preserved intact alongside `INV-GATE5-001.md` and `DEC-VER-PATCH-001.md`.
- Note on `RUN-GATE5-001.log:73`: the pre-patch runner printed `SVA_ASSERT_ERRORS=1` because Verilator `%Fatal` prints `"Assertion failed in tb_soc_top"`, which was corrected in [run_gate5.py](file:///mnt/e/PB/Projects/Microcontroller/tb/run_gate5.py#L229-L235) (`DEC-VER-PATCH-001`) so `sva_err_lines` strictly matches `u_sva_`/`sva_` instances separately from `has_tb_err` (`%Fatal|%Error|FAIL:`).

### 4.2 `RUN-GATE5-002` Exact Evidence Verification
- **Command & Exit Code:** `python3 tb/run_gate5.py --log regression/runs/RUN-GATE5-002.log` -> **`exit 0`** (`PASSED=68, FAILED=0, SVA_ERRORS=0, TOTAL=68`, `RUN-GATE5-002.log:77`).
- **Per-test count breakdown (`68` runs verified in `RUN-GATE5-002.log:2-69`):**
  - Core normal (`8`): `VER-CORE-001`, `VER-CORE-002`, `VER-CORE-003_w0/w1/w2/w5`, `VER-BUS-001_w16_glitch`, `VER-CORE-004`.
  - Fault tests & priority matrix (`44`): `VER-FAULT-001` (`3`), `002` (`2`), `003` (`6`), `004` (`1`), `005` (`1`), `006` (`6`), `007` (`3`), `008` (`6`), `009` (`7`), `010` (`3`), `011` (`5`) — covering all 10 fault codes `4'h1`..`4'hA` (`4'h1`: 2, `4'h2`: 4, `4'h3`: 6, `4'h4`: 2, `4'h5`: 13, `4'h6`: 7, `4'h7`: 8, `4'h8`: 7, `4'h9`: 15, `4'hA`: 4 across the 68 runs) and all 5 priority overlap cases (`VER-FAULT-011_sub0..4`).
  - Reset recovery (`3`): `VER-RST-002_apb_wait`, `VER-RST-002_local_rd`, `VER-RST-002_from_fault`.
  - Peripherals (`13`): `VER-UART-001`, `VER-UART-002_sub0..4` (`5`), `VER-GPIO-001`, `VER-GPIO-002_sub0..2` (`3`), `VER-TIMER-001`, `VER-TIMER-002_sub0..1` (`2`), `VER-PERIPH-INT-001`.
- **Coverage Counter Audit (`RUN-GATE5-002.log:71-76`, [tb_cov_collector.sv](file:///mnt/e/PB/Projects/Microcontroller/tb/tb_cov_collector.sv#L60-L151)):**
  - All RV32I instruction classes (`LUI=529`, `AUIPC=16`, `JAL=6`, `JALR=10`, `BR=825`, `LD=578`, `ST=341`, `ALUI=1543`, `ALUR=60`, `FENCE=24`, `X0_DST=424`), memory operations (`IROM_RD=44`, `DRAM_RD=32`, `DRAM_WR=174`, all 7 valid `BE_*` patterns), APB3 slots/waits/SLVERR (`UART=355`, `GPIO=120`, `TIMER=174`, `WAIT_0=570`, `WAIT_1=7`, `WAIT_2PLUS=72`, `SLVERR=13`), reset recovery (`DURING_STALL=2`, `FROM_FAULT=1`), and all 12 peripheral register slots are non-zero and accurately summed.
  - **Accounted collector quirks:**
    1. `FAULTS: 4'h4=1` with `0` for `4'h1..4'hA\4'h4`: expected artifact of breaking out of the poll loop (`tb_soc_top.sv:271`, `tb_core_bus.sv:376`) on the first `fault_o` edge before a subsequent `always_ff` clock sample; end-of-test assertions directly check `fault_code_o === exp_fault_code[3:0]` on all 68 runs.
    2. `DRAM_WR=174` vs `sum(BE_*)=172`: the `+2` difference comes from `VER-FAULT-009_sub4`/`sub5` (misaligned DRAM `SH`/`SW`), where combinational `dmem_req && dmem_we` triggers before `fault_o` latches while `dram_be=4'b0000` cleanly suppresses the actual write.
    3. `COV-SVA-*` cover-property hit totals (`c_apb_*`, `c_mem_*`, `c_rst_*`, `c_uart_*`, `c_gpio_*`, `c_tmr_*`) are not collected/printed by `run_gate5.py`.

### 4.3 Unexercised / Bounded Verification Scenarios
- **Dedicated `VER-RST-001` test row:** No separate `VER-RST-001` entry in `run_gate5.py` `tests[]`; instead, every `tb_soc_top` run (`58` runs) asserts cold reset pin defaults (`uart_tx_o=1`, `gpio_oe_o=0`, `gpio_o=0`, `fault_o=0`) and `sva_soc_fault_rst_if` checks reset properties on every clock.
- **Default UART baud rate (`434` vs `16`):** `VER-UART-001` and `VER-PERIPH-INT-001` use `+UART_BAUD_DIV=16` (`UART_BAUD_DIV=434` reset default verified by register reset check and `BAUD_DIV < 2` rejection).
- **Directed vs randomized scope:** UART RX short start-pulse glitch filtering, arbitrary-phase back-to-back UART/Timer/GPIO stress, and exhaustive multi-class fault combinations beyond `VER-FAULT-011_sub0..4` are covered only through RTL inspection and directed tests.

---

## 5. Documentation & Reproducibility Audit (`PASS` — Minor Post-Sign-Off Doc Notes)

- **Firmware Reproducibility:** Verified read-only via `cd verification/firmware && for f in build/*.sha256; do sha256sum -c "$f"; done` -> **`180 / 180` OK (`60` test images `.elf`, `.bin`, `.mem`), `0` failures**. Note: `.sha256` manifest paths use `build/<name>`, so verification must run from `verification/firmware/`.
- **Simulation Reproducibility:** `python3 tb/run_gate5.py --log regression/runs/RUN-GATE5-002.log` builds both testbenches, compiles SVA, runs all 68 tests, summarizes coverage, and cleans temporary directories using installed `Verilator 5.032` and `riscv64-unknown-elf-gcc 14.2.0+19` / `binutils 2.45.50`.
- **Lint & Generic Synthesis (`REP-RTL-003`):**
  - Verilator `--lint-only -Wall --top-module soc_top -f rtl/rtl.f` -> `EXIT=0`.
  - Yosys `0.52` `synth -top soc_top` (`IROM_INIT_FILE=""`) -> `EXIT=0`; `VER_CORE_001.mem` pre-map infers `$mem_v2 2` (`713` hierarchy cells, `0` problems); post-synth `irom_local` retains `1620` generic cells (`0` problems).
- **Minor Non-Blocking Documentation Findings:**
  1. [README.md](file:///mnt/e/PB/Projects/Microcontroller/README.md#L28) and [docs/README.md](file:///mnt/e/PB/Projects/Microcontroller/docs/README.md#L11) still carry Gate 0 pre-RTL wording (stating the repository does not contain RTL yet and listing only `DEC-ARCH-BASELINE-001..002`). Recommended to refresh once Gate 9 approves merge to `main`.
  2. Synthesis commands live inside `reports/REP-RTL-001..003.md` rather than a standalone script in `scripts/`, and `tb/run_gate5.py` lacks a short quickstart entry in root `README.md`.

---

## 6. Unresolved Questions & Recommended Next Action

- **Unresolved Questions:** None blocking RTL or verification integrity. Decide whether to:
  - Sign off Gate 9 as-is (`READY_FOR_HUMAN_SIGNOFF`) and perform `README.md`/`docs/README.md` cleanup on merge to `main`, or
  - Optionally request a tiny verification follow-up (bind `sva_cpu_internal` under `SVA_ENABLE_INTERNAL_BINDS` + refresh `README.md`) prior to committing.
- **Recommended Next Action:** Human review of `REP-GATE9-001.md` and explicit **Gate 9 Final Sign-Off & Commit/Merge Authorization** on `dev/gate2-4-rtl-and-verif` -> `main` (preserving `docs/specifications/references/IHI0024E_amba_apb_architecture_spec.pdf` untracked and `verification/firmware/build/` ignored).

**FINAL CONCLUSION: `READY_FOR_HUMAN_SIGNOFF`**
