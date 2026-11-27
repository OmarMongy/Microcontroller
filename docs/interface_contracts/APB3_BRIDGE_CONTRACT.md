# APB3 Bridge & CPU Stall/Commit Contract

- **Contract ID:** `CON-APB3-001`
- **Version:** `v1.1`
- **Status:** `APPROVED (DEC-ARCH-CORE-001)`
- **Date:** 2026-11-27
- **Parent Proposal:** [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md)
- **Approved Decision:** [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) (Decisions #4 & #5)
- **Protocol Reference:** `AMBA® APB Protocol Specification` (ARM IHI 0024E / ID022823, Issue E — **APB3 / Issue B / v1.0** subset ONLY: Chapters 2–4, Appendix A, Appendix B Table B-1).

---

## 1. Strict APB3 Signal Subset (No APB4/APB5 Signals)

Per ARM `IHI0024E` Appendix B Table B-1 (APB3 column):
- **Included (Mandatory / APB3 Optional-Output):** `PCLK`, `PRESETn`, `PADDR`, `PSELx` (`PSEL_UART`, `PSEL_GPIO`, `PSEL_TIMER`), `PENABLE`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`, `PSLVERR`.
- **Strictly Excluded (APB4 / APB5 — Must NOT be present):** `PPROT`, `PSTRB`, `PNSE`, `PWAKEUP`, `PAUSER`, `PWUSER`, `PRUSER`, `PBUSER`, and all `*CHK` parity signals.

---

## 2. Sub-Word & Unaligned Access Policy on APB3 (`APPROVED — DEC-ARCH-CORE-001`)

Because APB3 (`Issue B`) has **no `PSTRB` byte-write strobe**, every APB3 write drives a full 32-bit `PWDATA` word and every APB3 read returns a full 32-bit `PRDATA` word.

### Approved Policy (`Option APB-W1`): Strict 32-Bit Aligned `LW`/`SW` Only
1. **Valid APB3 Operations:** Only `LW` and `SW` with `addr[1:0] == 2'b00` targeting a populated APB3 slot (`0x4000_0000`–`0x4000_2FFF`) are accepted by the APB3 bridge.
2. **Sub-Word Rejection:** Any `LB`, `LBU`, `LH`, `LHU`, `SB`, or `SH` targeting the APB3 window is blocked **before** `apb_req_valid` is asserted and raises `FAULT_DATA_SIZE_UNSUP`.
3. **Unaligned Word Rejection:** Any `LW` or `SW` targeting the APB3 window with `addr[1:0] != 2'b00` is blocked **before** `apb_req_valid` is asserted and raises `FAULT_DATA_MISALIGNED`.
4. **No Spurious Bus Activity:** Neither sub-word nor unaligned accesses ever initiate an APB3 `SETUP` phase.

---

## 3. Interface Signals

### 3.1 `data_bus_decode` <-> `apb3_bridge` Internal Handshake (`APPROVED — DEC-ARCH-CORE-001`)

| Signal | Width | Direction (wrt `apb3_bridge`) | Polarity / Timing | Description |
|---|---:|---|---|---|
| `clk` | 1 | Input | Rising-edge | Shared 50 MHz system clock (`PCLK`). |
| `sys_rst_n` | 1 | Input | Active-LOW | Synchronized system reset (`PRESETn`). |
| `apb_req_valid` | 1 | Input | Active-HIGH | Asserted when CPU decodes a valid, aligned `LW`/`SW` to a populated APB3 slot and `!fault_valid`. Held stable while `dmem_stall == 1`. |
| `apb_req_write` | 1 | Input | Active-HIGH | `1` = `SW` (write), `0` = `LW` (read). Stable while `apb_req_valid == 1`. |
| `apb_req_addr` | 32 | Input | Byte address | Full 32-bit target address (`apb_req_addr[1:0] == 2'b00`). Stable while `apb_req_valid == 1`. |
| `apb_req_wdata` | 32 | Input | Write word | `rs2` value for `SW`. Stable while `apb_req_valid == 1`. |
| `apb_rsp_ready` | 1 | Output | Active-HIGH | Combinational completion pulse (`1` only in `ACCESS && PREADY_mux`). Causes `apb_stall` to deassert for the upcoming `posedge clk`. |
| `apb_rsp_rdata` | 32 | Output | Read word | Equals `PRDATA_mux`. Valid when `apb_rsp_ready && !apb_req_write && !apb_rsp_err`. |
| `apb_rsp_err` | 1 | Output | Active-HIGH | Equals `PSLVERR_mux`. Valid **only** when `apb_rsp_ready == 1`. |

- **APB Stall & Unified CPU Stall Equation:**
  - `apb_stall = apb_req_valid && !apb_rsp_ready`
  - At `data_bus_decode`, `dmem_stall = (local_read_stall || apb_stall) && !fault_valid`, where `local_read_stall` handles the 1-cycle synchronous read wait state for `dram_local` and `irom_local` Port B (see `CON-MEM-001`). `apb_req_valid` and `local_read_stall` are mutually exclusive because `IROM`, `DRAM`, and `APB3` address regions do not overlap.

### 3.2 APB3 Bus Interface (`apb3_bridge` <-> Peripheral Completers)

| Signal | Width | Source | Width / Polarity | APB3 Rule (`IHI0024E`) |
|---|---:|---|---|---|
| `PCLK` | 1 | System Clock | Rising-edge | Connected to `clk` (50 MHz). |
| `PRESETn` | 1 | Reset Sync | Active-LOW | Connected to `sys_rst_n`. |
| `PADDR` | 32 | `apb3_bridge` | Registered | Full 32-bit byte address (`PADDR[1:0] == 2'b00`); peripherals decode `PADDR[11:0]`. |
| `PSEL_UART` | 1 | `apb3_bridge` | Registered, active-HIGH | Asserted (`1`) in `SETUP` & `ACCESS` for `0x4000_0000`–`0x4000_0FFF`. |
| `PSEL_GPIO` | 1 | `apb3_bridge` | Registered, active-HIGH | Asserted (`1`) in `SETUP` & `ACCESS` for `0x4000_1000`–`0x4000_1FFF`. |
| `PSEL_TIMER` | 1 | `apb3_bridge` | Registered, active-HIGH | Asserted (`1`) in `SETUP` & `ACCESS` for `0x4000_2000`–`0x4000_2FFF`. |
| `PENABLE` | 1 | `apb3_bridge` | Registered, active-HIGH | `0` in `IDLE` and `SETUP`; `1` in `ACCESS`. |
| `PWRITE` | 1 | `apb3_bridge` | Registered | `1` = APB write, `0` = APB read. |
| `PWDATA` | 32 | `apb3_bridge` | Registered | Driven during `SETUP` and `ACCESS` when `PWRITE == 1` (driven to `32'h0` when idle/read). |
| `PREADY` | 1 | Selected Completer | Active-HIGH (muxed) | `PREADY_mux` from the Completer whose `PSELx == 1`. Default `1'b1` if peripheral has 0 wait states. |
| `PRDATA` | 32 | Selected Completer | Read data (muxed) | `PRDATA_mux` from selected Completer; sampled when `PSELx && PENABLE && PREADY && !PWRITE`. |
| `PSLVERR` | 1 | Selected Completer | Active-HIGH (muxed) | `PSLVERR_mux` from selected Completer; sampled **only** when `PSELx && PENABLE && PREADY`. Default `1'b0` if unused. |

---

## 4. APB3 Bridge FSM & Stability Rules (`Design 4A — APPROVED`)

### 4.1 State Encoding & Transitions

```text
          !apb_req_valid
          +-----------+
          |           |
          v           |
     +--------+       |
     |  IDLE  |-------+
     |PSELx=0 |
     |PENABLE=0
     +----+---+
          | apb_req_valid == 1
          v
     +--------+
     | SETUP  |  (Exactly 1 clock cycle; latches PADDR, PWRITE, PWDATA, one-hot PSELx)
     |PSELx=1 |
     |PENABLE=0
     +----+---+
          | Unconditional on next posedge PCLK
          v
     +--------+
     | ACCESS |<--+
     |PSELx=1 |   | PREADY_mux == 0 (wait state: hold all signals stable)
     |PENABLE=1---+
     +----+---+
          | PREADY_mux == 1 (transfer completes; apb_rsp_ready = 1)
          +-----------------> IDLE (CPU advances PC or halts on PSLVERR)
```

### 4.2 Exact Protocol Rules (`IHI0024E` Chapters 3 & 4)
1. **Reset State (`PRESETn == 0`):** FSM enters `IDLE`; `PSEL_UART = PSEL_GPIO = PSEL_TIMER = 0`, `PENABLE = 0`, `PWRITE = 0`, `PADDR = 32'h0`, `PWDATA = 32'h0`.
2. **One-Hot `PSELx`:** At most one of `{PSEL_UART, PSEL_GPIO, PSEL_TIMER}` may be `1` in any cycle.
3. **Single-Cycle `SETUP`:** The bridge remains in `SETUP` for **exactly one clock cycle** and always transitions to `ACCESS` on the next rising `PCLK` edge.
4. **Signal Stability (`SETUP` -> `ACCESS` and while `PREADY == 0`):** Because `PADDR`, `PWRITE`, `PWDATA`, and `PSELx` are registered on `IDLE -> SETUP` and held until `ACCESS && PREADY == 1`, they are guaranteed unchanged across `SETUP -> ACCESS` and across all `ACCESS` wait-state cycles.
5. **No Restart of `SETUP` During Wait:** While `state == ACCESS && PREADY_mux == 0`, `PENABLE` remains `1` and the bridge does NOT re-enter `SETUP`.
6. **`PSLVERR` Validity & Sampling:** `PSLVERR` is ignored in `IDLE`, `SETUP`, and `ACCESS` cycles where `PREADY_mux == 0`. It is sampled **only** when `state == ACCESS && PREADY_mux == 1`.

---

## 5. Cycle-Accurate Timing & CPU Stall/Commit Contract

### 5.1 Timing Diagram — APB Read (`LW`) with 1 Wait State (`PREADY = 0` at T3, `PREADY = 1` at T4)

```text
Cycle:          |  C0 (Decode) |  C1 (SETUP)  | C2 (ACCESS,W)| C3 (ACCESS)  | C4 (Next)
Clock Edge:     T0             T1             T2             T3             T4             T5
PC              [   PC_apb    ][   PC_apb    ][   PC_apb    ][   PC_apb    ][  PC_apb+4   ]
apb_req_valid   ______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________
FSM State       [    IDLE     ][    SETUP    ][   ACCESS    ][   ACCESS    ][    IDLE     ]
PSELx           ______________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________
PENABLE         _____________________________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________
PADDR / PWRITE  --------------<             Stable APB Request              >-------------
PREADY_mux      --------------<    don't-care ><     0      ><      1       >-------------
PRDATA_mux      ---------------------------------------------<  Read Data   >-------------
PSLVERR_mux     ---------------------------------------------<    0 (OK)    >-------------
apb_rsp_ready   _____________________________________________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________
dmem_stall      ______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________________________
CPU Commit      [hold PC & RF ][hold PC & RF ][hold PC & RF ][RF<=PRDATA,PC+4 at T4]
```

*(Note: For a 0-wait-state APB transfer where `PREADY_mux == 1` in `C2`, `apb_rsp_ready` asserts in `C2`, `dmem_stall` drops in `C2`, and the CPU commits at `T3` — 3 clock cycles total.)*

### 5.2 Exactly-Once Commit & Fault Guarantees
1. **PC & Instruction Hold:** While `dmem_stall == 1`, `PC` does not update, `irom_addr` remains at `PC_apb[14:0]`, and decoded `rs1`/`rs2`/`rd`/ALU outputs remain constant.
2. **No Premature or Duplicate Writeback:** Register File write-enable (`rf_we`) is gated by `!dmem_stall && !fault_detect`. Thus `RF[rd]` is written **only at `T4`** (for `LW` with `PSLVERR == 0`), **never** during `C0..C2`.
3. **No Duplicate Peripheral Side Effect:** The bridge latches the request once on `IDLE -> SETUP` (`T1`) and returns to `IDLE` at `T4` simultaneously with `PC <= PC + 4`, guaranteeing every `LW`/`SW` produces **exactly one** APB transfer.
4. **Behavior on `PSLVERR == 1` (at `T4`):**
   - Bridge transitions `ACCESS -> IDLE`.
   - CPU suppresses `RF[rd]` writeback (for `LW`, `PRDATA` is discarded).
   - CPU latches `FAULT_APB_SLVERR`, `fault_pc <= PC_apb`, `fault_addr <= apb_req_addr`, `fault_insn <= insn`, and enters halted state (`PC` frozen at `PC_apb`).
   - *(Note per ARM `IHI0024E` Section 3.4: On a failing APB write, whether the Completer modified its internal register before asserting `PSLVERR` is peripheral-specific; the CPU still halts immediately without advancing `PC`.)*
