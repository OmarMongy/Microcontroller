# Architecture Proposal V1.1 — Single-Cycle RV32I Microcontroller SoC

- **Document ID:** `ARCH-PROP-001`
- **Version:** `V1.2 (CORE ARCHITECTURE FROZEN PER DEC-ARCH-CORE-001 & DEC-ARCH-CORE-002)`
- **Date:** 2026-11-27
- **Author:** Architect Agent
- **Specification Baseline:** [SOC_SPECIFICATION_DRAFT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/specifications/SOC_SPECIFICATION_DRAFT.md) (Draft 0.3)
- **Approved Human Decisions Referenced:**
  - [DEC-ARCH-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-BASELINE-001.md) (`APPROVED`)
  - [DEC-ARCH-BASELINE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-BASELINE-002.md) (`APPROVED_DIRECTION`)
  - [DEC-CPU-APB-WAIT-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-CPU-APB-WAIT-001.md) (`APPROVED`)
  - [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) (`APPROVED` — Core Architecture Decisions #1–#7)
  - [DEC-ARCH-CORE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-002.md) (`APPROVED` — `IROM` Port B 1-cycle sync read, `FAULT_DATA_RO_WRITE` `4'hA`, `FENCE` as single-cycle NOP after memory completion)
- **External Protocol Reference:** `AMBA® APB Protocol Specification` (ARM IHI 0024E / ID022823, Issue E; APB3 / Issue B rules only), stored at [IHI0024E_amba_apb_architecture_spec.pdf](file:///mnt/e/PB/Projects/Microcontroller/docs/specifications/references/IHI0024E_amba_apb_architecture_spec.pdf)

> **Revision / Approval Status (`DEC-ARCH-CORE-001` & `DEC-ARCH-CORE-002`):**
> All core architecture items and contracts (`CON-ADDR-001`, `CON-MEM-001`, `CON-APB3-001`, `CON-FLT-RST-001`, `CON-TOP-001`) are **APPROVED / FROZEN** per [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) and [DEC-ARCH-CORE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-002.md).
> Peripheral register offsets, bit fields, reset values, and polling/FIFO policies are handled in the separate focused peripheral register-map architecture task (`ARCH-003`).

---

## 1. Executive Summary & Approved Baseline (`DEC-ARCH-CORE-001`)

1. **Modified Harvard Organization (`APPROVED`):** Separate dedicated local Instruction ROM (`IROM`, 32 KB: Port A instruction fetch + Port B read-only `.rodata` data port) and local Data RAM (`DRAM`, 32 KB). Neither memory uses APB.
2. **Non-Overlapping Address Map (`APPROVED`):**
   - `IROM`: `0x0000_0000` – `0x0000_7FFF` (32 KB, covers reset vector `0x0000_0000`; IF Read/Exec + Data Read-Only)
   - `DRAM`: `0x2000_0000` – `0x2000_7FFF` (32 KB; Data Read/Write)
   - `APB3 Window`: `0x4000_0000` – `0x4000_FFFF` (64 KB total, 4 KB slot granularity; populated slots `0..2` = `0x4000_0000` – `0x4000_2FFF` for UART, GPIO, Timer)
3. **Fixed-Latency Local Memories (`APPROVED` Option RAM-B + `PROPOSED` Port B Sync Read):**
   - `IROM` Port A (IF): 0-cycle combinational read (`inst` valid in the same cycle as `PC`). Ordinary non-load instructions remain 1 cycle.
   - `IROM` Port B (Data RO, `PROPOSED`): 1-cycle synchronous read (uniform with `DRAM`, 2 cycles total per `.rodata` load; avoids an 8192:1 read mux on the `ALU -> ByteExt -> RF` critical path).
   - `DRAM` (`APPROVED` Option RAM-B): 1-cycle synchronous read (1 wait state = 2 cycles total per `DRAM` load) and 1-cycle synchronous `posedge clk` write with 4-bit byte enables (0 wait states on stores).
4. **Strict APB3 Compliance (`APPROVED` Option APB-W1 & Design 4A):** Uses only APB3 (Issue B / v1.0) signals (`PCLK`, `PRESETn`, `PADDR`, `PSELx`, `PENABLE`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`, `PSLVERR`). Registered APB3 bridge (`IDLE -> SETUP -> ACCESS`), 3-cycle minimum 0-wait-state APB transfer, strict 32-bit aligned `LW`/`SW`-only access policy on APB3, and stall/hold/exactly-once commit contract.
5. **Deterministic Fault-and-Halt Policy (`APPROVED` + `4'hA` `PROPOSED`):** 4-bit fault code encoding (`4'h0`–`4'hA`), sticky captured context (`fault_pc`, `fault_insn`, `fault_addr`), deterministic priority order, zero state corruption on fault, and reset-only recovery.
6. **Safe Reset Synchronization (`APPROVED` Option RST-A):** External active-low asynchronous `rst_n` passed through a 2-FF asynchronous-assert / synchronous-deassert reset synchronizer producing `sys_rst_n` / `PRESETn`.

---

## 2. Top-Level Address Map (`APPROVED — DEC-ARCH-CORE-001`)

Full details are specified in [ADDRESS_MAP_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/ADDRESS_MAP_CONTRACT.md) (`CON-ADDR-001` v1.1).

### 2.1 End-Address Convention
All address ranges use **both** explicit notation forms:
- **Inclusive end (`[Base, End_Incl]`):** `End_Incl = Base + Size - 1` (e.g., `0x0000_0000` – `0x0000_7FFF`).
- **Exclusive end (`[Base, End_Excl)`):** `End_Excl = Base + Size` (e.g., `0x0000_8000`).

### 2.2 Approved Region & Subrange Table

| Region / Subrange | Status | Base Address | Inclusive End | Exclusive End | Size | Alignment | IF Path Permission | Data Path Permission |
|---|---|---:|---:|---:|---:|---|---|---|
| **Instruction ROM (`IROM`)** | `APPROVED` | `0x0000_0000` | `0x0000_7FFF` | `0x0000_8000` | 32 KB (`0x8000`) | 32 KB | Read/Execute (4B aligned) | **Read-Only** (`LB/LBU/LH/LHU/LW`; `STORE` -> `FAULT_DATA_RO_WRITE`) |
| **Data RAM (`DRAM`)** | `APPROVED` | `0x2000_0000` | `0x2000_7FFF` | `0x2000_8000` | 32 KB (`0x8000`) | 32 KB | **Fault** (`FAULT_IF_UNMAPPED`) | Read/Write (`LB/LBU/LH/LHU/LW`, `SB/SH/SW`) |
| **APB3 Window (Total)** | `APPROVED` | `0x4000_0000` | `0x4000_FFFF` | `0x4001_0000` | 64 KB (`0x1_0000`) | 64 KB | **Fault** (`FAULT_IF_UNMAPPED`) | Populated slots only (see below) |
| — **UART Subrange (`PSEL_UART`)** | `APPROVED` | `0x4000_0000` | `0x4000_0FFF` | `0x4000_1000` | 4 KB (`0x1000`) | 4 KB | **Fault** | Read/Write (`LW`/`SW` aligned only) |
| — **GPIO Subrange (`PSEL_GPIO`)** | `APPROVED` | `0x4000_1000` | `0x4000_1FFF` | `0x4000_2000` | 4 KB (`0x1000`) | 4 KB | **Fault** | Read/Write (`LW`/`SW` aligned only) |
| — **Timer Subrange (`PSEL_TIMER`)** | `APPROVED` | `0x4000_2000` | `0x4000_2FFF` | `0x4000_3000` | 4 KB (`0x1000`) | 4 KB | **Fault** | Read/Write (`LW`/`SW` aligned only) |
| — **APB3 Reserved Slots (3..15)** | `APPROVED` | `0x4000_3000` | `0x4000_FFFF` | `0x4001_0000` | 52 KB (`0xD000`) | 4 KB | **Fault** | **Fault** (`FAULT_DATA_UNMAPPED`) |
| **All Other Addresses** | `APPROVED` | — | — | — | — | — | **Fault** (`FAULT_IF_UNMAPPED`) | **Fault** (`FAULT_DATA_UNMAPPED`) |

### 2.3 Decode Granularity & Unmapped Handling
- **Full-width exact decode (`APPROVED`):** Both instruction and data decoders compare the full 32-bit address (`addr[31:15]` for 32 KB `IROM`/`DRAM`, `addr[31:12]` for 4 KB APB3 slots). **No address aliasing/mirroring** is permitted.
- **Peripheral decode boundary:** `data_bus_decode` asserts `apb_req_valid` only for `0x4000_0000`–`0x4000_2FFF`. The APB3 bridge uses `PADDR[13:12]` to drive one-hot `PSEL_UART`, `PSEL_GPIO`, or `PSEL_TIMER`, and forwards `PADDR[31:0]` (peripherals decode `PADDR[11:0]`). Register decode inside each 4 KB subrange remains **deferred**.

---

## 3. Local Memory Interfaces (`IROM` & `DRAM`)

Full signal tables, byte-lane rules, and cycle-accurate timing diagrams are in [LOCAL_MEMORY_INTERFACE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/LOCAL_MEMORY_INTERFACE_CONTRACT.md) (`CON-MEM-001` v1.1).

### 3.1 Instruction ROM (`irom_local`) Dual-Port Modified Harvard Interface
- **Port A (Instruction Fetch — `Option ROM-A`):** Dedicated local instruction port (`irom_en`, `irom_addr[14:0]`, `irom_rdata[31:0]`), **0-cycle combinational word read**. Preserves 1-cycle execution for all non-load, non-APB RV32I instructions at 50 MHz.
- **Port B (Data Read-Only `.rodata` — `PROPOSED` 1-Cycle Synchronous Read):** Dedicated read-only data port (`irom_dreq`, `irom_daddr[14:0]`, `irom_drdata[31:0]`).
  - *Why 1-cycle synchronous read is recommended (`PROPOSED`):* Matches `Option RAM-B` (`dram_local`), avoids placing an 8,192:1 32-bit combinational read mux on the `IROM -> Decode -> RF -> ALU -> IROM Port B -> ByteExt -> RF` critical path in generic synthesis, and lets `data_bus_decode` share one unified `local_rd_valid` 2-cycle load handshake for all local memory loads (`IROM` + `DRAM`).
  - *Alternative (Pending Confirmation #1):* 0-cycle combinational Port B read (1 cycle for `.rodata` loads, 2 cycles for `DRAM` loads), at the cost of a much longer generic-synthesis combinational path through the 32 KB ROM read mux.
- **Initialization & Endianness:** Word-oriented `.hex`/`.mem` (`$readmemh`), little-endian byte ordering (`inst[7:0]` at `+0`), unprogrammed words `32'h0000_0000`.

### 3.2 Data RAM (`dram_local`) Interface (`APPROVED` Option RAM-B)
- **Dedicated local port:** `clk`, `sys_rst_n`, `dram_req`, `dram_we`, `dram_be[3:0]`, `dram_addr[14:0]`, `dram_wdata[31:0]`, `dram_rdata[31:0]`.
- **Timing (`APPROVED` Option RAM-B):**
  - **Writes (`SB`/`SH`/`SW`):** **1 clock cycle** (0 wait states; synchronous byte-enabled write at `posedge clk`).
  - **Reads (`LB`/`LBU`/`LH`/`LHU`/`LW`):** **2 clock cycles** (1 fixed wait state; `C0` issues `dram_req && !dram_we` with `local_read_stall = 1`, `dram_rdata` latches on `posedge clk` at `T1`; `C1` holds `dram_rdata` valid with `local_read_stall = 0` and commits `RF[rd]` + `PC+4` at `T2`).
  - **Quantified Impact:** Non-load instructions remain 1 cycle; every local `DRAM` load adds +1 cycle (e.g., 20% dynamic load mix yields CPI = `1.20` on local code) in exchange for removing the 32 KB 8192:1 read mux from the CPU critical path.
- **Byte Ordering & Alignment:** Little-endian (`dram_be[n]` -> bits `[8n+7:8n]`). `LB/LBU/SB` always aligned; `LH/LHU/SH` require `addr[0] == 0`; `LW/SW` require `addr[1:0] == 2'b00`.

---

## 4. APB3 Bridge FSM & CPU Stall/Hold/Commit Timing (`APPROVED — DEC-ARCH-CORE-001`)

Full contract and timing diagrams are in [APB3_BRIDGE_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/APB3_BRIDGE_CONTRACT.md) (`CON-APB3-001` v1.1).

- **Strict APB3 (Issue B) Signal Subset:** `PCLK`, `PRESETn`, `PADDR[31:0]`, `PSEL_UART`, `PSEL_GPIO`, `PSEL_TIMER`, `PENABLE`, `PWRITE`, `PWDATA[31:0]`, `PREADY`, `PRDATA[31:0]`, `PSLVERR`. No APB4 (`PPROT`, `PSTRB`) or APB5 signals.
- **Sub-Word & Unaligned Policy (`APPROVED` Option APB-W1):** Strict 32-bit aligned `LW`/`SW` only on APB3. `LB`/`LBU`/`LH`/`LHU`/`SB`/`SH` fault (`FAULT_DATA_SIZE_UNSUP`) and unaligned `LW`/`SW` fault (`FAULT_DATA_MISALIGNED`) prior to initiating any APB transfer.
- **Registered Bridge FSM (`APPROVED` Design 4A):** `IDLE -> SETUP -> ACCESS`, 3-cycle minimum 0-wait transfer (`C0` decode/req + `C1` `SETUP` + `C2` `ACCESS`), `PREADY=0` holds `ACCESS` and keeps all APB signals unchanged, `PSLVERR` sampled only on `PSELx && PENABLE && PREADY`, CPU holds `PC`/instruction on `dmem_stall` and commits `RF`/`PC` exactly once (suppressing `RF` write on `PSLVERR`).

---

## 5. Fault Status, Capture, Priority, Halt, and Recovery

Full specification is in [FAULT_AND_RESET_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/FAULT_AND_RESET_CONTRACT.md) (`CON-FLT-RST-001` v1.1).

- **Fault Codes (`fault_code[3:0]`):**
  - `4'h0`: `FAULT_NONE`
  - `4'h1`: `FAULT_IF_MISALIGNED` (`pc[1:0] != 2'b00`)
  - `4'h2`: `FAULT_IF_UNMAPPED` (`pc` outside `IROM`)
  - `4'h3`: `FAULT_ILLEGAL_INSN` (non-RV32I instruction; `FENCE` treated as valid RV32I `NOP`)
  - `4'h4`: `FAULT_ECALL`
  - `4'h5`: `FAULT_EBREAK`
  - `4'h6`: `FAULT_DATA_MISALIGNED`
  - `4'h7`: `FAULT_DATA_UNMAPPED`
  - `4'h8`: `FAULT_DATA_SIZE_UNSUP` (sub-word access on APB3)
  - `4'h9`: `FAULT_APB_SLVERR` (`PSLVERR == 1` during `ACCESS && PREADY`)
  - `4'hA`: `FAULT_DATA_RO_WRITE` (`PROPOSED` — `SB`/`SH`/`SW` targeting read-only `IROM` `0x0000_0000`–`0x0000_7FFF`)
- **Priority Order (Highest to Lowest):**
  `FAULT_IF_UNMAPPED` > `FAULT_IF_MISALIGNED` > (`FAULT_ECALL` | `FAULT_EBREAK` | `FAULT_ILLEGAL_INSN`) > `FAULT_DATA_UNMAPPED` > `FAULT_DATA_RO_WRITE` > `FAULT_DATA_SIZE_UNSUP` > `FAULT_DATA_MISALIGNED` > `FAULT_APB_SLVERR`.
- **Captured Context & Recovery:** Sticky `fault_valid`, `fault_code[3:0]`, `fault_pc[31:0]`, `fault_insn[31:0]`, `fault_addr[31:0]` exposed on `rv32i_cpu` and `soc_top`; `PC` frozen and writes suppressed on fault; reset (`rst_n == 0`) recovery only.

---

## 6. Reset Behavior (`APPROVED — DEC-ARCH-CORE-001`)

Full specification is in [FAULT_AND_RESET_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/FAULT_AND_RESET_CONTRACT.md) (`CON-FLT-RST-001` v1.1).

- **Reset Synchronizer (`APPROVED` Option RST-A):** 2-FF asynchronous-assert / synchronous-deassert synchronizer (`rst_sync`) producing `sys_rst_n` and `PRESETn`.
- **Reset Values:** `PC = 32'h0000_0000`; `x1..x31 = 32'h0000_0000`; `fault_* = 0`; `local_rd_valid = 0`; `dram_rdata = 32'h0`; `irom_drdata = 32'h0`; 32 KB `DRAM` array has no hardware reset tree (sim time-0 `0`); `APB3 Bridge` in `IDLE`; peripherals reset via `PRESETn` to safe idle states (exact register maps deferred).

---

## 7. Top-Level Module Hierarchy & Integration (`APPROVED — DEC-ARCH-CORE-001`)

Full block diagram, module table, and port list are in [SOC_TOP_HIERARCHY_CONTRACT.md](file:///mnt/e/PB/Projects/Microcontroller/docs/interface_contracts/SOC_TOP_HIERARCHY_CONTRACT.md) (`CON-TOP-001` v1.1).

```text
                        clk (50 MHz), rst_n
                                |
                          +-----v-----+
                          | rst_sync  |---> sys_rst_n / PRESETn
                          +-----------+
                                |
                          +-----v-----+       fault_* (valid, code, PC, addr, insn)
           +------------->| rv32i_cpu |---------------------------------------------->
           | Port A (IF)  +-----+-----+
           |                    | (Data path: dmem_req, we, size, addr, wdata, rdata, stall, fault)
     +-----+-----+        +-----v-----------+
     |irom_local |<-------| data_bus_decode |
     | (32 KB)   | Port B +---+---------+---+
     +-----------+ (Data RO)  |         |
                       +------v---+  +--v----------+
                       |dram_local|  | apb3_bridge |
                       | (32 KB)  |  +--+----------+
                       +----------+     | APB3 (PCLK, PRESETn, PADDR, PSELx, PENABLE,
                                        |       PWRITE, PWDATA, PREADY, PRDATA, PSLVERR)
                                    +---+---+---+
                                    |   |   |
                                  UART GPIO Timer
```

---

## 8. Core Baseline Freeze Status (`DEC-ARCH-CORE-001` & `DEC-ARCH-CORE-002`)

All core architecture decisions and the three confirmation items are **APPROVED / FROZEN** per [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) and [DEC-ARCH-CORE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-002.md):
1. `IROM` Port B (`irom_local` read-only `.rodata` port): **1-cycle synchronous read**, matching `DRAM` `Option RAM-B` timing.
2. `IROM` store attempts (`SB`, `SH`, `SW`): raise **`FAULT_DATA_RO_WRITE`**, code **`4'hA`**.
3. RV32I `FENCE`: valid single-cycle `NOP`, provided all preceding memory transactions have completed before retirement.

*(Remaining open architecture scope: detailed peripheral register maps for `uart_apb`, `gpio_apb`, and `timer_apb`, deferred to `ARCH-003`.)*
