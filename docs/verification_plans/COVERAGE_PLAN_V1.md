# Functional Coverage Plan V1 — RV32I Microcontroller SoC

- **Document ID:** `COV-PLAN-001`
- **Baseline ID:** `SOC_VB_001`
- **Version:** `V1.0`
- **Status:** `APPROVED / FROZEN (DEC-VER-BASELINE-001)`
- **Date:** 2026-11-27
- **Approved Decision:** [DEC-VER-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-001.md)
- **Author:** Independent Verification Engineer Agent
- **Companion Documents:** [VERIFICATION_PLAN_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/VERIFICATION_PLAN_V1.md), [SVA_SPECIFICATION_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/verification_plans/SVA_SPECIFICATION_V1.md)

---

## 1. Coverage Methodology & Collection Mechanism

1. **Goal:** Achieve **100% hit rate** across all unblocked functional coverpoints and cross bins in `SOC_VB_001` prior to Gate 5 / Gate 8 sign-off, alongside Verilator line/toggle/branch code coverage on the RTL.
2. **Tooling Implementation Note (`Verilator 5.032`):** Because open-source Verilator has limited native support for SystemVerilog `covergroup`/`cross` syntax compared to commercial simulators, each covergroup/bin defined below is implemented in Gate 4 via a dual mechanism:
   - **SVA `cover property`** points (defined in `SVA_SPECIFICATION_V1.md`) for temporal/protocol milestones.
   - **Deterministic SV/C++ Functional Coverage Collector (`tb_cov_collector`)** driven at the scoreboard commit/bus-monitor hook, emitting a machine-readable coverage summary per regression run.
3. **Scope Boundary:** Peripheral functional register covergroups (`CG-UART-*`, `CG-GPIO-*`, `CG-TIMER-*`) are **`BLOCKED (awaiting approved peripheral register-map contract)`** and listed in Section 4.

---

## 2. Unblocked Core Covergroups (`SOC_VB_001`)

### 2.1 `CG-RV32I-OPS` — RV32I Base ISA Instruction Coverage
- **Sampling Point:** Retired instruction (`!dmem_stall && !fault_valid && sys_rst_n`) or decode-fault capture (`FAULT_ECALL`, `FAULT_EBREAK`, `FAULT_ILLEGAL_INSN`).
- **Required Bins (40/40 RV32I instructions + `FENCE`):**
  - `b_upper`: `LUI`, `AUIPC`
  - `b_jumps`: `JAL`, `JALR`
  - `b_branches`: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
  - `b_loads`: `LB`, `LH`, `LW`, `LBU`, `LHU`
  - `b_stores`: `SB`, `SH`, `SW`
  - `b_alu_imm`: `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`
  - `b_alu_reg`: `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`
  - `b_misc`: `FENCE` (`funct3 == 3'b000`, single-cycle NOP)
  - `b_sys_fault`: `ECALL` (`4'h4`), `EBREAK` (`4'h5`)
  - `b_illegal`: `32'h0000_0000`, `32'hFFFF_FFFF`, `CSRR*`, `MRET`, `M`-ext (`MUL`), `FENCE.I` (`4'h3`)
- **Primary Stimulus:** `VER-CORE-001`, `VER-CORE-002`, `VER-FAULT-003..005`.

### 2.2 `CG-RV32I-HAZARD` — Operand, Control-Flow & Architectural Edge Cases
- **Sampling Point:** Instruction retirement.
- **Required Bins:**
  - `b_x0_dest`: Instruction with `rd == x0` and non-zero ALU/load result (`x0` remains `0`).
  - `b_x0_src`: `rs1 == x0` and `rs2 == x0` operands.
  - `b_branch_dir`: Cross of `{BEQ, BNE, BLT, BGE, BLTU, BGEU}` x `{taken, not_taken}` x `{forward_offset, backward_offset}`.
  - `b_jalr_lsb`: `JALR` with `(rs1 + imm)[0] == 1'b1` and `(rs1 + imm)[1] == 1'b0` (LSB cleared to `0`, aligned target).
  - `b_jalr_same_reg`: `JALR rd, rs1, imm` where `rd == rs1` (link address must equal `old_pc + 4`, target uses old `rs1`).
  - `b_load_use`: 2-cycle `DRAM` or `IROM` Port B load immediately followed by an instruction reading `rd`.
  - `b_store_to_load`: `DRAM` 1-cycle store immediately followed by `DRAM` 2-cycle load to the same word address.
  - `b_shift_edges`: Shift amounts `0`, `1`, `31` for `SLL/SRL/SRA/SLLI/SRLI/SRAI` with MSB `0` and MSB `1`.
  - `b_signed_unsigned_cmp`: `SLT/SLTI` vs `SLTU/SLTIU` with `{0x8000_0000, 0x7FFF_FFFF, 0xFFFF_FFFF, 0x0000_0000}`.
- **Primary Stimulus:** `VER-CORE-001`, `VER-CORE-002`.

### 2.3 `CG-ADDR-REGIONS` — Modified Harvard Address Decode & Boundary Coverage
- **Sampling Point:** `IF` path (`pc`) and `MEM` path (`dmem_req && dmem_addr`).
- **Required Bins:**
  - `b_if_irom_low`: Fetch at `0x0000_0000` (reset vector).
  - `b_if_irom_high`: Fetch at upper `IROM` word (`0x0000_7FFC` or branch/jump near top of `IROM`).
  - `b_if_unmapped`: Fetch targeting `0x0000_8000` (IROM end+1), `0x2000_0000` (`DRAM`), `0x4000_0000` (`APB3`).
  - `b_mem_irom_bounds`: `IROM` Port B load at `0x0000_0000` and `0x0000_7FFC`.
  - `b_mem_dram_bounds`: `DRAM` read/write at `0x2000_0000` and `0x2000_7FFC`.
  - `b_mem_apb_slots`: Aligned `LW`/`SW` across Slots 0 (`0x4000_0000`, `+0xFFC`), 1 (`0x4000_1000`, `+0xFFC`), 2 (`0x4000_2000`, `+0xFFC`).
  - `b_mem_apb_rsvd`: Accesses to reserved APB slots (`0x4000_3000`, `0x4000_FFFC`).
  - `b_mem_gaps`: Accesses to Gap 0 (`0x0000_8000`, `0x1FFF_FFFC`), Gap 1 (`0x2000_8000`, `0x3FFF_FFFC`), Gap 2 (`0x4001_0000`, `0xFFFF_FFFC`).
- **Primary Stimulus:** `VER-CORE-002`, `VER-CORE-003`, `VER-FAULT-001`, `VER-FAULT-006`.

### 2.4 `CG-IROM-PORTB` — Modified Harvard `irom_local` Port B `.rodata` Coverage
- **Sampling Point:** `irom_local` Port B read completion (`local_rd_valid && daddr_in_irom`) or ROM write fault.
- **Required Bins:**
  - `b_irom_lb_offsets`: `LB` at `addr[1:0] == 2'b00, 2'b01, 2'b10, 2'b11` x `{bit7==0, bit7==1}` (sign extension).
  - `b_irom_lbu_offsets`: `LBU` at `addr[1:0] == 2'b00, 2'b01, 2'b10, 2'b11` x `{bit7==1}` (zero extension).
  - `b_irom_lh_offsets`: `LH` at `addr[1:0] == 2'b00, 2'b10` x `{bit15==0, bit15==1}`.
  - `b_irom_lhu_offsets`: `LHU` at `addr[1:0] == 2'b00, 2'b10` x `{bit15==1}`.
  - `b_irom_lw`: `LW` at `addr[1:0] == 2'b00`.
  - `b_irom_ro_write`: `SB`, `SH`, `SW` targeting `IROM` (all 3 store widths raise `4'hA`).
- **Primary Stimulus:** `VER-CORE-002`, `VER-FAULT-007`.

### 2.5 `CG-DRAM-ACCESS` — `dram_local` (`Option RAM-B`) Timing & Byte-Lane Coverage
- **Sampling Point:** `dram_req` on `dram_local`.
- **Required Bins:**
  - `b_dram_sb_be`: `SB` covering `dram_be == 4'b0001`, `4'b0010`, `4'b0100`, `4'b1000` (and verifying unmasked neighbor bytes remain untouched).
  - `b_dram_sh_be`: `SH` covering `dram_be == 4'b0011`, `4'b1100` (and verifying unmasked neighbor halfword remains untouched).
  - `b_dram_sw_be`: `SW` with `dram_be == 4'b1111`.
  - `b_dram_loads`: `LB`, `LBU`, `LH`, `LHU`, `LW` across all valid `addr[1:0]` offsets + sign/zero extension.
  - `b_dram_b2b`: `DRAM` 2-cycle load immediately followed by `DRAM` 1-cycle store (`COV-SVA-007`), and `DRAM` store immediately followed by `DRAM` load.
- **Primary Stimulus:** `VER-CORE-002`.

### 2.6 `CG-APB3-PROTO` — APB3 Bus Protocol, Wait-State & Error Coverage
- **Sampling Point:** `apb3_bridge` boundary (`TB-CORE-BUS` with Mock APB3 Completers) & `data_bus_decode`.
- **Required Bins:**
  - `b_apb_slot_dir`: Cross `{PSEL_UART, PSEL_GPIO, PSEL_TIMER}` x `{Read (LW), Write (SW)}`.
  - `b_apb_waits`: Wait-state duration in `ACCESS` (`PREADY == 0` cycles before `PREADY == 1`): `{0, 1, 2, 5, 16}` cycles for both reads and writes.
  - `b_apb_slverr`: `PSLVERR == 1` at `ACCESS && PREADY == 1` for both `LW` (0-wait & multi-wait) and `SW` (0-wait & multi-wait).
  - `b_apb_slverr_ignored`: `PSLVERR == 1` while `PREADY == 0`, dropping to `PSLVERR == 0` when `PREADY == 1` (`COV-SVA-004`).
  - `b_apb_b2b`: Back-to-back APB3 `SW -> LW` across same and different slots.
  - `b_apb_fence`: `FENCE` immediately following APB3 transfer (`COV-SVA-008`).
  - `b_apb_w1_reject`: Sub-word `{LB, LBU, LH, LHU, SB, SH}` targeting populated APB3 slots (`FAULT_DATA_SIZE_UNSUP`).
- **Primary Stimulus:** `VER-CORE-003`, `VER-BUS-001`, `VER-FAULT-008`, `VER-FAULT-010`.

### 2.7 `CG-FAULT-CODES` & `CG-FAULT-PRIO` — Fault-and-Halt Coverage
- **Sampling Point:** `fault_o` / `fault_code_o` at `soc_top`.
- **Required Bins (`CG-FAULT-CODES`):**
  - `b_fc_0`: `4'h0` (`FAULT_NONE` during normal execution)
  - `b_fc_1`: `4'h1` (`FAULT_IF_MISALIGNED` via `JALR` to `pc[1:0]==2'b10`, plus taken branch / `JAL` check if applicable)
  - `b_fc_2`: `4'h2` (`FAULT_IF_UNMAPPED` targeting Gap 0, `DRAM`, `APB3`)
  - `b_fc_3`: `4'h3` (`FAULT_ILLEGAL_INSN`: `0x0000_0000`, `0xFFFF_FFFF`, `CSRRW`, `MRET`, `MUL`, `FENCE.I`)
  - `b_fc_4`: `4'h4` (`FAULT_ECALL`)
  - `b_fc_5`: `4'h5` (`FAULT_EBREAK`)
  - `b_fc_6`: `4'h6` (`FAULT_DATA_MISALIGNED` across `IROM` `LH/LHU/LW`, `DRAM` `LH/LHU/LW/SH/SW`, `APB3` `LW/SW` with offsets `1, 2, 3`)
  - `b_fc_7`: `4'h7` (`FAULT_DATA_UNMAPPED` across Gaps 0/1/2 and reserved APB slots `0x4000_3000..FFFF`)
  - `b_fc_8`: `4'h8` (`FAULT_DATA_SIZE_UNSUP` across `LB/LBU/LH/LHU/SB/SH` on APB3 slots 0/1/2)
  - `b_fc_9`: `4'h9` (`FAULT_APB_SLVERR` on `LW` and `SW`)
  - `b_fc_A`: `4'hA` (`FAULT_DATA_RO_WRITE` across `SB`, `SH`, `SW` on `IROM`)
  - `b_fc_illegal`: `4'hB..4'hF` (`illegal_bins` — must never occur)
- **Required Bins (`CG-FAULT-PRIO`):**
  - `b_prio_if`: `FAULT_IF_UNMAPPED` + `FAULT_IF_MISALIGNED` (`0x0000_8002`) -> `4'h2`
  - `b_prio_unmapped_ro`: `FAULT_DATA_UNMAPPED` + misaligned (`0x0000_8001` store) -> `4'h7`
  - `b_prio_unmapped_apb`: `FAULT_DATA_UNMAPPED` + sub-word + misaligned (`0x4000_3001` `SH`) -> `4'h7`
  - `b_prio_ro_align`: `FAULT_DATA_RO_WRITE` + misaligned (`0x0000_0102` `SW`, `0x0000_0101` `SH`) -> `4'hA`
  - `b_prio_size_align`: `FAULT_DATA_SIZE_UNSUP` + misaligned (`0x4000_0001` `LH`, `0x4000_1003` `SH`) -> `4'h8`
  - `b_prio_sticky`: Second fault stimulus while already halted (`fault_o == 1`) does not alter `fault_code_o`/`fault_pc_o`.
- **Primary Stimulus:** `VER-FAULT-001` through `VER-FAULT-011`.

### 2.8 `CG-RESET` — Reset Synchronizer & Recovery Coverage
- **Sampling Point:** `rst_n`, `sys_rst_n`, and subsystem states.
- **Required Bins:**
  - `b_rst_cold`: External `rst_n` asserted asynchronously mid-cycle, held `>= 1` clock, released cleanly (`2-FF` sync).
  - `b_rst_during_apb_wait`: `rst_n` asserted during `ACCESS && !PREADY` (`COV-SVA-009`).
  - `b_rst_during_local_rd`: `rst_n` asserted during `C0` and `C1` (`local_rd_valid == 1`) of a local memory load.
  - `b_rst_from_fault`: `rst_n` asserted after `fault_o == 1`, verifying full recovery to `PC = 0x0000_0000` (`COV-SVA-010`).
- **Primary Stimulus:** `VER-RST-001`, `VER-RST-002`.

---

## 3. Coverage Closure Targets (`SOC_VB_001`)

| Category | Target | Blocking Status |
|---|---|---|
| Core Functional Coverage (`CG-RV32I-*`, `CG-ADDR-*`, `CG-IROM-*`, `CG-DRAM-*`, `CG-APB3-*`, `CG-FAULT-*`, `CG-RESET`) | **100%** of defined bins | Unblocked (ready for Gate 4/5) |
| SVA Cover Properties (`COV-SVA-001..010`) | **100%** hit (`>= 1` hit each) | Unblocked (ready for Gate 4/5) |
| Peripheral Register Coverage (`CG-UART-*`, `CG-GPIO-*`, `CG-TIMER-*`) | Deferred to `SOC_VB_002` | `BLOCKED (awaiting approved peripheral register-map contract)` |

---

## 4. `BLOCKED` Peripheral Register-Level Covergroups

| Covergroup ID | Peripheral | Blocked Bins | Status |
|---|---|---|---|
| `CG-UART-REG` | `uart_apb` | Register offset RW/RO access, baud divisor settings, 8N1 TX/RX data patterns (`0x00`, `0xFF`, `0x55`, `0xAA`), RX overrun, invalid offset `PSLVERR` | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `CG-GPIO-REG` | `gpio_apb` | Direction (`gpio_oe_o`) all-input/all-output/mixed masks, `gpio_o` walking 1s/0s, `gpio_i` input sampling, invalid offset `PSLVERR` | `BLOCKED (awaiting approved peripheral register-map contract)` |
| `CG-TIMER-REG` | `timer_apb` | Counter enable/disable/reset, compare match at `0`, `1`, `0xFFFF_FFFF` wrap boundary, sticky status clear, invalid offset `PSLVERR` | `BLOCKED (awaiting approved peripheral register-map contract)` |
