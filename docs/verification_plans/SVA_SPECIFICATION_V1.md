# SystemVerilog Assertions (SVA) Specification V1

- **Document ID:** `SVA-SPEC-001`
- **Baseline ID:** `SOC_VB_001`
- **Version:** `V1.0`
- **Status:** `APPROVED / FROZEN (DEC-VER-BASELINE-001)`
- **Date:** 2026-11-27
- **Approved Decision:** [DEC-VER-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-001.md)
- **Author:** Independent Verification Engineer Agent
- **Contract Authority:**
  - `CON-ADDR-001` v1.1 (`ADDRESS_MAP_CONTRACT.md`)
  - `CON-MEM-001` v1.1 (`LOCAL_MEMORY_INTERFACE_CONTRACT.md`)
  - `CON-APB3-001` v1.1 (`APB3_BRIDGE_CONTRACT.md`) + `ARM IHI 0024E` (APB3 / Issue B only)
  - `CON-FLT-RST-001` v1.1 (`FAULT_AND_RESET_CONTRACT.md`)
  - `CON-TOP-001` v1.1 (`SOC_TOP_HIERARCHY_CONTRACT.md`)
  - `DEC-ARCH-CORE-002` (`FENCE`, `FAULT_DATA_RO_WRITE`, `IROM` Port B 1-cycle sync read)

---

## 1. SVA Architecture, Clocking, Reset, and Separation Rules

1. **Clocking Event:**
   - All synchronous protocol and microarchitectural properties are clocked on `@(posedge clk)` (which equals `@(posedge PCLK)`, 50 MHz shared clock per `DEC-ARCH-BASELINE-001`).
2. **Disable / Reset Assumptions:**
   - **Operational Assertions:** Use `disable iff (!sys_rst_n)` (or `disable iff (!PRESETn)` on the APB3 boundary) so properties evaluate only after synchronized reset release.
   - **Reset-Specific Assertions (`SVA-RST-*`):** Do **NOT** use `disable iff (!sys_rst_n)`; instead they trigger on `!rst_n` or `!sys_rst_n` directly to verify asynchronous assertion, 2-FF synchronous deassertion, and reset output values.
   - **Known-Value Assumption:** Interface signals are assumed 2-state/known (`!$isunknown(...)`) after reset release (`sys_rst_n == 1`) where applicable.
3. **Separation of Interface vs. Internal Properties (per `.agents/skills/sva/SKILL.md`):**
   - **Part A — Interface Protocol Properties (Black-Box / Port Boundary):** Bound to module boundaries (`apb3_bridge` APB3 bus, `irom_local` Port A/B, `dram_local`, `data_bus_decode` <-> `apb3_bridge`, `rv32i_cpu` <-> `data_bus_decode`, `soc_top`). These make zero assumptions about internal RTL signal names beyond frozen contract ports.
   - **Part B — Internal Implementation Properties (White-Box / Module Internals):** Bound to internal architectural contracts (`rv32i_cpu` `PC`/`RF`/`rf_we`, `apb3_bridge` `IDLE/SETUP/ACCESS` FSM, `data_bus_decode` `local_rd_valid`, `rst_sync` 2-FF stages).
4. **Verilator 5.032 Simulation Note:**
   - The local environment runs `Verilator 5.032`. Properties below are written in standard IEEE 1800-2017 SVA using bounded single-cycle / `|=>` / `|->` / `throughout` / `$past` / auxiliary shadow registers so they can be compiled cleanly under Verilator `--assert` (or converted to equivalent clocked immediate assertions in a bind checker if any specific `throughout` sequence triggers a Verilator SVA limitation, without changing temporal semantics).
5. **Blocked Scope:**
   - Peripheral functional register assertions (`uart_apb` TX/RX framing/baud, `gpio_apb` register-to-pin mapping, `timer_apb` counter/compare match) are **`BLOCKED (awaiting approved peripheral register-map contract)`** (Section 6).

---

## 2. Part A — Interface Protocol Properties

### 2.1 APB3 Bus Interface Assertions (`ARM IHI 0024E` Issue B & `CON-APB3-001`)

- **Clock & Reset:** `@(posedge PCLK)`, `disable iff (!PRESETn)` (except `SVA-APB-001`).
- **Convenience Definitions:**
  - `let psel_vec = {PSEL_TIMER, PSEL_GPIO, PSEL_UART};`
  - `let psel_any = |psel_vec;`
  - `let apb_setup = psel_any && !PENABLE;`
  - `let apb_access = psel_any && PENABLE;`
  - `let apb_xfer_done = apb_access && PREADY;`

| SVA ID | Rule / Contract Source | Formal Intent & SystemVerilog Property |
|---|---|---|
| `SVA-APB-001` | `CON-APB3-001 §4.2.1` | **APB3 Reset Outputs:** While `!PRESETn`, all Requester control outputs are quiescent (`IDLE`).<br>`property p_apb_reset_idle; @(posedge PCLK) !PRESETn |-> (!psel_any && !PENABLE && !PWRITE && PADDR == 32'h0 && PWDATA == 32'h0); endproperty` |
| `SVA-APB-002` | `CON-APB3-001 §4.2.2` | **One-Hot `PSELx`:** At most one `PSELx` line is asserted in any cycle.<br>`property p_apb_psel_onehot0; @(posedge PCLK) disable iff (!PRESETn) $onehot0(psel_vec); endproperty` |
| `SVA-APB-003` | `CON-ADDR-001 §3`, `CON-APB3-001 §3.2` | **`PSELx` Address Match & Alignment:** Whenever a `PSELx` is asserted, `PADDR` falls inside that Completer's 4 KB subrange and is 4-byte aligned (`Option APB-W1`).<br>`property p_apb_addr_decode; @(posedge PCLK) disable iff (!PRESETn)`<br>`  (PSEL_UART  |-> (PADDR[31:12] == 20'h4000_0 && PADDR[1:0] == 2'b00)) and`<br>`  (PSEL_GPIO  |-> (PADDR[31:12] == 20'h4000_1 && PADDR[1:0] == 2'b00)) and`<br>`  (PSEL_TIMER |-> (PADDR[31:12] == 20'h4000_2 && PADDR[1:0] == 2'b00)); endproperty` |
| `SVA-APB-004` | `IHI0024E §4.1`, `CON-APB3-001 §4.2` | **No `PENABLE` Without `PSELx`:** `PENABLE` must never be HIGH when all `PSELx` are LOW.<br>`property p_apb_penable_implies_psel; @(posedge PCLK) disable iff (!PRESETn) PENABLE |-> psel_any; endproperty` |
| `SVA-APB-005` | `IHI0024E §4.1`, `CON-APB3-001 §4.2.3` | **Single-Cycle `SETUP` -> `ACCESS`:** Every `SETUP` cycle (`psel_any && !PENABLE`) transitions unconditionally on the next `PCLK` edge to `ACCESS` (`PENABLE == 1`) for the **same** selected Completer.<br>`property p_apb_setup_to_access; @(posedge PCLK) disable iff (!PRESETn) apb_setup |=> (apb_access && psel_vec == $past(psel_vec)); endproperty` |
| `SVA-APB-006` | `IHI0024E §3.1.2, §3.3.2, §4.1`, `CON-APB3-001 §4.2.4` | **Signal Stability Across `SETUP -> ACCESS` and `PREADY=0` Wait States:** When in `SETUP` OR when in `ACCESS && !PREADY`, `PADDR`, `PWRITE`, `psel_vec`, and (if `PWRITE`) `PWDATA` must remain identical on the next cycle.<br>`property p_apb_hold_stable; @(posedge PCLK) disable iff (!PRESETn)`<br>`  (apb_setup || (apb_access && !PREADY)) |=>`<br>`  ($stable(PADDR) && $stable(PWRITE) && $stable(psel_vec) && (!PWRITE || $stable(PWDATA))); endproperty` |
| `SVA-APB-007` | `IHI0024E §4.1`, `CON-APB3-001 §4.2.5` | **No Restart of `SETUP` During Wait:** While `apb_access && !PREADY`, `PENABLE` must stay HIGH on the next cycle.<br>`property p_apb_wait_keeps_penable; @(posedge PCLK) disable iff (!PRESETn) (apb_access && !PREADY) |=> PENABLE; endproperty` |
| `SVA-APB-008` | `CON-APB3-001 §4.1` (Design 4A) | **Completion Exits to `IDLE`:** When `apb_access && PREADY`, Design 4A transitions `ACCESS -> IDLE` (`!psel_any && !PENABLE`) on the next cycle (guaranteeing at least 1 `IDLE` cycle where CPU updates `PC` before any next APB instruction).<br>`property p_apb_done_to_idle; @(posedge PCLK) disable iff (!PRESETn) apb_xfer_done |=> (!psel_any && !PENABLE); endproperty` |
| `SVA-APB-009` | `CON-APB3-001 §2, §3.1` | **Bridge Request-to-APB Consistency:** No `PSELx` can rise from `IDLE` unless `apb_req_valid` was HIGH in `IDLE`; while `apb_req_valid` is held across an APB transfer, `apb_req_write`, `apb_req_addr`, `apb_req_wdata` match `PWRITE`, `PADDR`, `PWDATA`.<br>`property p_apb_req_handshake; @(posedge PCLK) disable iff (!PRESETn)`<br>`  (!psel_any && $past(!psel_any) && !apb_req_valid) |-> !psel_any; endproperty`<br>`property p_apb_req_match; @(posedge PCLK) disable iff (!PRESETn)`<br>`  apb_setup |-> (PADDR == $past(apb_req_addr) && PWRITE == $past(apb_req_write) && (!PWRITE || PWDATA == $past(apb_req_wdata))); endproperty` |
| `SVA-APB-010` | `IHI0024E §3.4`, `CON-APB3-001 §4.2.6` | **`PSLVERR` Ignored Outside `ACCESS && PREADY`:** `apb_rsp_ready` asserts iff `apb_xfer_done`, and `dmem_fault_valid` (for `FAULT_APB_SLVERR`) never triggers during `SETUP` or `ACCESS && !PREADY`.<br>`property p_apb_rsp_ready_exact; @(posedge PCLK) disable iff (!PRESETn) apb_rsp_ready == apb_xfer_done; endproperty`<br>`property p_apb_no_early_slverr; @(posedge PCLK) disable iff (!PRESETn) (apb_setup || (apb_access && !PREADY)) |-> (!apb_rsp_ready && !(dmem_fault_valid && dmem_fault_code == 4'h9)); endproperty` |

### 2.2 Local Memory & Modified Harvard Interface Assertions (`CON-MEM-001`, `CON-ADDR-001`)

- **Clock & Reset:** `@(posedge clk)`, `disable iff (!sys_rst_n)` (except reset checks).

| SVA ID | Rule / Contract Source | Formal Intent & SystemVerilog Property |
|---|---|---|
| `SVA-MEM-001` | `CON-MEM-001 §1.2, §1.3` | **`irom_local` Port A Gating & Range:** Whenever `irom_en` is HIGH, `irom_addr[1:0] == 2'b00` and `!fault_valid`; whenever `!irom_en`, `irom_rdata == 32'h0`.<br>`property p_irom_porta_en_valid; @(posedge clk) disable iff (!sys_rst_n) irom_en |-> (irom_addr[1:0] == 2'b00 && !fault_valid); endproperty`<br>`property p_irom_porta_zero_when_dis; @(posedge clk) !irom_en |-> (irom_rdata == 32'h0); endproperty` |
| `SVA-MEM-002` | `CON-MEM-001 §1.2, §1.4` | **`irom_local` Port B 1-Cycle Strobe (`C0` only):** `irom_dreq` is never asserted for 2 consecutive cycles (single-cycle pulse in `C0`; `0` in `C1`).<br>`property p_irom_portb_single_pulse; @(posedge clk) disable iff (!sys_rst_n) irom_dreq |=> !irom_dreq; endproperty` |
| `SVA-MEM-003` | `CON-MEM-001 §1.4` | **`irom_local` Port B Registered Output:** `irom_drdata` changes only after `irom_dreq` was HIGH in the prior cycle (`!irom_dreq` holds `irom_drdata` stable during `C1`).<br>`property p_irom_portb_hold; @(posedge clk) disable iff (!sys_rst_n) !$past(irom_dreq) |-> $stable(irom_drdata); endproperty` |
| `SVA-MEM-004` | `CON-ADDR-001 §4.2`, `CON-FLT-RST-001` | **No Writes to `IROM`:** `irom_local` has no write port, and `dram_req` / `apb_req_valid` must be `0` whenever `dmem_addr[31:15] == 17'h0000_0` and `dmem_req`.<br>`property p_no_write_path_on_irom; @(posedge clk) disable iff (!sys_rst_n) (dmem_req && dmem_addr[31:15] == 17'h0000_0 && dmem_we) |-> (!irom_dreq && !dram_req && !apb_req_valid); endproperty` |
| `SVA-MEM-005` | `CON-MEM-001 §2.2` | **`dram_local` Byte Enable & Request Rules:** On reads (`dram_req && !dram_we`), `dram_be == 4'b0000`; on writes (`dram_req && dram_we`), `dram_be` matches `SB/SH/SW` little-endian encoding and is non-zero; never asserted during `fault_valid`.<br>`property p_dram_be_on_read; @(posedge clk) disable iff (!sys_rst_n) (dram_req && !dram_we) |-> (dram_be == 4'b0000); endproperty`<br>`property p_dram_be_on_write; @(posedge clk) disable iff (!sys_rst_n) (dram_req && dram_we) |-> (dram_be inside {4'b0001,4'b0010,4'b0100,4'b1000,4'b0011,4'b1100,4'b1111}); endproperty`<br>`property p_dram_req_no_fault; @(posedge clk) disable iff (!sys_rst_n) dram_req |-> !fault_valid; endproperty` |
| `SVA-MEM-006` | `CON-MEM-001 §2.3` | **`dram_local` Read 1-Cycle Strobe (`C0` only):** A `dram_local` read (`dram_req && !dram_we`) is never active for 2 consecutive cycles (`C1` gates `dram_req` LOW via `!local_rd_valid`).<br>`property p_dram_rd_single_pulse; @(posedge clk) disable iff (!sys_rst_n) (dram_req && !dram_we) |=> !(dram_req && !dram_we); endproperty` |
| `SVA-MEM-007` | `CON-MEM-001 §2.3` | **`dram_local` Read Output Stability:** `dram_rdata` remains stable when `!$past(dram_req && !dram_we)` (holds during `C1` and idle cycles).<br>`property p_dram_rdata_hold; @(posedge clk) disable iff (!sys_rst_n) !$past(dram_req && !dram_we) |-> $stable(dram_rdata); endproperty` |
| `SVA-MEM-008` | `CON-MEM-001 §1.4, §2.3` | **Mutual Exclusion of Local & APB Requests:** At most one of `{irom_dreq, dram_req, apb_req_valid}` may be HIGH in any cycle.<br>`property p_dmem_targets_mutex; @(posedge clk) disable iff (!sys_rst_n) $onehot0({irom_dreq, dram_req, apb_req_valid}); endproperty` |
| `SVA-MEM-009` | `CON-MEM-001 §2.6` | **Reset Gating of Memory Requests:** When `!sys_rst_n`, `irom_en`, `irom_dreq`, `dram_req`, and `apb_req_valid` are all `0`, and `irom_drdata == 32'h0`, `dram_rdata == 32'h0`.<br>`property p_mem_reset_quiescent; @(posedge clk) !sys_rst_n |-> (!irom_en && !irom_dreq && !dram_req && !apb_req_valid && irom_drdata == 32'h0 && dram_rdata == 32'h0); endproperty` |

### 2.3 CPU <-> Data Bus Decoder Interface Assertions (`CON-TOP-001 §4`, `CON-ADDR-001 §4.2`, `CON-APB3-001 §3.1`)

| SVA ID | Rule / Contract Source | Formal Intent & SystemVerilog Property |
|---|---|---|
| `SVA-DEC-001` | `CON-ADDR-001 §4.2`, `CON-FLT-RST-001 §1.4` | **Pre-Check Fault Suppresses All Memory/APB Requests:** Whenever `dmem_fault_valid` is asserted in `C0` (any fault other than `FAULT_APB_SLVERR`), `irom_dreq`, `dram_req`, and `apb_req_valid` must all be `0` in that cycle.<br>`property p_fault_suppresses_reqs; @(posedge clk) disable iff (!sys_rst_n) (dmem_fault_valid && dmem_fault_code != 4'h9) |-> (!irom_dreq && !dram_req && !apb_req_valid); endproperty` |
| `SVA-DEC-002` | `CON-APB3-001 §2` | **APB3 Sub-Word / Unaligned Rejection:** When `dmem_req` targets `0x4000_0000..0x4000_2FFF` with `dmem_size != 2'b10` or `dmem_addr[1:0] != 2'b00`, `apb_req_valid` must be `0` and `dmem_fault_valid` must be `1`.<br>`property p_apb_w1_reject; @(posedge clk) disable iff (!sys_rst_n) (dmem_req && dmem_addr[31:12] inside {20'h4000_0, 20'h4000_1, 20'h4000_2} && (dmem_size != 2'b10 || dmem_addr[1:0] != 2'b00)) |-> (!apb_req_valid && dmem_fault_valid); endproperty` |
| `SVA-DEC-003` | `CON-APB3-001 §3.1` | **Stall Stability on CPU Data Interface:** While `dmem_stall` is HIGH, CPU holds `dmem_req`, `dmem_we`, `dmem_size`, `dmem_addr`, and `dmem_wdata` stable into the next cycle (unless reset or fault occurs).<br>`property p_cpu_dmem_hold_on_stall; @(posedge clk) disable iff (!sys_rst_n) (dmem_stall && !fault_valid) |=> ($stable(dmem_req) && $stable(dmem_we) && $stable(dmem_size) && $stable(dmem_addr) && $stable(dmem_wdata)); endproperty` |

---

## 3. Part B — Internal Microarchitecture Properties

### 3.1 CPU Stall, Hold, Exactly-Once Commit & `FENCE` (`rv32i_cpu`)

| SVA ID | Rule / Contract Source | Formal Intent & SystemVerilog Property |
|---|---|---|
| `SVA-CPU-001` | `SOC_SPEC §3`, `CON-FLT-RST-001 §2.2` | **`x0` Immutability:** Register `rf[0]` is always `32'h0000_0000` on every clock cycle.<br>`property p_cpu_x0_zero; @(posedge clk) (rf[0] == 32'h0000_0000); endproperty` |
| `SVA-CPU-002` | `CON-FLT-RST-001 §2.2` | **Reset Values (`PC` and `x1..x31`):** When `!sys_rst_n`, `pc == 32'h0000_0000` and all `rf[1..31] == 32'h0000_0000`.<br>`property p_cpu_reset_state; @(posedge clk) !sys_rst_n |-> (pc == 32'h0000_0000 && (foreach_rf_zero)); endproperty` *(Checker loops `i = 1..31`)* |
| `SVA-CPU-003` | `DEC-CPU-APB-WAIT-001`, `CON-APB3-001 §5.2.1` | **`PC` Frozen During `dmem_stall`:** If `dmem_stall` is HIGH and `!fault_valid`, `pc` on the next `posedge clk` equals `pc` in the current cycle.<br>`property p_cpu_pc_hold_on_stall; @(posedge clk) disable iff (!sys_rst_n) (dmem_stall && !fault_valid) |=> $stable(pc); endproperty` |
| `SVA-CPU-004` | `CON-APB3-001 §5.2.2` | **No Premature or Faulted `RF` Writeback:** `rf_we` is strictly `0` whenever `dmem_stall` is HIGH or `fault_detect` is HIGH or `fault_valid` is HIGH.<br>`property p_cpu_rf_we_gated; @(posedge clk) disable iff (!sys_rst_n) rf_we |-> (!dmem_stall && !fault_detect && !fault_valid); endproperty` |
| `SVA-CPU-005` | `CON-APB3-001 §5.2.3`, `DEC-CPU-APB-WAIT-001` | **Exactly-Once Completion per Stalled Load/Store:** When `dmem_stall` drops (`$fell(dmem_stall)`) without a fault (`!fault_detect && !fault_valid`), `pc` advances (`pc` changes to `pc+4`) on the next clock edge and `dmem_stall` is not still stuck on the same instruction.<br>`property p_cpu_commit_on_stall_release; @(posedge clk) disable iff (!sys_rst_n) ($past(dmem_stall) && !dmem_stall && !fault_detect && !fault_valid) |=> (pc == $past(pc) + 32'd4); endproperty` |
| `SVA-CPU-006` | `DEC-ARCH-CORE-002 #3` | **`FENCE` Single-Cycle NOP After Memory Completion:** When `!fault_valid && !if_fault && insn[6:0] == 7'b0001111 && insn[14:12] == 3'b000` (`FENCE`), no `dmem_req`, `dmem_stall`, `rf_we`, or `fault_detect` occurs, and `pc` advances by `4` in 1 cycle (`C0 -> C1`).<br>`property p_cpu_fence_nop; @(posedge clk) disable iff (!sys_rst_n) (!fault_valid && !if_fault && insn[6:0] == 7'b0001111 && insn[14:12] == 3'b000) |-> (!dmem_req && !dmem_stall && !rf_we && !fault_detect) and |=> (pc == $past(pc) + 32'd4); endproperty` |

### 3.2 `data_bus_decode` & `apb3_bridge` Internals

| SVA ID | Rule / Contract Source | Formal Intent & SystemVerilog Property |
|---|---|---|
| `SVA-INT-001` | `CON-MEM-001 §2.3` | **`local_rd_valid` Handshake:** `local_rd_valid` resets to `0`, asserts for exactly 1 cycle (`C1`) immediately following a valid local read issue (`irom_dreq || (dram_req && !dram_we)`), and clears on `C2`.<br>`property p_local_rd_valid_pulse; @(posedge clk) disable iff (!sys_rst_n) local_rd_valid |=> !local_rd_valid; endproperty`<br>`property p_local_rd_valid_cause; @(posedge clk) disable iff (!sys_rst_n) (irom_dreq || (dram_req && !dram_we)) |=> local_rd_valid; endproperty` |
| `SVA-INT-002` | `CON-APB3-001 §4.1` | **`apb3_bridge` FSM Legal States & Transitions:** Bridge `state` takes only `{IDLE, SETUP, ACCESS}`; `IDLE -> SETUP` only on `apb_req_valid`; `SETUP -> ACCESS` unconditionally; `ACCESS -> ACCESS` if `!PREADY_mux`; `ACCESS -> IDLE` if `PREADY_mux`.<br>`property p_bridge_fsm_legal; @(posedge clk) disable iff (!sys_rst_n) (state inside {ST_IDLE, ST_SETUP, ST_ACCESS}); endproperty`<br>`property p_bridge_setup_to_access; @(posedge clk) disable iff (!sys_rst_n) (state == ST_SETUP) |=> (state == ST_ACCESS); endproperty` |

### 3.3 Fault-and-Halt & Reset Synchronizer Properties (`CON-FLT-RST-001`)

| SVA ID | Rule / Contract Source | Formal Intent & SystemVerilog Property |
|---|---|---|
| `SVA-FLT-001` | `CON-FLT-RST-001 §1.1, §1.3` | **Valid Fault Code Encoding:** `fault_code_o` is always `4'h0` when `!fault_o`, and in `4'h1..4'hA` (never `4'hB..4'hF` or `4'h0`) when `fault_o`.<br>`property p_fault_code_valid; @(posedge clk) disable iff (!sys_rst_n) (!fault_o -> fault_code_o == 4'h0) && (fault_o -> (fault_code_o inside {[4'h1:4'hA]})); endproperty` |
| `SVA-FLT-002` | `CON-FLT-RST-001 §1.1` | **Fault Context Format Rules:** For IF faults (`4'h1, 4'h2`), `fault_insn_o == 32'h0` and `fault_addr_o == fault_pc_o`; for decode faults (`4'h3, 4'h4, 4'h5`), `fault_addr_o == 32'h0`.<br>`property p_fault_context_fmt; @(posedge clk) disable iff (!sys_rst_n)`<br>`  (fault_o && fault_code_o inside {4'h1, 4'h2}) |-> (fault_insn_o == 32'h0 && fault_addr_o == fault_pc_o) and`<br>`  (fault_o && fault_code_o inside {4'h3, 4'h4, 4'h5}) |-> (fault_addr_o == 32'h0); endproperty` |
| `SVA-FLT-003` | `CON-FLT-RST-001 §1.4` | **Sticky Fault Capture (First Fault Wins):** Once `fault_o == 1`, `fault_o`, `fault_code_o`, `fault_pc_o`, `fault_addr_o`, and `fault_insn_o` remain constant until `sys_rst_n == 0`.<br>`property p_fault_sticky; @(posedge clk) disable iff (!sys_rst_n) fault_o |=> (fault_o && $stable(fault_code_o) && $stable(fault_pc_o) && $stable(fault_addr_o) && $stable(fault_insn_o)); endproperty` |
| `SVA-FLT-004` | `CON-FLT-RST-001 §1.4` | **Halt Quiescence (Zero Mutation While Halted):** While `fault_o == 1`, `PC` stays frozen at `fault_pc_o`, `rf_we == 0`, `irom_en == 0`, `irom_dreq == 0`, `dram_req == 0`, `apb_req_valid == 0`, and `apb3_bridge` is in `IDLE`.<br>`property p_halt_quiescent; @(posedge clk) disable iff (!sys_rst_n) fault_o |-> (pc == fault_pc_o && !rf_we && !irom_en && !irom_dreq && !dram_req && !apb_req_valid && !psel_any && !PENABLE); endproperty` |
| `SVA-FLT-005` | `CON-FLT-RST-001 §1.4` | **Zero Mutation on Faulting Edge:** On the cycle a fault is detected (`!fault_valid && fault_detect`), `rf_we == 0`, `dram_req == 0`, `irom_dreq == 0`, `apb_req_valid == 0` (except `FAULT_APB_SLVERR` which finishes the current APB transfer and transitions `ACCESS -> IDLE`).<br>`property p_fault_edge_no_commit; @(posedge clk) disable iff (!sys_rst_n) (!fault_valid && fault_detect) |-> (!rf_we && !dram_req && !irom_dreq); endproperty` |
| `SVA-FLT-006` | `CON-FLT-RST-001 §1.2` | **Fault Priority Enforcement:** Verify higher-priority conditions always win (e.g., if `!if_in_irom` and `pc[1:0]!=0`, `fault_code` on detect is `4'h2` not `4'h1`; if `data_in_irom && dmem_we` and misaligned, `fault_code` is `4'hA` not `4'h6`).<br>`property p_fault_prio_if; @(posedge clk) disable iff (!sys_rst_n) (!fault_valid && (pc[31:15] != 17'h0000_0) && (pc[1:0] != 2'b00)) |=> (fault_o && fault_code_o == 4'h2); endproperty`<br>`property p_fault_prio_ro_over_align; @(posedge clk) disable iff (!sys_rst_n) (!fault_valid && !if_fault && dmem_req && dmem_we && (dmem_addr[31:15] == 17'h0000_0) && (dmem_addr[1:0] != 2'b00)) |=> (fault_o && fault_code_o == 4'hA); endproperty` |
| `SVA-FLT-007` | `CON-FLT-RST-001 §1.2` | **APB Priority (`SIZE_UNSUP` > `MISALIGNED`):** Sub-word unaligned access to populated APB slot latches `4'h8` (`FAULT_DATA_SIZE_UNSUP`), not `4'h6`.<br>`property p_fault_prio_apb_size; @(posedge clk) disable iff (!sys_rst_n) (!fault_valid && !if_fault && dmem_req && (dmem_addr[31:12] inside {20'h4000_0,20'h4000_1,20'h4000_2}) && dmem_size != 2'b10 && dmem_addr[1:0] != 2'b00) |=> (fault_o && fault_code_o == 4'h8); endproperty` |
| `SVA-RST-001` | `CON-FLT-RST-001 §2.1` | **Async Assert of `sys_rst_n`:** Whenever external `rst_n == 0`, internal `sync_ff1`, `sync_ff2`, `sys_rst_n`, and `PRESETn` must be `0` immediately (checked continuously / on edge and every clk).<br>`property p_rst_async_assert; @(posedge clk) !rst_n |-> (!sync_ff1 && !sync_ff2 && !sys_rst_n && !PRESETn); endproperty` |
| `SVA-RST-002` | `CON-FLT-RST-001 §2.1` | **2-FF Sync Deassert of `sys_rst_n`:** After `rst_n` rises (`0 -> 1`), `sys_rst_n` remains `0` for at least 1 `posedge clk` (`sync_ff1` captures `1`, `sync_ff2` still `0`) and releases to `1` on the second `posedge clk` while `rst_n == 1`.<br>`property p_rst_sync_release; @(posedge clk) ($rose(rst_n) && !sync_ff2) ##1 rst_n |-> (!sys_rst_n ##1 (rst_n -> sys_rst_n)); endproperty` |
| `SVA-RST-003` | `CON-FLT-RST-001 §2.2` | **Reset Clears Fault Outputs:** When `!sys_rst_n`, `fault_o == 0`, `fault_code_o == 4'h0`, `fault_pc_o == 32'h0`, `fault_addr_o == 32'h0`, `fault_insn_o == 32'h0`.<br>`property p_rst_clears_fault; @(posedge clk) !sys_rst_n |-> (!fault_o && fault_code_o == 4'h0 && fault_pc_o == 32'h0 && fault_addr_o == 32'h0 && fault_insn_o == 32'h0); endproperty` |
| `SVA-RST-004` | `CON-FLT-RST-001 §2.2` | **Reset Clears `local_rd_valid`:** When `!sys_rst_n`, `local_rd_valid == 0`.<br>`property p_rst_clears_local_rd; @(posedge clk) !sys_rst_n |-> !local_rd_valid; endproperty` |
| `SVA-RST-005` | `CON-FLT-RST-001 §2.2`, `CON-TOP-001 §3` | **Top-Level Peripheral Pin Reset State:** When `!sys_rst_n`, `uart_tx_o == 1'b1`, `gpio_oe_o == 8'h00`, `gpio_o == 8'h00`.<br>`property p_rst_top_pins; @(posedge clk) !sys_rst_n |-> (uart_tx_o == 1'b1 && gpio_oe_o == 8'h00 && gpio_o == 8'h00); endproperty` |
| `SVA-RST-006` | `CON-FLT-RST-001 §1.4` | **Reset-Only Fault Recovery:** `fault_o` can only fall (`1 -> 0`) when `!sys_rst_n`.<br>`property p_fault_fall_only_on_reset; @(posedge clk) $fell(fault_o) |-> !sys_rst_n; endproperty` |

---

## 4. Functional `cover property` Milestones

| Cover ID | Scenario Description | Cover Expression (`@(posedge clk)`) |
|---|---|---|
| `COV-SVA-001` | APB3 0-wait write (`SW`) | `disable iff (!PRESETn) (apb_setup && PWRITE) ##1 (apb_access && PREADY)` |
| `COV-SVA-002` | APB3 0-wait read (`LW`) | `disable iff (!PRESETn) (apb_setup && !PWRITE) ##1 (apb_access && PREADY)` |
| `COV-SVA-003` | APB3 multi-wait transfer (`>= 2` wait cycles) | `disable iff (!PRESETn) apb_setup ##1 (apb_access && !PREADY)[*2:$] ##1 (apb_access && PREADY)` |
| `COV-SVA-004` | APB3 `PSLVERR` asserted while `PREADY == 0` then `PSLVERR == 0` at `PREADY == 1` (must not fault) | `disable iff (!PRESETn) (apb_access && !PREADY && PSLVERR) ##[1:8] (apb_access && PREADY && !PSLVERR)` |
| `COV-SVA-005` | APB3 `PSLVERR == 1` at `PREADY == 1` (`FAULT_APB_SLVERR`) | `disable iff (!PRESETn) (apb_access && PREADY && PSLVERR)` |
| `COV-SVA-006` | `IROM` Port B 2-cycle `.rodata` load (`C0 -> C1`) | `disable iff (!sys_rst_n) (irom_dreq && dmem_stall) ##1 (!irom_dreq && local_rd_valid && !dmem_stall)` |
| `COV-SVA-007` | `DRAM` 2-cycle load followed immediately by 1-cycle `DRAM` store | `disable iff (!sys_rst_n) (dram_req && !dram_we) ##1 (local_rd_valid) ##1 (dram_req && dram_we)` |
| `COV-SVA-008` | `FENCE` executed immediately after APB3 completion | `disable iff (!sys_rst_n) (apb_xfer_done) ##2 (!fault_valid && insn[6:0] == 7'b0001111 && insn[14:12] == 3'b000)` |
| `COV-SVA-009` | Reset asserted during `apb_access && !PREADY` stall | `($past(apb_access && !PREADY) && !sys_rst_n)` |
| `COV-SVA-010` | Reset asserted while `fault_o == 1` followed by release (`fault_o == 0`) | `(fault_o) ##[1:4] (!sys_rst_n) ##[2:4] (sys_rst_n && !fault_o)` |

---

## 5. `BLOCKED` Peripheral Register-Level SVA Properties

| Blocked SVA Group | Target Module | Description | Status |
|---|---|---|---|
| `SVA-UART-001..N` | `uart_apb` | Register RW/RO permissions, TX start/busy/shift-register 8N1 frame timing, baud divider accuracy, RX start/stop validation, RX overrun/valid flags, and peripheral `PSLVERR` decode | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `SVA-GPIO-001..N` | `gpio_apb` | Register offsets for `DATA_IN`/`DATA_OUT`/`DIR`, `gpio_oe_o` & `gpio_o` update timing, `gpio_i` synchronizer staging, and peripheral `PSLVERR` decode | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `SVA-TIMER-001..N` | `timer_apb` | Register offsets for `CTRL`/`COUNT`/`COMPARE`/`STATUS`, 32-bit counter increment/wrap, compare match sticky/W1C clear timing, and peripheral `PSLVERR` decode | `BLOCKED (awaiting approved peripheral register-map contract)` |
