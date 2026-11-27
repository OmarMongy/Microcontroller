#!/usr/bin/env python3
"""Gate 5 Reproducible Simulation Regression Runner (SOC_VB_001.1 & SOC_VB_002).

Compiles Vtb_core_bus and Vtb_soc_top with Verilator --binary --assert --timing,
extracts exact symbol addresses & instruction words from .elf/.mem files,
executes all core and peripheral verification tests, aggregates coverage,
records logs, and cleans up temporary obj_dir_* directories.
"""

import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys
from typing import Dict, List, Optional, Tuple


ROOT = pathlib.Path(__file__).resolve().parent.parent
FW_BUILD = ROOT / "verification" / "firmware" / "build"

RTL_FILES = [str(ROOT / line.strip()) for line in (ROOT / "rtl" / "rtl.f").read_text().splitlines() if line.strip()]
SVA_FILES = [
    str(ROOT / "sva" / "sva_apb3_if.sv"),
    str(ROOT / "sva" / "sva_mem_if.sv"),
    str(ROOT / "sva" / "sva_cpu_fault_rst.sv"),
    str(ROOT / "sva" / "sva_periph_if.sv"),
    str(ROOT / "sva" / "sva_binds.sv"),
]


def get_elf_symbols(elf_path: pathlib.Path) -> Dict[str, int]:
    out = subprocess.check_output(["riscv64-unknown-elf-nm", str(elf_path)], text=True)
    syms: Dict[str, int] = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3:
            syms[parts[2]] = int(parts[0], 16)
    return syms


def get_mem_word(mem_path: pathlib.Path, byte_addr: int) -> int:
    words = mem_path.read_text().splitlines()
    idx = (byte_addr & 0x7FFF) >> 2
    return int(words[idx], 16) if idx < len(words) else 0


def build_sim(top: str, tb_files: List[str], mdir: pathlib.Path, extra_flags: List[str]) -> pathlib.Path:
    cmd = [
        "verilator",
        "--binary",
        "--assert",
        "--timing",
        "--public-flat-rw",
        "-j",
        "4",
        "-Wno-DECLFILENAME",
        "--Mdir",
        str(mdir),
        "--top-module",
        top,
        *extra_flags,
        *RTL_FILES,
        *tb_files,
        *SVA_FILES,
    ]
    res = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stdout)
        print(res.stderr, file=sys.stderr)
        raise RuntimeError(f"Verilator build failed for {top}")
    return mdir / f"V{top}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=pathlib.Path, default=ROOT / "regression" / "runs" / "RUN-GATE5-001.log")
    parser.add_argument("--keep-obj", action="store_true")
    args = parser.parse_args()

    obj_core = ROOT / "obj_dir_gate5_core_bus"
    obj_top = ROOT / "obj_dir_gate5_soc_top"
    args.log.parent.mkdir(parents=True, exist_ok=True)

    log_lines: List[str] = []

    def log(msg: str) -> None:
        print(msg)
        log_lines.append(msg)

    try:
        log("=== Compiling Vtb_core_bus & Vtb_soc_top (Verilator --binary --assert --timing) ===")
        bin_core = build_sim(
            "tb_core_bus",
            [
                str(ROOT / "tb" / "tb_pkg.sv"),
                str(ROOT / "tb" / "mock_apb_completer.sv"),
                str(ROOT / "tb" / "rv32i_golden_iss.sv"),
                str(ROOT / "tb" / "tb_cov_collector.sv"),
                str(ROOT / "tb" / "tb_core_bus.sv"),
            ],
            obj_core,
            [],
        )
        bin_top = build_sim(
            "tb_soc_top",
            [
                str(ROOT / "tb" / "tb_pkg.sv"),
                str(ROOT / "tb" / "rv32i_golden_iss.sv"),
                str(ROOT / "tb" / "tb_cov_collector.sv"),
                str(ROOT / "tb" / "tb_soc_top.sv"),
            ],
            obj_top,
            ["-DSVA_ENABLE_INTERNAL_BINDS"],
        )

        # (test_id, harness_bin, fw_stem, exp_fault, exp_status, exp_pc_sym_or_val, exp_addr, check_insn, plusargs)
        tests: List[Tuple[str, pathlib.Path, str, int, int, Optional[object], Optional[int], bool, List[str]]] = [
            # Core normal tests (SOC_VB_001.1)
            ("VER-CORE-001", bin_top, "VER_CORE_001", 5, 0xCAFE0001, "ver_core_001_pass_ebreak", 0, True, []),
            ("VER-CORE-002", bin_top, "VER_CORE_002", 5, 0xCAFE0001, "ver_core_002_pass_ebreak", 0, True, []),
            ("VER-CORE-003_w0", bin_core, "VER_CORE_003", 5, 0xCAFE0001, "ver_core_003_pass_ebreak", 0, False, ["+APB_WAITS=0"]),
            ("VER-CORE-003_w1", bin_core, "VER_CORE_003", 5, 0xCAFE0001, "ver_core_003_pass_ebreak", 0, False, ["+APB_WAITS=1"]),
            ("VER-CORE-003_w2", bin_core, "VER_CORE_003", 5, 0xCAFE0001, "ver_core_003_pass_ebreak", 0, False, ["+APB_WAITS=2"]),
            ("VER-CORE-003_w5", bin_core, "VER_CORE_003", 5, 0xCAFE0001, "ver_core_003_pass_ebreak", 0, False, ["+APB_WAITS=5"]),
            ("VER-BUS-001_w16_glitch", bin_core, "VER_CORE_003", 5, 0xCAFE0001, "ver_core_003_pass_ebreak", 0, False, ["+APB_WAITS=16", "+GLITCH_SLVERR=1"]),
            ("VER-CORE-004", bin_core, "VER_CORE_004", 5, 0xCAFE0001, "ver_core_004_done_ebreak", 0, False, ["+APB_WAITS=1"]),
            # Fault tests (SOC_VB_001.1)
            ("VER-FAULT-001_sub0", bin_top, "VER_FAULT_001_sub0", 2, 0xAAAA0001, 0x00008000, 0x00008000, False, []),
            ("VER-FAULT-001_sub1", bin_top, "VER_FAULT_001_sub1", 2, 0xAAAA0001, 0x20000000, 0x20000000, False, []),
            ("VER-FAULT-001_sub2", bin_top, "VER_FAULT_001_sub2", 2, 0xAAAA0001, 0x40000000, 0x40000000, False, []),
            ("VER-FAULT-002_sub0", bin_top, "VER_FAULT_002_sub0", 1, 0xAAAA0001, 0x00000202, 0x00000202, False, []),
            ("VER-FAULT-002_sub1", bin_top, "VER_FAULT_002_sub1", 1, 0xAAAA0001, 0x00000202, 0x00000202, False, []),
            ("VER-FAULT-003_sub0", bin_top, "VER_FAULT_003_sub0", 3, 0xAAAA0001, "fault_trigger_pc", 0, True, []),
            ("VER-FAULT-003_sub1", bin_top, "VER_FAULT_003_sub1", 3, 0xAAAA0001, "fault_trigger_pc", 0, True, []),
            ("VER-FAULT-003_sub2", bin_top, "VER_FAULT_003_sub2", 3, 0xAAAA0001, "fault_trigger_pc", 0, True, []),
            ("VER-FAULT-003_sub3", bin_top, "VER_FAULT_003_sub3", 3, 0xAAAA0001, "fault_trigger_pc", 0, True, []),
            ("VER-FAULT-003_sub4", bin_top, "VER_FAULT_003_sub4", 3, 0xAAAA0001, "fault_trigger_pc", 0, True, []),
            ("VER-FAULT-003_sub5", bin_top, "VER_FAULT_003_sub5", 3, 0xAAAA0001, "fault_trigger_pc", 0, True, []),
            ("VER-FAULT-004_sub0", bin_top, "VER_FAULT_004_sub0", 4, 0xAAAA0001, "fault_trigger_pc", 0, True, []),
            ("VER-FAULT-005_sub0", bin_top, "VER_FAULT_005_sub0", 5, 0xAAAA0001, "fault_trigger_pc", 0, True, []),
            ("VER-FAULT-006_sub0", bin_top, "VER_FAULT_006_sub0", 7, 0xAAAA0001, "fault_trigger_pc", 0x00008000, True, []),
            ("VER-FAULT-006_sub1", bin_top, "VER_FAULT_006_sub1", 7, 0xAAAA0001, "fault_trigger_pc", 0x1FFFFFFC, True, []),
            ("VER-FAULT-006_sub2", bin_top, "VER_FAULT_006_sub2", 7, 0xAAAA0001, "fault_trigger_pc", 0x20008000, True, []),
            ("VER-FAULT-006_sub3", bin_top, "VER_FAULT_006_sub3", 7, 0xAAAA0001, "fault_trigger_pc", 0x40003000, True, []),
            ("VER-FAULT-006_sub4", bin_top, "VER_FAULT_006_sub4", 7, 0xAAAA0001, "fault_trigger_pc", 0x4000FFFC, True, []),
            ("VER-FAULT-006_sub5", bin_top, "VER_FAULT_006_sub5", 7, 0xAAAA0001, "fault_trigger_pc", 0x40010000, True, []),
            ("VER-FAULT-007_sub0", bin_top, "VER_FAULT_007_sub0", 10, 0xAAAA0001, "fault_trigger_pc", 0x00000000, True, []),
            ("VER-FAULT-007_sub1", bin_top, "VER_FAULT_007_sub1", 10, 0xAAAA0001, "fault_trigger_pc", 0x00000200, True, []),
            ("VER-FAULT-007_sub2", bin_top, "VER_FAULT_007_sub2", 10, 0xAAAA0001, "fault_trigger_pc", 0x00007FFF, True, []),
            ("VER-FAULT-008_sub0", bin_top, "VER_FAULT_008_sub0", 8, 0xAAAA0001, "fault_trigger_pc", 0x40000000, True, []),
            ("VER-FAULT-008_sub1", bin_top, "VER_FAULT_008_sub1", 8, 0xAAAA0001, "fault_trigger_pc", 0x40001000, True, []),
            ("VER-FAULT-008_sub2", bin_top, "VER_FAULT_008_sub2", 8, 0xAAAA0001, "fault_trigger_pc", 0x40002000, True, []),
            ("VER-FAULT-008_sub3", bin_top, "VER_FAULT_008_sub3", 8, 0xAAAA0001, "fault_trigger_pc", 0x40000004, True, []),
            ("VER-FAULT-008_sub4", bin_top, "VER_FAULT_008_sub4", 8, 0xAAAA0001, "fault_trigger_pc", 0x40001004, True, []),
            ("VER-FAULT-008_sub5", bin_top, "VER_FAULT_008_sub5", 8, 0xAAAA0001, "fault_trigger_pc", 0x40002004, True, []),
            ("VER-FAULT-009_sub0", bin_top, "VER_FAULT_009_sub0", 6, 0xAAAA0001, "fault_trigger_pc", 0x00000201, True, []),
            ("VER-FAULT-009_sub1", bin_top, "VER_FAULT_009_sub1", 6, 0xAAAA0001, "fault_trigger_pc", 0x00000202, True, []),
            ("VER-FAULT-009_sub2", bin_top, "VER_FAULT_009_sub2", 6, 0xAAAA0001, "fault_trigger_pc", 0x20000003, True, []),
            ("VER-FAULT-009_sub3", bin_top, "VER_FAULT_009_sub3", 6, 0xAAAA0001, "fault_trigger_pc", 0x20000001, True, []),
            ("VER-FAULT-009_sub4", bin_top, "VER_FAULT_009_sub4", 6, 0xAAAA0001, "fault_trigger_pc", 0x20000001, True, []),
            ("VER-FAULT-009_sub5", bin_top, "VER_FAULT_009_sub5", 6, 0xAAAA0001, "fault_trigger_pc", 0x20000003, True, []),
            ("VER-FAULT-009_sub6", bin_top, "VER_FAULT_009_sub6", 6, 0xAAAA0001, "fault_trigger_pc", 0x40000002, True, []),
            ("VER-FAULT-010_sub0_w0", bin_core, "VER_FAULT_010_sub0", 9, 0xAAAA0001, "fault_trigger_pc", 0x40000000, False, ["+INJECT_SLVERR=1", "+APB_WAITS=0"]),
            ("VER-FAULT-010_sub0_w2", bin_core, "VER_FAULT_010_sub0", 9, 0xAAAA0001, "fault_trigger_pc", 0x40000000, False, ["+INJECT_SLVERR=1", "+APB_WAITS=2"]),
            ("VER-FAULT-010_sub1_w1", bin_core, "VER_FAULT_010_sub1", 9, 0xAAAA0001, "fault_trigger_pc", 0x40001000, False, ["+INJECT_SLVERR=1", "+APB_WAITS=1"]),
            ("VER-FAULT-011_sub0", bin_top, "VER_FAULT_011_sub0", 2, 0xAAAA0001, 0x00008002, 0x00008002, False, []),
            ("VER-FAULT-011_sub1", bin_top, "VER_FAULT_011_sub1", 7, 0xAAAA0001, "fault_trigger_pc", 0x00008001, True, []),
            ("VER-FAULT-011_sub2", bin_top, "VER_FAULT_011_sub2", 7, 0xAAAA0001, "fault_trigger_pc", 0x40003001, True, []),
            ("VER-FAULT-011_sub3", bin_top, "VER_FAULT_011_sub3", 10, 0xAAAA0001, "fault_trigger_pc", 0x00000102, True, []),
            ("VER-FAULT-011_sub4", bin_top, "VER_FAULT_011_sub4", 8, 0xAAAA0001, "fault_trigger_pc", 0x40000001, True, []),
            # Reset tests
            ("VER-RST-002_apb_wait", bin_core, "VER_CORE_003", 5, 0xCAFE0001, "ver_core_003_pass_ebreak", 0, False, ["+APB_WAITS=5", "+RST_DURING_APB=1"]),
            ("VER-RST-002_local_rd", bin_top, "VER_CORE_002", 5, 0xCAFE0001, "ver_core_002_pass_ebreak", 0, True, ["+RST_DURING_LD=1"]),
            ("VER-RST-002_from_fault", bin_top, "VER_FAULT_004_sub0", 4, 0xAAAA0001, "fault_trigger_pc", 0, True, ["+RESET_RECOVERY=1"]),
            # Peripheral tests (SOC_VB_002)
            ("VER-UART-001", bin_top, "VER_UART_001", 5, 0xCAFE0001, "ver_uart_001_pass_ebreak", 0, True, ["+UART_BAUD_DIV=16"]),
            ("VER-UART-002_sub0", bin_top, "VER_UART_002_sub0", 9, 0xAAAA0001, "fault_trigger_pc", 0x40000008, True, []),
            ("VER-UART-002_sub1", bin_top, "VER_UART_002_sub1", 9, 0xAAAA0001, "fault_trigger_pc", 0x4000000C, True, []),
            ("VER-UART-002_sub2", bin_top, "VER_UART_002_sub2", 9, 0xAAAA0001, "fault_trigger_pc", 0x40000010, True, []),
            ("VER-UART-002_sub3", bin_top, "VER_UART_002_sub3", 9, 0xAAAA0001, "fault_trigger_pc", 0x40000010, True, []),
            ("VER-UART-002_sub4", bin_top, "VER_UART_002_sub4", 9, 0xAAAA0001, "fault_trigger_pc", 0x40000014, True, []),
            ("VER-GPIO-001", bin_top, "VER_GPIO_001", 5, 0xCAFE0001, "ver_gpio_001_pass_ebreak", 0, True, ["+GPIO_MODE=1"]),
            ("VER-GPIO-002_sub0", bin_top, "VER_GPIO_002_sub0", 9, 0xAAAA0001, "fault_trigger_pc", 0x40001000, True, []),
            ("VER-GPIO-002_sub1", bin_top, "VER_GPIO_002_sub1", 9, 0xAAAA0001, "fault_trigger_pc", 0x4000100C, True, []),
            ("VER-GPIO-002_sub2", bin_top, "VER_GPIO_002_sub2", 9, 0xAAAA0001, "fault_trigger_pc", 0x40001FFC, True, []),
            ("VER-TIMER-001", bin_top, "VER_TIMER_001", 5, 0xCAFE0001, "ver_timer_001_pass_ebreak", 0, True, []),
            ("VER-TIMER-002_sub0", bin_top, "VER_TIMER_002_sub0", 9, 0xAAAA0001, "fault_trigger_pc", 0x40002010, True, []),
            ("VER-TIMER-002_sub1", bin_top, "VER_TIMER_002_sub1", 9, 0xAAAA0001, "fault_trigger_pc", 0x40002FFC, True, []),
            ("VER-PERIPH-INT-001", bin_top, "VER_PERIPH_INT_001", 5, 0xCAFE0001, "ver_periph_int_001_done_ebreak", 0, True, ["+UART_BAUD_DIV=16", "+GPIO_MODE=1"]),
        ]

        passed = 0
        failed = 0
        sva_errors = 0
        cov_totals: Dict[str, int] = {}

        for tid, sim_bin, fw_stem, exp_flt, exp_sts, exp_pc_spec, exp_addr, chk_insn, extra in tests:
            elf_p = FW_BUILD / f"{fw_stem}.elf"
            mem_p = FW_BUILD / f"{fw_stem}.mem"
            syms = get_elf_symbols(elf_p)

            cmd = [
                str(sim_bin),
                f"+MEM_FILE={mem_p}",
                f"+EXP_FAULT={exp_flt}",
                f"+EXP_STATUS_HEX={exp_sts:08X}",
            ]
            if isinstance(exp_pc_spec, str):
                pc_val = syms[exp_pc_spec]
                cmd.append(f"+EXP_PC_HEX={pc_val:08X}")
                if chk_insn:
                    insn_val = get_mem_word(mem_p, pc_val)
                    cmd.append(f"+EXP_INSN_HEX={insn_val:08X}")
            elif isinstance(exp_pc_spec, int):
                cmd.append(f"+EXP_PC_HEX={exp_pc_spec:08X}")
                if chk_insn:
                    cmd.append("+EXP_INSN_HEX=00000000")

            if exp_addr is not None:
                cmd.append(f"+EXP_ADDR_HEX={exp_addr:08X}")
            cmd.extend(extra)

            res = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
            out_all = res.stdout + res.stderr

            # Separate SVA property errors (sva_* instances) from testbench $fatal errors
            sva_err_lines = [
                ln for ln in out_all.splitlines()
                if ("Assertion failed" in ln and ("u_sva_" in ln or "sva_" in ln))
            ]
            sva_errors += len(sva_err_lines)
            has_tb_err = bool(re.search(r"(%Fatal|%Error|FAIL:)", out_all))

            # Aggregate tb_cov_collector metrics
            for k, v in re.findall(r"\b([A-Za-z0-9_+]+)=(\d+)\b", out_all):
                if k not in ("testid", "retires", "rc"):
                    cov_totals[k] = cov_totals.get(k, 0) + int(v)
            for m in re.finditer(r"BE=\{0001:(\d+),0010:(\d+),0100:(\d+),1000:(\d+),0011:(\d+),1100:(\d+),1111:(\d+)\}", out_all):
                for idx, be in enumerate(["0001", "0010", "0100", "1000", "0011", "1100", "1111"], start=1):
                    cov_totals[f"BE_{be}"] = cov_totals.get(f"BE_{be}", 0) + int(m.group(idx))
            for m in re.finditer(r"WAITS=\{0:(\d+),1:(\d+),2\+:(\d+)\}", out_all):
                for idx, w in enumerate(["WAIT_0", "WAIT_1", "WAIT_2PLUS"], start=1):
                    cov_totals[w] = cov_totals.get(w, 0) + int(m.group(idx))
            for m in re.finditer(r"FAULTS: 1=(\d+) 2=(\d+) 3=(\d+) 4=(\d+) 5=(\d+) 6=(\d+) 7=(\d+) 8=(\d+) 9=(\d+) A=(\d+)", out_all):
                for idx, fc in enumerate(["1", "2", "3", "4", "5", "6", "7", "8", "9", "A"], start=1):
                    cov_totals[f"FAULT_{fc}"] = cov_totals.get(f"FAULT_{fc}", 0) + int(m.group(idx))
            for m in re.finditer(r"PERIPH_REGS: UART=\{(\d+),(\d+),(\d+),(\d+),(\d+)\} GPIO=\{(\d+),(\d+),(\d+)\} TIMER=\{(\d+),(\d+),(\d+),(\d+)\}", out_all):
                names = [
                    "UART_CTRL", "UART_STATUS", "UART_TX", "UART_RX", "UART_BAUD",
                    "GPIO_IN", "GPIO_OUT", "GPIO_DIR",
                    "TMR_CTRL", "TMR_STATUS", "TMR_CNT", "TMR_CMP",
                ]
                for idx, nm in enumerate(names, start=1):
                    cov_totals[nm] = cov_totals.get(nm, 0) + int(m.group(idx))

            if res.returncode == 0 and not has_tb_err and len(sva_err_lines) == 0 and ("PASS:" in out_all):
                passed += 1
                pass_line = [ln for ln in out_all.splitlines() if "PASS:" in ln][-1]
                log(f"[PASS] {tid:24s} | {pass_line}")
            else:
                failed += 1
                log(f"[FAIL] {tid:24s} | rc={res.returncode}")
                log(out_all.strip())

        log("=== AGGREGATED FUNCTIONAL COVERAGE SUMMARY ===")
        log(
            "RV32I: "
            + " ".join(f"{k}={cov_totals.get(k, 0)}" for k in [
                "LUI", "AUIPC", "JAL", "JALR", "BR", "LD", "ST", "ALUI", "ALUR", "FENCE", "X0_DST"
            ])
        )
        log(
            "MEM: "
            + " ".join(f"{k}={cov_totals.get(k, 0)}" for k in [
                "IROM_RD", "DRAM_RD", "DRAM_WR",
                "BE_0001", "BE_0010", "BE_0100", "BE_1000", "BE_0011", "BE_1100", "BE_1111"
            ])
        )
        log(
            "APB3: "
            + " ".join(f"{k}={cov_totals.get(k, 0)}" for k in [
                "UART", "GPIO", "TIMER", "WAIT_0", "WAIT_1", "WAIT_2PLUS", "SLVERR"
            ])
        )
        log(
            "FAULTS: "
            + " ".join(f"4'h{fc}={cov_totals.get(f'FAULT_{fc}', 0)}" for fc in [
                "1", "2", "3", "4", "5", "6", "7", "8", "9", "A"
            ])
        )
        log(f"RESET: DURING_STALL={cov_totals.get('DURING_STALL', 0)} FROM_FAULT={cov_totals.get('FROM_FAULT', 0)}")
        log(
            "PERIPH_REGS: "
            + " ".join(f"{k}={cov_totals.get(k, 0)}" for k in [
                "UART_CTRL", "UART_STATUS", "UART_TX", "UART_RX", "UART_BAUD",
                "GPIO_IN", "GPIO_OUT", "GPIO_DIR",
                "TMR_CTRL", "TMR_STATUS", "TMR_CNT", "TMR_CMP",
            ])
        )
        log(f"=== REGRESSION SUMMARY: PASSED={passed}, FAILED={failed}, SVA_ERRORS={sva_errors}, TOTAL={len(tests)} ===")
        args.log.write_text("\n".join(log_lines) + "\n", encoding="utf-8")
        return 0 if failed == 0 else 1

    finally:
        if not args.keep_obj:
            shutil.rmtree(obj_core, ignore_errors=True)
            shutil.rmtree(obj_top, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
