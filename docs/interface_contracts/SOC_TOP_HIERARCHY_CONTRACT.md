# SoC Top-Level Hierarchy & Integration Contract

- **Contract ID:** `CON-TOP-001`
- **Version:** `v1.1`
- **Status:** `APPROVED (DEC-ARCH-CORE-001, DEC-ARCH-CORE-002)`
- **Date:** 2026-11-27
- **Parent Proposal:** [ARCHITECTURE_PROPOSAL_V1.md](file:///mnt/e/PB/Projects/Microcontroller/docs/architecture/ARCHITECTURE_PROPOSAL_V1.md)
- **Approved Decisions:** [DEC-ARCH-CORE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-001.md) (Decisions #1–#7), [DEC-ARCH-CORE-002.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-ARCH-CORE-002.md)

---

## 1. Module Hierarchy & Block Diagram (`UPDATED PER DEC-ARCH-CORE-001`)

```text
soc_top
 ├── rst_sync          (Async-assert, sync-deassert 2-FF reset synchronizer)
 ├── rv32i_cpu         (Single-cycle RV32I core + stall/hold + fault capture)
 ├── irom_local        (32 KB Instruction ROM: Port A IF + Port B RO data)
 ├── data_bus_decode   (Modified Harvard data decoder + fault check + local_rd_valid + mux)
 ├── dram_local        (32 KB Data RAM, Option RAM-B sync read / sync byte-enable write)
 ├── apb3_bridge       (APB3 Requester FSM: IDLE -> SETUP -> ACCESS, PSELx decode)
 ├── uart_apb          (APB3 Completer Slot 0: 0x4000_0000..0x4000_0FFF)
 ├── gpio_apb          (APB3 Completer Slot 1: 0x4000_1000..0x4000_1FFF)
 └── timer_apb         (APB3 Completer Slot 2: 0x4000_2000..0x4000_2FFF)
```

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

## 2. Module Responsibilities

| Module | Role | Key Responsibilities |
|---|---|---|
| `soc_top` | Top-level SoC wrapper | Instantiates and wires clock, reset synchronizer, CPU, local memories, data decoder, APB3 bridge, and APB3 peripherals; exposes external SoC I/O and fault observability ports. |
| `rst_sync` | Reset synchronizer | Converts external `rst_n` into `sys_rst_n` / `PRESETn` (asynchronous assertion, 2-FF synchronous deassertion on `posedge clk`). |
| `rv32i_cpu` | Processor core | Implements RV32I ISA (`PC`, `32x32` RF with `x0=0`, decoder, ALU, comparator, imm gen), IF fault checks, decode fault checks, stall/hold on `dmem_stall`, and sticky fault capture. |
| `irom_local` | Instruction ROM | 32 KB read-only memory (`8192 x 32b`), initialized from `.hex`/`.mem` (`INIT_FILE`). Port A: 0-cycle combinational IF read; Port B: 1-cycle synchronous read-only data port for `.rodata`. |
| `data_bus_decode` | Data path decoder/arbiter | Decodes `daddr` across `IROM` (RO), `DRAM` (RW), populated `APB3` slots (RW), and unmapped space; enforces store-to-ROM, width, and alignment fault checks; manages `local_rd_valid` 2-cycle read handshake (`DRAM` & `IROM` Port B); muxes `dmem_rdata`, `dmem_stall`, and data/bus faults back to CPU. |
| `dram_local` | Data RAM | 32 KB read/write memory (`8192 x 32b`), dedicated local interface (`Option RAM-B`: 1-cycle synchronous read, 1-cycle synchronous `dram_be[3:0]` byte-enabled write). |
| `apb3_bridge` | APB3 Requester | Implements ARM `IHI0024E` APB3 FSM (`IDLE -> SETUP -> ACCESS`), drives registered `PADDR/PSELx/PENABLE/PWRITE/PWDATA`, waits on `PREADY`, forwards `PRDATA` and `PSLVERR`. |
| `uart_apb` | UART peripheral | APB3 Completer in Slot 0; 8N1 UART, 115200 default baud @ 50 MHz, programmable divisor. *(Register map deferred.)* |
| `gpio_apb` | GPIO peripheral | APB3 Completer in Slot 1; 8-bit I/O with per-bit direction control. *(Register map deferred.)* |
| `timer_apb` | Timer peripheral | APB3 Completer in Slot 2; 32-bit counter + programmable compare. *(Register map deferred.)* |

---

## 3. Top-Level `soc_top` Port List (`APPROVED — DEC-ARCH-CORE-001`)

| Port Name | Width | Direction | Polarity / Type | Description |
|---|---:|---|---|---|
| `clk` | 1 | Input | 50 MHz clock | Single shared SoC clock (`D5`). |
| `rst_n` | 1 | Input | Active-LOW | External asynchronous reset (`G2`). |
| `uart_rx_i` | 1 | Input | Active-HIGH/idle-HIGH | UART serial receive input pin. |
| `uart_tx_o` | 1 | Output | Active-HIGH/idle-HIGH | UART serial transmit output pin (resets to `1`). |
| `gpio_i` | 8 | Input | Pin input | External GPIO input state sampled by `gpio_apb`. |
| `gpio_o` | 8 | Output | Pin output | Driven GPIO output data from `gpio_apb`. |
| `gpio_oe_o` | 8 | Output | Active-HIGH enable | Per-bit GPIO output enable (`0` = input, `1` = output; resets to `8'h00`). |
| `fault_o` | 1 | Output | Active-HIGH | Visible SoC fault/halt indicator (`fault_valid`). |
| `fault_code_o` | 4 | Output | Encoded | Visible 4-bit `fault_code` (`4'h0` = no fault). |
| `fault_pc_o` | 32 | Output | Observability | Exposes `fault_pc` at `soc_top` for testbench/SVA inspection. |
| `fault_addr_o` | 32 | Output | Observability | Exposes `fault_addr` at `soc_top`. |
| `fault_insn_o` | 32 | Output | Observability | Exposes `fault_insn` at `soc_top`. |

---

## 4. Internal `rv32i_cpu` <-> `data_bus_decode` Interface (`UPDATED PER DEC-ARCH-CORE-001`)

| Signal | Width | Direction (wrt `rv32i_cpu`) | Description |
|---|---:|---|---|
| `dmem_req` | 1 | Output | `1` when CPU decodes a valid `LOAD` or `STORE` opcode (and no IF/decode fault, `!fault_valid`, `sys_rst_n`). |
| `dmem_we` | 1 | Output | `1` = Store, `0` = Load. |
| `dmem_size` | 2 | Output | `2'b00` = Byte (`LB/LBU/SB`), `2'b01` = Halfword (`LH/LHU/SH`), `2'b10` = Word (`LW/SW`). |
| `dmem_addr` | 32 | Output | Effective byte address `rs1 + imm`. |
| `dmem_wdata` | 32 | Output | Raw `rs2` data (byte/halfword lane alignment handled by `data_bus_decode` for `DRAM`). |
| `dmem_rdata` | 32 | Input | Raw 32-bit word returned from `irom_local` (Port B), `dram_local`, or `apb3_bridge` (CPU performs `LB/LBU/LH/LHU` slicing & sign/zero-extension). |
| `dmem_stall` | 1 | Input | Unified stall signal (`(local_read_stall || apb_stall) && !fault_valid`): `1` during `C0` of any synchronous local load (`DRAM` or `IROM` Port B) and while any APB3 transfer is pending (`IDLE`/`SETUP`/`ACCESS` with `!PREADY`). |
| `dmem_fault_valid` | 1 | Input | `1` if `data_bus_decode` or `apb3_bridge` detects a data/bus fault. |
| `dmem_fault_code` | 4 | Input | `FAULT_DATA_UNMAPPED`, `FAULT_DATA_RO_WRITE`, `FAULT_DATA_SIZE_UNSUP`, `FAULT_DATA_MISALIGNED`, or `FAULT_APB_SLVERR`. |

---

## 5. Integration Dependencies & Sequencing

1. **Core Architecture Frozen (`DEC-ARCH-CORE-001`, `DEC-ARCH-CORE-002`):** All core contracts (`CON-ADDR-001`, `CON-MEM-001`, `CON-APB3-001`, `CON-FLT-RST-001`, `CON-TOP-001`) are approved.
2. **Next Architecture Task:** Focused peripheral register-map specification for `uart_apb`, `gpio_apb`, and `timer_apb` (register offsets within each 4 KB slot, bit fields, reset values, polling flags, `PSLVERR` conditions, and external pin synchronizer timing).
3. **Verification Plan & Baseline:** Independent Verification Engineer derives verification plan, SVA specification, coverage plan, and core verification firmware from the approved core contracts (peripheral-register verification remains blocked until peripheral register maps are approved).
4. **RTL Implementation (Gate 2):** Only after human approval of contracts and verification baseline.
