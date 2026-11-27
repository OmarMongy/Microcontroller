#!/usr/bin/env python3
"""Convert a little-endian raw RV32I binary into a 32-bit word .mem file for $readmemh.

Matches CON-MEM-001 v1.1 Section 1.5:
- One 32-bit hex word (8 uppercase hex digits) per line.
- Word 0 corresponds to byte offset 0x0000_0000.
- Little-endian byte packing: byte 0 = [7:0], byte 3 = [31:24].
"""

import argparse
import hashlib
import pathlib
import struct
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert .bin to 32-bit word .mem")
    parser.add_argument("input_bin", type=pathlib.Path)
    parser.add_argument("output_mem", type=pathlib.Path)
    parser.add_argument("--max-bytes", type=int, default=32768)
    args = parser.parse_args()

    data = args.input_bin.read_bytes()
    if len(data) > args.max_bytes:
        print(
            f"ERROR: {args.input_bin} ({len(data)} bytes) exceeds max {args.max_bytes} bytes",
            file=sys.stderr,
        )
        return 1

    # Pad tail to 4-byte word boundary with 0x00 (unprogrammed bytes = 0x00)
    rem = len(data) % 4
    if rem != 0:
        data += b"\x00" * (4 - rem)

    words = [struct.unpack_from("<I", data, off)[0] for off in range(0, len(data), 4)]
    args.output_mem.parent.mkdir(parents=True, exist_ok=True)
    args.output_mem.write_text("\n".join(f"{w:08X}" for w in words) + "\n", encoding="ascii")

    digest = hashlib.sha256(args.output_mem.read_bytes()).hexdigest()
    print(f"Generated {args.output_mem} ({len(words)} words, sha256={digest})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
