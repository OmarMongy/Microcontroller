# Task Report

- Report ID: `REP-RTL-002`
- Date/time: `2026-11-27 15:23 (+02:00)`
- Agent/role: RTL Designer Agent
- Task: `RTL-002` — RTL Memory Synthesis Investigation (`dram_local` cell expansion & `irom_local` zero-cell collapse; NO RTL modifications)
- Status: `REVIEW_REQUIRED` (Investigation complete; RTL Change Proposal `RCP-RTL-001` submitted for human decision)
- Relevant spec/interface revision:
  - `CON-MEM-001` v1.1 (`LOCAL_MEMORY_INTERFACE_CONTRACT.md`)
  - `CON-TOP-001` v1.1 (`SOC_TOP_HIERARCHY_CONTRACT.md`)
  - Related report: [REP-RTL-001.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-RTL-001.md)
- Git branch/commit: `dev/gate2-4-rtl-and-verif` (branched from `main` checkpoint `85dcd83`, `UNCOMMITTED`, zero files under `rtl/` modified)

## Work performed

Investigated the two Yosys 0.52 generic synthesis observations from `REP-RTL-001`:
1. Why `dram_local` mapped to `565,510` generic cells (including `262,144` `$_DFFE_PP_` cells).
2. Why `irom_local` mapped to `0` cells when `INIT_FILE == ""`, and how `irom_local` behaves under Yosys 0.52 when a non-empty `.mem` file is supplied via `chparam`.

All experiments were executed read-only against `rtl/` (or using temporary scratch copies in `/tmp` which were removed afterward). **No RTL files under `rtl/` were modified.**

---

## Findings

### 1. `dram_local` Generic Cell Expansion (`565,510` Cells / `262,144` `$_DFFE_PP_` FFs)
- **Root Cause (Expected Generic Synthesis Behavior):**
  - Pre-`memory_map` (`proc; opt; memory -nomap`), Yosys 0.52 cleanly infers `dram_local` as a single **`$mem_v2`** cell (`SIZE = 8192`, `WIDTH = 32`, `ABITS = 13`, total storage = **`262,144` bits = `32 KB`**), with `1` synchronous write port (consolidated from the 4 byte-enable lanes) and `1` synchronous read port (`dram_rdata` merged by `MEMORY_DFF` with `RD_ARST_VALUE = 0`), totaling only **`22` RTLIL cells** (`1 $mem_v2`, `16 $mux`, `3 $logic_and`, `2 $logic_not`).
  - Note: Yosys `stat` reports `Number of memories: 0` because `memory_collect` emits the newer `$mem_v2` cell rather than legacy `$mem` cells; the `262,144`-bit memory is directly present as `$mem_v2 \mem`.
  - During `synth` (with no target FPGA BRAM or ASIC SRAM technology library), Yosys runs `memory_map`, which lowers `$mem_v2` into discrete flip-flops and combinational decode/read-mux trees:
    - `262,144` `$_DFFE_PP_` cells (the `8192 x 32` storage array, confirming **no hardware `rst_n` reset tree** per `CON-MEM-001` §2.6 / `DEC-ARCH-CORE-001` Option RST-A),
    - `32` `$_DFFE_PN0P_` cells (the async-reset `dram_rdata` output register),
    - `262,112` `$_MUX_` cells + `41,222` generic logic gates (`$_ANDNOT_`, `$_OR_`, etc.) implementing the `8192:1 x 32` read mux and 13-to-8192 write-enable decoder, totaling `565,510` cells.
- **Conclusion for `dram_local`:** **Expected and compliant.** No RTL defect or change needed.

### 2. `irom_local` Zero-Cell Collapse (`0` Cells Even With Non-Empty `IROM_INIT_FILE`)
- **Finding 2A — Effect of `` `ifndef SYNTHESIS `` on Current `rtl/irom_local.sv`:**
  - Yosys `read_verilog -sv` defines the `SYNTHESIS` preprocessor macro automatically.
  - Because lines 34–43 of [irom_local.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/irom_local.sv#L34-L43) place the entire `initial` block (both the `32'h0` zeroing loop AND `if (INIT_FILE != "") $readmemh(INIT_FILE, mem);`) inside `` `ifndef SYNTHESIS ``, Yosys **never executes `$readmemh`**, even when `IROM_INIT_FILE` is overridden via `chparam -set IROM_INIT_FILE "/tmp/test_rom.mem" soc_top`.
  - Consequently, `OPT_MEM` detects zero writes and zero initialization on `mem`, logs `removing const-x lane 0..31`, and optimizes `irom_local` down to `0` cells (`2` pre-map cells `$adffe` + `$mux`, `0` post-`synth`).
- **Finding 2B — Secondary Yosys Pitfall Discovered With `for` Loop + `$readmemh`:**
  - In scratch experiments (`/tmp/irom_local_exp.sv` and `/tmp/irom_local_exp3.sv`), simply removing `` `ifndef SYNTHESIS `` while leaving `for (int i = 0; i < DEPTH; i++) mem[i] = 32'h0;` visible to Yosys (even in a separate `initial` block!) **still caused `irom_local` to fold to `0` cells** in `synth`, and added ~23–25 seconds per elaboration/chparam pass.
  - Cause: Yosys 0.52's `read_verilog`/`MEMORY_COLLECT` assigns the unrolled `for`-loop `$meminit` writes higher priority than `$readmemh`, overwriting the `.mem` contents with `0` in `$mem_v2` `INIT` (`0` non-zero bits in `INIT`), so `OPT_DFF` folded all `8192` `$dff`s to constant `0`!
- **Finding 2C — Validated Fix (`/tmp/irom_local_exp2.sv`):**
  - Keeping the `for (int i = 0; i < DEPTH; i++) mem[i] = {DATA_WIDTH{1'b0}};` zero-default loop inside `` `ifndef SYNTHESIS `` (simulation-only) and placing ONLY `initial begin if (INIT_FILE != "") $readmemh(INIT_FILE, mem); end` outside `` `ifndef SYNTHESIS `` resolves both issues:
    1. When `INIT_FILE == ""` (`EXP 2D`): `read_verilog -sv` + `hierarchy` + `memory -nomap` succeeds in `0.01s` (`EXIT=0`, no file-open error).
    2. When `INIT_FILE == "/tmp/test_rom.mem"` (`EXP 2E`, `EXP 2F`, `EXP 2H`):
       - Pre-map (`irom_local`): `4` cells including `1 $mem_v2` (`SIZE=8192, WIDTH=29` after `OPT_MEM` pruned 3 const-0 bit lanes `14, 17, 24`, `2` read ports).
       - Pre-map (`soc_top`): `713` cells including **`$mem_v2 2`** (both `dram_local` and `irom_local` inferred as memories in `0.64s`).
       - Post-`synth` (`irom_local`): **`72` generic cells** (`15 $_DFFE_PN0P_`, `12 $_MUX_`, `23 $_ANDNOT_`, `7 $_OR_`, `4 $_NOT_`, `4 $_ORNOT_`, `2 $_AND_`, `2 $_NAND_`, `2 $_NOR_`, `1 $_XOR_`) — the programmed ROM contents are retained and synthesized into logic!

---

## Files created/changed

- Created:
  - [REP-RTL-002.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-RTL-002.md)
- Modified: **None** (`rtl/` untouched).
- Temporary `/tmp` test files (`/tmp/test_rom.mem`, `/tmp/irom_local_exp*.sv`, `/tmp/exp*.log`): deleted after observation.

## Commands and tool versions

- Tool version: `Yosys 0.52 (git sha1 fee39a3284c90249e1d9684cf6944ffbbcbb8f90)`

1. **Exp 1 — Current `rtl/irom_local.sv` inside `soc_top` with non-empty `IROM_INIT_FILE`:**
   ```bash
   yosys -p "read_verilog -sv rtl/soc_pkg.sv rtl/rst_sync.sv rtl/irom_local.sv rtl/dram_local.sv rtl/data_bus_decode.sv rtl/apb3_bridge.sv rtl/uart_apb.sv rtl/gpio_apb.sv rtl/timer_apb.sv rtl/rv32i_cpu.sv rtl/soc_top.sv; chparam -set IROM_INIT_FILE \"/tmp/test_rom.mem\" soc_top; hierarchy -check -top soc_top; proc; opt; memory -nomap; stat"
   ```
   - Result: `EXIT=0`; `irom_local.mem: removing const-x lane 0..31`; `irom_local` reduced to `2` cells (`$adffe 1`, `$mux 1`); `soc_top` has only `1` `$mem_v2` (`dram_local`).

2. **Exp 2A–2C — Scratch `irom_local` without `` `ifndef SYNTHESIS `` (retaining `for`-loop + `$readmemh`):**
   ```bash
   yosys -p "read_verilog -sv /tmp/irom_local_exp.sv; chparam -set INIT_FILE \"/tmp/test_rom.mem\" irom_local; hierarchy -check -top irom_local; proc; opt; memory -nomap; dump irom_local; stat"
   yosys -p "read_verilog -sv /tmp/irom_local_exp.sv; chparam -set INIT_FILE \"/tmp/test_rom.mem\" irom_local; synth -top irom_local; stat"
   ```
   - Result: `EXIT=0`, but `for`-loop `$meminit` overwrote `$readmemh` (`INIT` had `0` `'1'` bits), so `synth` still collapsed `irom_local` to `0` cells (and `2G` with separate `initial` blocks also collapsed to `0` cells).

3. **Exp 2D–2F & 2H — Scratch `irom_local` with `for`-loop under `` `ifndef SYNTHESIS `` and `$readmemh` always active:**
   ```bash
   yosys -p "read_verilog -sv /tmp/irom_local_exp2.sv; hierarchy -check -top irom_local; proc; opt; memory -nomap; stat"
   yosys -p "read_verilog -sv /tmp/irom_local_exp2.sv; chparam -set INIT_FILE \"/tmp/test_rom.mem\" irom_local; hierarchy -check -top irom_local; proc; opt; memory -nomap; stat"
   yosys -p "read_verilog -sv /tmp/irom_local_exp2.sv; chparam -set INIT_FILE \"/tmp/test_rom.mem\" irom_local; synth -top irom_local; stat"
   yosys -p "read_verilog -sv rtl/soc_pkg.sv rtl/rst_sync.sv /tmp/irom_local_exp2.sv rtl/dram_local.sv rtl/data_bus_decode.sv rtl/apb3_bridge.sv rtl/uart_apb.sv rtl/gpio_apb.sv rtl/timer_apb.sv rtl/rv32i_cpu.sv rtl/soc_top.sv; chparam -set IROM_INIT_FILE \"/tmp/test_rom.mem\" soc_top; hierarchy -check -top soc_top; proc; opt; memory -nomap; stat"
   ```
   - Result: `EXIT=0` for `INIT_FILE=""` (`0.01s`); `EXP 2E` pre-map `4` cells (`$mem_v2 1`); `EXP 2F` post-`synth` **`72` cells** (`15 $_DFFE_PN0P_`, `12 $_MUX_`, `45` gates); `EXP 2H` `soc_top` pre-map `713` cells (**`$mem_v2 2`**).

4. **Exp 3A–3B — `dram_local` pre-map vs post-map comparison:**
   ```bash
   yosys -p "read_verilog -sv rtl/dram_local.sv; hierarchy -check -top dram_local; proc; opt; memory -nomap; dump dram_local; stat"
   yosys -p "read_verilog -sv rtl/dram_local.sv; synth -top dram_local; stat"
   ```
   - Result: Pre-map (`3A`): `22` cells (`$mem_v2 1` with `SIZE 8192, WIDTH 32, ABITS 13` = `262,144` bits = `32 KB`, `1` WR port, `1` RD port). Post-map (`3B`): `565,510` cells (`262,144 $_DFFE_PP_`, `32 $_DFFE_PN0P_`, `262,112 $_MUX_`, `41,222` gates), `0` problems, `0` latches.

## Results and evidence paths

| Experiment | Scope / Config | Pre-Map `$mem_v2` | Pre-Map Cells | Post-`synth` Cells | Notes |
|---|---|---:|---:|---:|---|
| `EXP 3A/3B` | `rtl/dram_local.sv` | 1 (`8192x32` = 262,144 b) | 22 | 565,510 | `262,144 $_DFFE_PP_` (no reset tree) + `32 $_DFFE_PN0P_` |
| `EXP 1` | `rtl/irom_local.sv` (`INIT_FILE="/tmp/test_rom.mem"`) | 0 (const-x pruned) | 2 | 0 | `` `ifndef SYNTHESIS `` blocked `$readmemh` |
| `EXP 2B/2C` | `/tmp/irom_local_exp.sv` (`for` loop + `$readmemh`) | 1 (all-zero `INIT`) | 4 | 0 | `for` loop `$meminit` overwrote `$readmemh` in Yosys |
| `EXP 2D` | `/tmp/irom_local_exp2.sv` (`INIT_FILE=""`) | 0 (const-x pruned) | 2 | — | Clean `EXIT=0` in `0.01s` |
| `EXP 2E/2F` | `/tmp/irom_local_exp2.sv` (`INIT_FILE="/tmp/test_rom.mem"`) | 1 (`8192x29`) | 4 | 72 | `15 $_DFFE_PN0P_` + `57` mux/logic cells; ROM retained |
| `EXP 2H` | `soc_top` + `irom_local_exp2.sv` (`"/tmp/test_rom.mem"`) | 2 (`dram` + `irom`) | 713 | — | Both local memories inferred as `$mem_v2` |

- Evidence: [REP-RTL-002.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-RTL-002.md) (this report).

## Assumptions / unresolved questions

- **Note on unprogrammed ROM words during synthesis:** When `for (int i = 0; i < DEPTH; i++) mem[i] = 0;` is kept under `` `ifndef SYNTHESIS ``, simulation initializes unprogrammed words to `32'h0000_0000` (`CON-MEM-001` §1.5), while Yosys treats unprogrammed addresses absent from `INIT_FILE` as `X`/don't-care during combinational ROM optimization (if full 32 KB `0`-padding is desired in synthesis, the `.mem` firmware image can simply include zero-filled words, or a synthesis target BRAM init can default to zero).

---

## RTL Change Proposal (`RCP-RTL-001`)

- Proposal ID: `RCP-RTL-001`
- Related report: `REP-RTL-002`
- Author: RTL Designer Agent
- RTL branch/commit: `dev/gate2-4-rtl-and-verif` (branched from `85dcd83`, `UNCOMMITTED`)
- Human approval status: `PENDING`

### Suspected root cause and evidence
In [irom_local.sv](file:///mnt/e/PB/Projects/Microcontroller/rtl/irom_local.sv#L34-L43), `$readmemh(INIT_FILE, mem)` is wrapped inside `` `ifndef SYNTHESIS ``. Because Yosys defines `SYNTHESIS` automatically, synthesizing `soc_top` or `irom_local` with a non-empty `IROM_INIT_FILE` / `INIT_FILE` parameter ignores the `.mem` image and collapses `irom_local` to `0` cells (`EXP 1`). Additionally, `EXP 2B/2C/2G` proved that keeping the `8192`-word `for` loop visible to Yosys overrides `$readmemh` with `0`s in Yosys's `$meminit` priority order.

### Proposed files/lines changed
- File: `rtl/irom_local.sv`, lines 34–43:
  - Current:
    ```systemverilog
    `ifndef SYNTHESIS
        initial begin
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] = {DATA_WIDTH{1'b0}};
            end
            if (INIT_FILE != "") begin
                $readmemh(INIT_FILE, mem);
            end
        end
    `endif
    ```
  - Proposed (single `initial` block — avoids simulation `initial`-block race while keeping the `for`-loop simulation-only):
    ```systemverilog
        initial begin
    `ifndef SYNTHESIS
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] = {DATA_WIDTH{1'b0}};
            end
    `endif
            if (INIT_FILE != "") begin
                $readmemh(INIT_FILE, mem);
            end
        end
    ```

### Proposed behavior change
- **Simulation (`SYNTHESIS` undefined):** Executes the `for` loop (zeros all `8192` words) followed sequentially in the **same `initial` block** by `$readmemh` (overlays programmed words), preserving `CON-MEM-001` §1.5 with **zero simulation race condition**.
- **Yosys synthesis (`SYNTHESIS` defined):** Preprocessor strips ONLY the `for` loop, leaving `initial begin if (INIT_FILE != "") $readmemh(INIT_FILE, mem); end` (verified in `EXP 2D/2E/2F/2H`).

### Potential side effects
- When `INIT_FILE == ""`, Yosys synthesis behavior is unchanged (`irom_local` optimizes to `0` cells, fast `0.01s`).
- When `INIT_FILE != ""`, Yosys synthesizes the actual ROM contents (`$mem_v2` pre-map / ROM logic post-map) instead of collapsing `irom_local` to `0` cells.
- Unprogrammed addresses not listed in `INIT_FILE` are zero-initialized in simulation (`CON-MEM-001` §1.5), and treated as don't-care by Yosys during synthesis unless explicitly present in the `.mem` file.

### Required regression tests
- Re-run `verilator --lint-only -Wall --top-module soc_top -f rtl/rtl.f`.
- Re-run Yosys `soc_top` synthesis with `IROM_INIT_FILE=""` AND pre-map/post-map check with a sample non-empty `.mem` file.
- Run Gate 5 simulation tests with `irom_local` `.mem` initialization (both programmed and unprogrammed words).

### Human decision and rationale
- Pending human review (`PENDING`).

## Recommended next action

1. Human / Orchestrator review of [REP-RTL-002.md](file:///mnt/e/PB/Projects/Microcontroller/reports/REP-RTL-002.md).
2. Approve or reject `RCP-RTL-001` (`rtl/irom_local.sv` single-`initial` `` `ifndef SYNTHESIS `` fix); apply only after explicit human authorization.
