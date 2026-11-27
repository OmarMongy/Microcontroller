# Address Map Interface Contract

- **Contract ID:** `CON-ADDR-001`
- **Version:** `v1.1`
- **Status:** `APPROVED (DEC-ARCH-CORE-001, DEC-ARCH-CORE-002)`
- **Date:** 2026-11-27
- **Parent Proposal:** [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md)
- **Approved Decisions:** [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) (Decisions #1, #3, #4), [DEC-ARCH-CORE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-002.md) (`FAULT_DATA_RO_WRITE`)
- **Scope Boundary:** Defines top-level non-overlapping address regions and peripheral subrange decode boundaries ONLY. Individual UART, GPIO, and Timer register offsets, bit fields, reset values, and FIFO policies remain **explicitly deferred** to a later focused architecture task.

---

## 1. Address Conventions

- **Address Width:** 32-bit byte-addressed physical address space (`0x0000_0000` through `0xFFFF_FFFF`).
- **Endianness:** Little-endian byte ordering across all regions.
- **Range Notation:**
  - **Inclusive End (`End_Incl`):** Last valid byte address in the region (`Base + Size - 1`).
  - **Exclusive End (`End_Excl`):** First byte address immediately following the region (`Base + Size`).
- **Modified Harvard Separation (`DEC-ARCH-CORE-001`):** Instruction fetch (`IF` path) and Data load/store (`MEM` path) have independent address decoders. `IROM` is executable on the `IF` path and **read-only** on the `MEM` path (for bare-metal C `.rodata` loads); `DRAM` and `APB3` are data-only and non-executable on the `IF` path.

---

## 2. Top-Level Memory & Peripheral Map (`APPROVED — DEC-ARCH-CORE-001`)

| Region | Status | Base Address | Inclusive End | Exclusive End | Size (Bytes) | Alignment | IF Path | Data Path |
|---|---|---:|---:|---:|---:|---|---|---|
| **Instruction ROM (`IROM`)** | `APPROVED` | `0x0000_0000` | `0x0000_7FFF` | `0x0000_8000` | 32,768 (`0x8000`) | 32 KB | **Execute / Fetch** (4B aligned) | **Read-Only** (`LB/LBU/LH/LHU/LW` aligned; `STORE` faults with `FAULT_DATA_RO_WRITE`) |
| *Unmapped Gap 0* | `APPROVED` | `0x0000_8000` | `0x1FFF_FFFF` | `0x2000_0000` | ~512 MB | — | **FAULT** (`FAULT_IF_UNMAPPED`) | **FAULT** (`FAULT_DATA_UNMAPPED`) |
| **Data RAM (`DRAM`)** | `APPROVED` | `0x2000_0000` | `0x2000_7FFF` | `0x2000_8000` | 32,768 (`0x8000`) | 32 KB | **FAULT** (`FAULT_IF_UNMAPPED`) | **Read / Write** (1B, 2B, 4B aligned) |
| *Unmapped Gap 1* | `APPROVED` | `0x2000_8000` | `0x3FFF_FFFF` | `0x4000_0000` | ~512 MB | — | **FAULT** (`FAULT_IF_UNMAPPED`) | **FAULT** (`FAULT_DATA_UNMAPPED`) |
| **APB3 Peripheral Window** | `APPROVED` | `0x4000_0000` | `0x4000_FFFF` | `0x4001_0000` | 65,536 (`0x1_0000`) | 64 KB | **FAULT** (`FAULT_IF_UNMAPPED`) | **Populated slots only** (see Section 3) |
| *Unmapped Gap 2* | `APPROVED` | `0x4001_0000` | `0xFFFF_FFFF` | — | ~3 GB | — | **FAULT** (`FAULT_IF_UNMAPPED`) | **FAULT** (`FAULT_DATA_UNMAPPED`) |

- **Reset Vector (`APPROVED` `D1`):** `0x0000_0000` (word 0 of `IROM`).

---

## 3. APB3 Peripheral Subranges & Decode Boundary (`APPROVED — DEC-ARCH-CORE-001`)

Within the 64 KB APB3 peripheral window (`0x4000_0000`–`0x4000_FFFF`), decode granularity is **4 KB (`0x1000` bytes)** per peripheral slot (`addr[15:12]`):

| Slot | Peripheral | Select Signal | Base Address | Inclusive End | Exclusive End | Size | Data Path Access |
|---:|---|---|---:|---:|---:|---:|---|
| 0 | **UART** (`uart_apb`) | `PSEL_UART` | `0x4000_0000` | `0x4000_0FFF` | `0x4000_1000` | 4 KB | Read/Write (`LW`/`SW`, 4B aligned only) |
| 1 | **GPIO (8-bit)** (`gpio_apb`) | `PSEL_GPIO` | `0x4000_1000` | `0x4000_1FFF` | `0x4000_2000` | 4 KB | Read/Write (`LW`/`SW`, 4B aligned only) |
| 2 | **Timer (32-bit)** (`timer_apb`) | `PSEL_TIMER` | `0x4000_2000` | `0x4000_2FFF` | `0x4000_3000` | 4 KB | Read/Write (`LW`/`SW`, 4B aligned only) |
| 3–15 | *Reserved / Unpopulated* | *None* | `0x4000_3000` | `0x4000_FFFF` | `0x4001_0000` | 52 KB | **FAULT** (`FAULT_DATA_UNMAPPED`) |

### Peripheral Decode Boundary Rule (`APPROVED — DEC-ARCH-CORE-001`)
1. **Top-Level / Bridge Responsibility:** `data_bus_decode` checks `addr[31:12]` against the three populated APB3 slots (`0x4000_0`, `0x4000_1`, `0x4000_2`). Unpopulated slots (`0x4000_3000`–`0x4000_FFFF`) are rejected **before** asserting `apb_req_valid` and raise `FAULT_DATA_UNMAPPED` immediately.
2. **Bridge-to-Peripheral Boundary:** When a populated slot is targeted with a valid aligned `LW`/`SW`, the APB3 bridge asserts the corresponding one-hot `PSELx` and drives `PADDR[31:0]`. Each peripheral decodes only its local 4 KB offset `PADDR[11:0]` (register offsets deferred).
3. **Peripheral Responsibility (`PSLVERR`):** If software issues a valid aligned `LW`/`SW` to an unimplemented register offset *within* an allocated 4 KB peripheral subrange, the peripheral Completer is responsible for responding with `PREADY = 1` and `PSLVERR = 1` (exact register-level error conditions to be specified in the peripheral register-map task).

---

## 4. Exact Modified Harvard Decode & Alignment Rules

### 4.1 Instruction Fetch (`IF` Path) (`APPROVED — DEC-ARCH-CORE-001`)
- **Exact Decode Equation:** `if_in_irom = (pc[31:15] == 17'h0000_0)` (full 32-bit comparison, no aliasing).
- **Alignment Rule:** `pc[1:0] == 2'b00`.
- **Faults:**
  - `!if_in_irom` -> `FAULT_IF_UNMAPPED` (suppresses fetch, halts CPU).
  - `if_in_irom && (pc[1:0] != 2'b00)` -> `FAULT_IF_MISALIGNED` (suppresses fetch, halts CPU).

### 4.2 Data Access (`MEM` Path) (`UPDATED PER DEC-ARCH-CORE-001`)
- **Exact Decode Equations:**
  - `data_in_irom = (daddr[31:15] == 17'h0000_0)` (`0x0000_0000`–`0x0000_7FFF`, read-only via `irom_local` Port B).
  - `data_in_dram = (daddr[31:15] == 17'b0010_0000_0000_0000_0)` (`0x2000_0000`–`0x2000_7FFF`).
  - `data_in_uart = (daddr[31:12] == 20'h4000_0)` (`0x4000_0000`–`0x4000_0FFF`).
  - `data_in_gpio = (daddr[31:12] == 20'h4000_1)` (`0x4000_1000`–`0x4000_1FFF`).
  - `data_in_timer = (daddr[31:12] == 20'h4000_2)` (`0x4000_2000`–`0x4000_2FFF`).
  - `data_in_apb = data_in_uart || data_in_gpio || data_in_timer`.
- **Multi-byte Wrap / Cross-Region Guarantee:** Because `IROM`, `DRAM`, and each APB3 slot are power-of-2 aligned (`32 KB` / `4 KB`) and all multi-byte accesses must be naturally aligned (`LH/LHU/SH` on `2B` boundary, `LW/SW` on `4B` boundary), no valid aligned load or store can ever straddle a region or slot boundary.
- **Data Fault Rules (Evaluated in Priority Order before Issuing Memory/APB Requests):**
  1. `!(data_in_irom || data_in_dram || data_in_apb)` (including reserved APB slots `0x4000_3000`–`0x4000_FFFF`) -> `FAULT_DATA_UNMAPPED`.
  2. `data_in_irom && dmem_we` (any `SB`, `SH`, or `SW` targeting `IROM`) -> `FAULT_DATA_RO_WRITE` (`4'hA`; approved in `DEC-ARCH-CORE-002`).
  3. `data_in_apb` with `LB`/`LBU`/`LH`/`LHU`/`SB`/`SH` -> `FAULT_DATA_SIZE_UNSUP`.
  4. Misaligned `LH`/`LHU` (`daddr[0] != 1'b0`) in `IROM`/`DRAM`, `SH` (`daddr[0] != 1'b0`) in `DRAM`, or misaligned `LW`/`SW` (`daddr[1:0] != 2'b00`) in `IROM`, `DRAM`, or `APB` -> `FAULT_DATA_MISALIGNED`.
- **Side-Effect Guarantee:** Any data pre-check fault suppresses `irom_dreq`, `dram_req`, and `apb_req_valid`, guaranteeing zero `DRAM` writes, zero `RF` writes, and zero APB transfers.
