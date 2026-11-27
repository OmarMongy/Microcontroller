/* Test ID: VER-CORE-002
 * Requirements: CON-ADDR-001 §2, CON-MEM-001 §1 & §2 (Modified Harvard IROM Port B + DRAM Option RAM-B)
 * Purpose:
 *   1. Verify Modified Harvard IROM Port B 2-cycle synchronous .rodata loads
 *      (LB, LBU, LH, LHU, LW across byte/halfword offsets, sign/zero extension,
 *       immediate load-use dependency, and reading word 0x0000_0000).
 *   2. Verify DRAM Option RAM-B 1-cycle byte-enabled stores (SB/SH/SW) and
 *      2-cycle synchronous loads (LB/LBU/LH/LHU/LW), verifying little-endian
 *      byte ordering and preservation of unmasked neighbor bytes.
 *   3. Verify back-to-back DRAM store->load and load->store sequences.
 * Expected outcome:
 *   MBOX_TESTID_ADDR (0x2000_7F04) = 0x0000_0002
 *   MBOX_STATUS_ADDR (0x2000_7F00) = 0xCAFE_0001 (STATUS_PASS)
 *   fault_o = 1, fault_code_o = 4'h5 (FAULT_EBREAK), fault_pc_o = ver_core_002_pass_ebreak
 */

#include "verif_mailbox.inc"

    .section .text.init, "ax"
    .globl _start
_start:
    li      s1, 0

    /* Step 1: IROM Port B LW + immediate load-use dependency */
    li      t0, 1
    la      s0, rodata_pattern
    lw      t1, 0(s0)               /* 0x89AB_CDEF */
    addi    t2, t1, 1               /* immediate consumer after 2-cycle load */
    li      t3, 0x89ABCDF0
    bne     t2, t3, fail
    ori     s1, s1, 0x1

    /* Step 2: IROM Port B LB (signed) across offsets 0..3 of 0x89AB_CDEF */
    /* Byte 0 = 0xEF (-17), Byte 1 = 0xCD (-51), Byte 2 = 0xAB (-85), Byte 3 = 0x89 (-119) */
    li      t0, 2
    lb      t1, 0(s0)
    li      t2, 0xFFFFFFEF
    bne     t1, t2, fail
    lb      t1, 1(s0)
    li      t2, 0xFFFFFFCD
    bne     t1, t2, fail
    lb      t1, 2(s0)
    li      t2, 0xFFFFFFAB
    bne     t1, t2, fail
    lb      t1, 3(s0)
    li      t2, 0xFFFFFF89
    bne     t1, t2, fail
    /* Positive byte test on rodata_pattern + 4 = 0x7F12_8034 */
    lb      t1, 4(s0)               /* 0x34 */
    li      t2, 0x00000034
    bne     t1, t2, fail
    ori     s1, s1, 0x2

    /* Step 3: IROM Port B LBU (unsigned) across offsets 0..3 */
    li      t0, 3
    lbu     t1, 0(s0)
    li      t2, 0x000000EF
    bne     t1, t2, fail
    lbu     t1, 1(s0)
    li      t2, 0x000000CD
    bne     t1, t2, fail
    lbu     t1, 2(s0)
    li      t2, 0x000000AB
    bne     t1, t2, fail
    lbu     t1, 3(s0)
    li      t2, 0x00000089
    bne     t1, t2, fail
    ori     s1, s1, 0x4

    /* Step 4: IROM Port B LH & LHU across offsets 0 and 2 */
    li      t0, 4
    lh      t1, 0(s0)               /* 0xCDEF -> 0xFFFF_CDEF */
    li      t2, 0xFFFFCDEF
    bne     t1, t2, fail
    lh      t1, 2(s0)               /* 0x89AB -> 0xFFFF_89AB */
    li      t2, 0xFFFF89AB
    bne     t1, t2, fail
    lhu     t1, 0(s0)
    li      t2, 0x0000CDEF
    bne     t1, t2, fail
    lhu     t1, 2(s0)
    li      t2, 0x000089AB
    bne     t1, t2, fail
    lh      t1, 4(s0)               /* 0x8034 -> 0xFFFF_8034 */
    li      t2, 0xFFFF8034
    bne     t1, t2, fail
    lh      t1, 6(s0)               /* 0x7F12 -> 0x0000_7F12 (positive) */
    li      t2, 0x00007F12
    bne     t1, t2, fail
    ori     s1, s1, 0x8

    /* Step 5: IROM Port B boundary read at 0x0000_0000 (must match _start first insn) */
    li      t0, 5
    li      t1, IROM_BASE
    lw      t2, 0(t1)
    beq     t2, zero, fail          /* _start word 0 is `li s1, 0` (non-zero) */
    ori     s1, s1, 0x10

    /* Step 6: DRAM Option RAM-B SW + SB byte-lane preservation */
    li      t0, 6
    li      s2, DRAM_BASE           /* 0x2000_0000 */
    li      t1, 0x11223344
    sw      t1, 0(s2)               /* 1-cycle store */
    lw      t2, 0(s2)               /* immediate 2-cycle load (store->load) */
    bne     t2, t1, fail

    /* Overwrite byte 0, 1, 2, 3 individually with SB and verify neighbors intact */
    li      t3, 0xAA
    sb      t3, 0(s2)
    lw      t2, 0(s2)
    li      t4, 0x112233AA
    bne     t2, t4, fail

    li      t3, 0xBB
    sb      t3, 1(s2)
    lw      t2, 0(s2)
    li      t4, 0x1122BBAA
    bne     t2, t4, fail

    li      t3, 0xCC
    sb      t3, 2(s2)
    lw      t2, 0(s2)
    li      t4, 0x11CCBBAA
    bne     t2, t4, fail

    li      t3, 0xDD
    sb      t3, 3(s2)
    lw      t2, 0(s2)
    li      t4, 0xDDCCBBAA
    bne     t2, t4, fail
    ori     s1, s1, 0x20

    /* Step 7: DRAM SH halfword-lane preservation (offsets 0 and 2) */
    li      t0, 7
    li      t3, 0x7654
    sh      t3, 0(s2)
    lw      t2, 0(s2)
    li      t4, 0xDDCC7654
    bne     t2, t4, fail

    li      t3, 0x9810
    sh      t3, 2(s2)
    lw      t2, 0(s2)
    li      t4, 0x98107654
    bne     t2, t4, fail
    ori     s1, s1, 0x40

    /* Step 8: DRAM LB/LBU/LH/LHU readback + load-followed-by-store + upper DRAM word */
    li      t0, 8
    lb      t1, 3(s2)               /* 0x98 -> 0xFFFF_FF98 */
    li      t4, 0xFFFFFF98
    bne     t1, t4, fail
    lbu     t1, 3(s2)               /* 0x0000_0098 */
    li      t4, 0x00000098
    bne     t1, t4, fail
    lh      t1, 2(s2)               /* 0x9810 -> 0xFFFF_9810 */
    li      t4, 0xFFFF9810
    bne     t1, t4, fail
    lhu     t1, 2(s2)               /* 0x0000_9810 */
    li      t4, 0x00009810
    bne     t1, t4, fail

    /* Load immediately followed by Store (C1 -> C2 transition in CON-MEM-001 §2.4) */
    li      s3, 0x20007EFC          /* near upper DRAM, safely below mailbox */
    lw      t5, 0(s2)
    sw      t5, 0(s3)
    lw      t6, 0(s3)
    bne     t6, t5, fail
    ori     s1, s1, 0x80

pass:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00000002
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PASS
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_core_002_pass_ebreak
ver_core_002_pass_ebreak:
    ebreak

fail:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00000002
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_FAIL_BASE
    or      t2, t2, t0
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_core_002_fail_ebreak
ver_core_002_fail_ebreak:
    ebreak

    .section .rodata, "a"
    .align 4
rodata_pattern:
    .word   0x89ABCDEF
    .word   0x7F128034
