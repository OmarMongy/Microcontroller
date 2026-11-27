# Local Memory Interface Contract (`IROM` & `DRAM`)

- **Contract ID:** `CON-MEM-001`
- **Version:** `v1.1`
- **Status:** `APPROVED (DEC-ARCH-CORE-001, DEC-ARCH-CORE-002)`
- **Date:** 2026-11-27
- **Parent Proposal:** [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md)
- **Approved Decisions:** [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) (Decisions #1 & #2), [DEC-ARCH-CORE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-002.md) (`IROM` Port B 1-cycle synchronous read)
- **Scope:** Dedicated local interfaces for the 32 KB Instruction ROM (`irom_local`, dual-port Modified Harvard: Port A instruction fetch + Port B read-only data) and 32 KB Data RAM (`dram_local`, `Option RAM-B`). Neither memory uses APB.

---

## 1. Instruction ROM (`irom_local`) Interface Contract (`Modified Harvard`)

### 1.1 Parameters & Organization
- **Capacity:** 32 KB = 8,192 words x 32 bits (`DEPTH = 8192`, `ADDR_WIDTH = 15`, `DATA_WIDTH = 32`).
- **Address Range:** `0x0000_0000` – `0x0000_7FFF` (word index `addr[14:2]`, 0..8191).
- **Initialization Parameter:** `INIT_FILE` (path to `.hex` or `.mem` image).
- **Dual-Port Modified Harvard Role (`DEC-ARCH-CORE-001`):**
  - **Port A (Instruction Fetch):** Read-only, **0-cycle combinational read** (`Option ROM-A`) so ordinary non-load instructions execute in 1 clock cycle.
  - **Port B (Data Read-Only `.rodata`):** Read-only, **1-cycle synchronous read** (`APPROVED` per `DEC-ARCH-CORE-002`, matching `Option RAM-B` timing so `IROM` Port B avoids an 8192:1 combinational read mux on the `ALU -> ByteExt -> RF` critical path). Stores (`SB`/`SH`/`SW`) to `IROM` are rejected by `data_bus_decode` with `FAULT_DATA_RO_WRITE` (`4'hA`).

### 1.2 Signal Table (`irom_local`)

| Port | Signal | Width | Direction (wrt `irom_local`) | Polarity / Timing | Description |
|---|---|---:|---|---|---|
| Global | `clk` | 1 | Input | Rising-edge | Shared 50 MHz SoC clock (used by Port B synchronous read). |
| Global | `sys_rst_n` | 1 | Input | Active-LOW | Synchronized system reset; clears `irom_drdata` register to `32'h0`. |
| Port A (IF) | `irom_en` | 1 | Input | Active-HIGH | `1` when `sys_rst_n == 1`, `!fault_valid`, and `PC` is valid/aligned inside `IROM`. Returns `32'h0` when `0`. |
| Port A (IF) | `irom_addr` | 15 | Input | Byte offset `[14:0]` | `pc[14:0]`. Bits `[1:0]` must be `2'b00`; word index is `irom_addr[14:2]`. |
| Port A (IF) | `irom_rdata` | 32 | Output | Combinational | 32-bit instruction word `mem[irom_addr[14:2]]` when `irom_en == 1`; `32'h0` otherwise. |
| Port B (Data RO) | `irom_dreq` | 1 | Input | Active-HIGH | Read strobe from `data_bus_decode` (`1` during Cycle `C0` of a valid aligned `IROM` load; `0` during `C1`). |
| Port B (Data RO) | `irom_daddr` | 15 | Input | Byte offset `[14:0]` | `daddr[14:0]`. Word index is `irom_daddr[14:2]`. |
| Port B (Data RO) | `irom_drdata` | 32 | Output | Registered (`posedge clk`) | Captures `mem[irom_daddr[14:2]]` on `posedge clk` when `sys_rst_n && irom_dreq`; holds value during `C1`. |

### 1.3 Port A Read Timing (0-Cycle Combinational Fetch)
1. At `posedge clk` (`T_k`), `PC` updates (or resets to `0x0000_0000`).
2. During `[T_k, T_{k+1})`, `irom_rdata` settles combinationally to `mem[PC[14:2]]`.
3. If the instruction completes in 1 cycle (`ALU`, `BRANCH`, `JAL`, `JALR`, `DRAM` store), `PC` updates at `T_{k+1}`.
4. If stalled (`dmem_stall == 1` for `DRAM` load, `IROM` Port B load, or `APB3` transfer), `PC` and `irom_addr` hold steady, keeping `irom_rdata` constant across `C0..C1` (or `C0..C2+W`).

### 1.4 Port B Read Timing (1-Cycle Synchronous `.rodata` Load — 2 Cycles Total)
Port B uses the exact same 2-cycle `local_rd_valid` / `local_read_stall` handshake as `dram_local` reads (see Section 2.4):
- **Cycle `C0` (`[T0, T1)`):** CPU decodes `LB`/`LBU`/`LH`/`LHU`/`LW` targeting `IROM`. `irom_dreq = 1`, `local_rd_valid = 0`, `local_read_stall = 1` (`dmem_stall = 1`). At `T1`, `irom_local` registers `irom_drdata <= mem[irom_daddr[14:2]]`, `data_bus_decode` sets `local_rd_valid <= 1`, and `PC` is held.
- **Cycle `C1` (`[T1, T2)`):** `irom_dreq = 0` (holds `irom_drdata` stable), `local_rd_valid = 1`, `local_read_stall = 0` (`dmem_stall = 0`). CPU extracts/sign-extends byte/halfword/word from `irom_drdata`. At `T2`, `RF[rd]` commits, `PC <= PC + 4`, and `local_rd_valid <= 0`.

### 1.5 Initialization Format & Little-Endian Word Ordering
- **Format:** Word-addressed hexadecimal text file (`.mem` / `.hex`) compatible with `$readmemh`. Each line holds one 32-bit hex word (8 hex digits representing `inst[31:0]`), starting at word `0` (`0x0000_0000`) up to at most word `8191` (`0x0000_7FFC`), or using `@<word_hex_addr>` directives.
- **Endianness Mapping:** For 32-bit word `W` at byte base `A = {word_idx, 2'b00}`: Byte `A+0 = W[7:0]`, Byte `A+1 = W[15:8]`, Byte `A+2 = W[23:16]`, Byte `A+3 = W[31:24]`.
- **Unprogrammed Words:** Default to `32'h0000_0000` (illegal RV32I opcode -> `FAULT_ILLEGAL_INSN` if fetched on Port A; reads as `0` if loaded on Port B).

---

## 2. Data RAM (`dram_local`) Interface Contract (`Option RAM-B — APPROVED`)

*(Note: `Option RAM-A` 0-cycle combinational read was rejected in `DEC-ARCH-CORE-001`; `Option RAM-B` 1-cycle synchronous read + 1-cycle synchronous write is the active approved contract.)*

### 2.1 Parameters & Organization
- **Capacity:** 32 KB = 8,192 words x 32 bits (`DEPTH = 8192`, `ADDR_WIDTH = 15`, `DATA_WIDTH = 32`).
- **Address Range:** `0x2000_0000` – `0x2000_7FFF` (byte offset `dram_addr[14:0] = daddr[14:0]`, word index `dram_addr[14:2]`).

### 2.2 Signal Table (`dram_local`)

| Signal | Width | Direction (wrt `dram_local`) | Polarity / Timing | Description |
|---|---:|---|---|---|
| `clk` | 1 | Input | Rising-edge | Shared 50 MHz SoC clock. |
| `sys_rst_n` | 1 | Input | Active-LOW | Synchronized system reset; suppresses writes and clears `dram_rdata` to `32'h0`. |
| `dram_req` | 1 | Input | Active-HIGH | `1` when CPU executes a valid, aligned `DRAM` store (`C0`) or `DRAM` load (`C0` only, gated by `!local_rd_valid`), `!fault_valid`, and `sys_rst_n == 1`. |
| `dram_we` | 1 | Input | Active-HIGH | `1` = Synchronous write (`SB/SH/SW`), `0` = Synchronous read (`LB/LBU/LH/LHU/LW`). |
| `dram_be` | 4 | Input | Active-HIGH per byte | Byte write enables (`dram_be[n]` writes `dram_wdata[8n+7 : 8n]`). Must be `4'b0000` on reads (`dram_we == 0`). |
| `dram_addr` | 15 | Input | Byte offset `[14:0]` | `daddr[14:0]`. Word index is `dram_addr[14:2]`; byte/halfword lane decoded from `dram_addr[1:0]`. |
| `dram_wdata` | 32 | Input | Write data word | Little-endian lane-placed write data; valid when `dram_req && dram_we`. |
| `dram_rdata` | 32 | Output | Registered (`posedge clk`) | Captures `mem[dram_addr[14:2]]` on `posedge clk` when `sys_rst_n && dram_req && !dram_we`; holds value during `C1`. |

### 2.3 Read & Write Timing (`Option RAM-B — APPROVED`)
- **Write Timing (`SB`/`SH`/`SW`):** **1 clock cycle (0 wait states)**.
  - During `C0` (`[T0, T1)`): `dram_req = 1`, `dram_we = 1`, `local_read_stall = 0` (`dmem_stall = 0`).
  - At `T1` (`posedge clk`): For each `n in 0..3`, if `dram_be[n] == 1'b1`, `mem[dram_addr[14:2]][8n+7 : 8n] <= dram_wdata[8n+7 : 8n]`; unmasked bytes are preserved. `PC <= PC + 4`.
- **Read Timing (`LB`/`LBU`/`LH`/`LHU`/`LW`):** **2 clock cycles (1 fixed wait state)**.
  - Driven by the `local_rd_valid` flip-flop in `data_bus_decode` (`reset = 1'b0`):
    - `local_rd_issue = dmem_req && !dmem_we && (data_in_dram || data_in_irom) && !dmem_fault_valid && !local_rd_valid`
    - `local_read_stall = local_rd_issue` (HIGH during `C0`, LOW during `C1`)
    - Next state: `local_rd_valid <= local_rd_issue`
  - **Cycle `C0` (`[T0, T1)`):** `dram_req = 1`, `dram_we = 0`, `local_read_stall = 1` (`dmem_stall = 1`). At `T1`, `dram_rdata <= mem[dram_addr[14:2]]`, `local_rd_valid <= 1`, and `PC` holds `PC_ld`.
  - **Cycle `C1` (`[T1, T2)`):** `dram_req = 0` (`!local_rd_valid` gates `dram_req`), `dram_rdata` is stable, `local_read_stall = 0` (`dmem_stall = 0`). CPU extracts/extends byte/halfword/word. At `T2`, `RF[rd]` commits, `PC <= PC_ld + 4`, and `local_rd_valid <= 0`.

### 2.4 Cycle-Accurate Timing Diagram — 2-Cycle Local Load (`DRAM` or `IROM` Port B) Followed by 1-Cycle `DRAM` Store

```text
Cycle:          | C0 (Load Iss)| C1 (Load Data)| C2 (Store)   | C3 (Next)
Clock Edge:     T0             T1             T2             T3             T4
PC              [    PC_ld    ][    PC_ld    ][    PC_st    ][   PC_st+4   ]
irom_rdata (A)  [   LOAD_op   ][   LOAD_op   ][   STORE_op  ][   NEXT_op   ]
dmem_req / we   [  1  /  0    ][  1  /  0    ][  1  /  1    ][  0  /  0    ]
local_rd_valid  _______________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________________________
dram_req/dreq   /‾‾‾‾‾‾‾‾‾‾‾‾‾‾\______________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________
local_read_stall/‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____________________________________________
dmem_stall      /‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____________________________________________
dram_rdata /    ----------------< Valid Word  >-----------------------------
irom_drdata
Commit Event    (Latch rdata   )(RF[rd]<=rdata)(RAM[addr]<=  )
                (at T1; hold PC)(PC<=PC_st @T2)(wdata;PC+4@T3)
```

### 2.5 Little-Endian Byte Enables, Lane Placement & Alignment Rules (Shared by `IROM` Port B Loads & `DRAM` Loads/Stores)

| Instruction | Region(s) | Alignment Check | Fault on Fail | `addr[1:0]` | `dram_be[3:0]` (DRAM only) | Active Data Lane(s) | CPU Read Extraction |
|---|---|---|---|---|---|---|---|
| `LB` / `LBU` | `IROM`, `DRAM` | Always aligned | — | `2'b00`..`2'b11` | `4'b0000` | Byte `addr[1:0]` (`[7:0]`..`[31:24]`) | Sign-ext (`LB`) / Zero-ext (`LBU`) |
| `LH` / `LHU` | `IROM`, `DRAM` | `addr[0] == 1'b0` | `FAULT_DATA_MISALIGNED` | `2'b00` / `2'b10` | `4'b0000` | `2'b00`->`[15:0]`; `2'b10`->`[31:16]` | Sign-ext (`LH`) / Zero-ext (`LHU`) |
| `LW` | `IROM`, `DRAM` | `addr[1:0] == 2'b00` | `FAULT_DATA_MISALIGNED` | `2'b00` | `4'b0000` | `[31:0]` | Full 32-bit word |
| `SB` | `DRAM` only (`IROM` faults `FAULT_DATA_RO_WRITE`) | Always aligned | — | `2'b00`..`2'b11` | `4'b0001 << addr[1:0]` | `rs2[7:0]` in byte `addr[1:0]` (`0` elsewhere) | — |
| `SH` | `DRAM` only (`IROM` faults `FAULT_DATA_RO_WRITE`) | `addr[0] == 1'b0` | `FAULT_DATA_MISALIGNED` | `2'b00` / `2'b10` | `2'b00`->`4'b0011`; `2'b10`->`4'b1100` | `rs2[15:0]` in halfword `addr[1]` (`0` elsewhere) | — |
| `SW` | `DRAM` only (`IROM` faults `FAULT_DATA_RO_WRITE`) | `addr[1:0] == 2'b00` | `FAULT_DATA_MISALIGNED` | `2'b00` | `4'b1111` | `dram_wdata = rs2[31:0]` | — |

### 2.6 Reset & Initialization Policy for `dram_local` (`APPROVED — DEC-ARCH-CORE-001`)
- **Hardware Reset (`sys_rst_n == 0`):** Suppresses all writes (`dram_we` ignored) and resets `dram_rdata` to `32'h0000_0000`. The 32 KB storage array has **no hardware `rst_n` reset tree** (avoids 262,144-FF reset fanout in generic synthesis).
- **Simulation Initialization:** Initialized to `32'h0000_0000` at simulation `time 0`; bare-metal firmware must clear `.bss` in startup code if relying on zeroed RAM after warm reset.
