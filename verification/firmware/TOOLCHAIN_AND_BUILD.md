# Verification Firmware Toolchain and Build Specification

- **Document ID:** `VER-BUILD-001`
- **Baseline ID:** `SOC_VB_001`
- **Status:** `APPROVED / FROZEN (DEC-VER-BASELINE-001)`
- **Date:** 2026-11-27
- **Approved Decision:** [DEC-VER-BASELINE-001.md](file:///mnt/e/PB/Projects/Microcontroller/docs/decisions/DEC-VER-BASELINE-001.md)
- **Author:** Independent Verification Engineer Agent
- **Contract Authority:** `CON-ADDR-001` v1.1, `CON-MEM-001` v1.1, `CON-FLT-RST-001` v1.1

---

## 1. Host Environment Inspection Result

Checked on `2026-11-27` via `which` and `--version`:
- `riscv32-unknown-elf-gcc` / `riscv64-unknown-elf-gcc` / `riscv-none-elf-gcc`: **NOT INSTALLED**
- `verilator`: `Verilator 5.032 2025-01-01 rev (Debian 5.032-1)` (installed at `/usr/bin/verilator`)
- `yosys`: `Yosys 0.52` (installed at `/usr/bin/yosys`)
- `python3`: `Python 3.14.4` (installed at `/usr/bin/python3`)
- **Firmware Build Execution Status:** **`NOT_RUN / BLOCKED (awaiting RISC-V bare-metal GNU toolchain installation)`**. No `.elf`, `.bin`, `.mem`, or SHA-256 digests were fabricated.

---

## 2. Required RISC-V Bare-Metal Toolchain

Install either of the following standard multilib / RV32I bare-metal GNU toolchains before Gate 4/5 simulation:
1. **Preferred:** `riscv64-unknown-elf-gcc` (Debian/Ubuntu `gcc-riscv64-unknown-elf` + `binutils-riscv64-unknown-elf` + `picolibc-riscv64-unknown-elf` or bare-metal `-nostdlib`), invoked with `-march=rv32i -mabi=ilp32` (or `-march=rv32i_zicsr` disallowed; strictly **`rv32i`**!).
2. **Alternative:** `riscv32-unknown-elf-gcc` or xPack `riscv-none-elf-gcc` (`CROSS_COMPILE=riscv32-unknown-elf-` or `riscv-none-elf-`).

*(Note on ISA strictness: Per `SOC_SPECIFICATION_DRAFT.md` §3 and `CON-FLT-RST-001`, only base `RV32I` is implemented. Do NOT enable `M`, `C`, `A`, `F`, or `Zicsr` in compiler flags except where a negative fault test explicitly emits raw `.word` opcodes for illegal-instruction testing.)*

---

## 3. Exact Compiler, Linker, and Image-Conversion Flow

### 3.1 Compiler & Assembler Flags
- **Architecture / ABI:** `-march=rv32i -mabi=ilp32`
- **Bare-Metal / Free-Standing:** `-ffreestanding -nostdlib -nostartfiles -fno-builtin -mcmodel=medlow`
- **Optimization & Debug:** `-O2 -g -Wall -Wextra -Werror`
- **Assembly Preprocessor:** `-x assembler-with-cpp -Iinclude` (supports `#define SUBCASE ...` and `verif_mailbox.inc`)
- **Linker Flags:** `-T link.ld -Wl,--gc-sections -Wl,-Map=<out>.map`

### 3.2 Memory Layout & Linker Script (`link.ld`)
- **`IROM` (`rx`):** `0x0000_0000` – `0x0000_7FFF` (`32 KB`).
  - Contains `.text.init` (reset vector at `0x0000_0000`), `.text`, and **`.rodata`** (placed in `IROM` per Modified Harvard `DEC-ARCH-CORE-001`, accessed via `irom_local` Port B).
  - For C programs with writable initialized globals (`.data`), LMA is placed in `IROM` (`AT > IROM`) and copied to `DRAM` VMA by `crt0.S`.
- **`DRAM` (`rw`):** `0x2000_0000` – `0x2000_7FFF` (`32 KB`).
  - Contains `.data`, `.bss`, stack (`_stack_top = 0x2000_7E00` growing downward), and a reserved 256-byte **Verification Signature Mailbox** at `0x2000_7F00`–`0x2000_7FFF`.

### 3.3 ELF-to-`.mem` Conversion (`CON-MEM-001 §1.5`)
`irom_local` uses `$readmemh` on a 32-bit word array (`logic [31:0] mem [0:8191]`), little-endian byte order, 8 hex digits per line:
```bash
<CROSS_COMPILE>objcopy -O binary build/<test>.elf build/<test>.bin
python3 bin2mem.py build/<test>.bin build/<test>.mem --max-bytes 32768
sha256sum build/<test>.elf build/<test>.bin build/<test>.mem > build/<test>.sha256
```

### 3.4 Expected Build Commands & Image Record (Once Toolchain Is Installed)
```bash
cd verification/firmware
make all CROSS_COMPILE=riscv64-unknown-elf-
# Verify SHA-256 manifests recorded in build/*.sha256 before Gate 5 simulation
```
Record the exact `<CROSS_COMPILE>gcc --version` output and `build/*.sha256` digests in the Gate 4/5 regression run report (`regression/runs/`).
