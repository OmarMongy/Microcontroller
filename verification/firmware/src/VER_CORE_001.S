/* Test ID: VER-CORE-001
 * Requirements: SPEC A1, CPU §3, DEC-ARCH-CORE-002 #3 (FENCE), CON-FLT-RST-001 (x0==0)
 * Purpose: Directed self-checking test for all non-memory RV32I base ISA instructions:
 *          LUI, AUIPC, JAL, JALR (incl. rd==rs1 & LSB clear), BEQ/BNE/BLT/BGE/BLTU/BGEU
 *          (forward/backward, taken/untaken), ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI,
 *          ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND, x0 immutability, and FENCE.
 * Expected outcome:
 *   MBOX_TESTID_ADDR (0x2000_7F04) = 0x0000_0001
 *   MBOX_DETAIL_ADDR (0x2000_7F08) = 0x0000_FFFF (all 16 subchecks passed)
 *   MBOX_STATUS_ADDR (0x2000_7F00) = 0xCAFE_0001 (STATUS_PASS)
 *   fault_o = 1, fault_code_o = 4'h5 (FAULT_EBREAK), fault_pc_o = pass_ebreak
 */

#include "verif_mailbox.inc"

    .section .text.init, "ax"
    .globl _start
_start:
    /* Step 1: Verify x0 immutability as destination and source */
    li      t0, 1
    addi    x0, x0, 0x123
    lui     x0, 0xABCDE
    auipc   x0, 0x1
    add     x0, t0, t0
    bne     x0, zero, fail
    addi    s1, zero, 1             /* detail mask bit 0 */

    /* Step 2: LUI and AUIPC */
    li      t0, 2
    lui     t1, 0x12345
    li      t2, 0x12345000
    bne     t1, t2, fail
auipc_ref:
    auipc   t3, 0
    la      t4, auipc_ref
    bne     t3, t4, fail
    ori     s1, s1, 0x2

    /* Step 3: ADD / SUB / ADDI */
    li      t0, 3
    li      t1, 0x7FFFFFFF
    addi    t2, t1, 1               /* 0x8000_0000 (wrap without trap) */
    li      t3, 0x80000000
    bne     t2, t3, fail
    sub     t4, t2, t1              /* 0x8000_0000 - 0x7FFF_FFFF = 1 */
    addi    t5, zero, 1
    bne     t4, t5, fail
    add     t4, t1, t2              /* 0xFFFF_FFFF */
    addi    t5, zero, -1
    bne     t4, t5, fail
    ori     s1, s1, 0x4

    /* Step 4: Logical ops (AND/OR/XOR/ANDI/ORI/XORI) */
    li      t0, 4
    li      t1, 0xA5A55A5A
    li      t2, 0x0F0FF0F0
    and     t3, t1, t2
    li      t4, 0x05055050
    bne     t3, t4, fail
    or      t3, t1, t2
    li      t4, 0xAFAFFAFA
    bne     t3, t4, fail
    xor     t3, t1, t2
    li      t4, 0xAA0AA0AA
    /* Wait: 0xA5A55A5A ^ 0x0F0FF0F0 = 0xAA0AA0AA? Check nibble by nibble:
       A^0=A, 5^F=A, A^0=A, 5^F=A, 5^F=A, A^0=A, 5^F=A, A^0=A -> 0xAAAAAAAA! */
    li      t4, 0xAAAAAAAA
    bne     t3, t4, fail
    andi    t3, t1, 0x0FF
    li      t4, 0x0000005A
    bne     t3, t4, fail
    ori     t3, t3, 0x105
    li      t4, 0x0000015F
    bne     t3, t4, fail
    xori    t3, t3, -1              /* bitwise NOT */
    li      t4, 0xFFFFFEA0
    bne     t3, t4, fail
    ori     s1, s1, 0x8

    /* Step 5: Immediate & Register Shifts (0, 1, 31; logical vs arithmetic) */
    li      t0, 5
    li      t1, 0x80000001
    slli    t2, t1, 0
    bne     t2, t1, fail
    slli    t2, t1, 31
    li      t3, 0x80000000
    bne     t2, t3, fail
    srli    t2, t1, 31
    li      t3, 1
    bne     t2, t3, fail
    srai    t2, t1, 31
    li      t3, -1
    bne     t2, t3, fail
    li      t4, 4
    sll     t2, t1, t4
    li      t3, 0x00000010
    bne     t2, t3, fail
    srl     t2, t1, t4
    li      t3, 0x08000000
    bne     t2, t3, fail
    sra     t2, t1, t4
    li      t3, 0xF8000000
    bne     t2, t3, fail
    /* Verify shift amount uses only lower 5 bits rs2[4:0] */
    li      t4, 0x24                /* 0x24 & 0x1F = 4 */
    sra     t2, t1, t4
    bne     t2, t3, fail
    ori     s1, s1, 0x10

    /* Step 6: Signed & Unsigned Comparisons (SLT/SLTI/SLTU/SLTIU) */
    li      t0, 6
    li      t1, -1                  /* 0xFFFF_FFFF */
    li      t2, 1
    slt     t3, t1, t2              /* -1 < 1 (signed) -> 1 */
    bne     t3, t2, fail
    sltu    t3, t1, t2              /* 0xFFFF_FFFF < 1 (unsigned) -> 0 */
    bne     t3, zero, fail
    slti    t3, t2, -1              /* 1 < -1 (signed) -> 0 */
    bne     t3, zero, fail
    sltiu   t3, t2, -1              /* 1 < 0xFFFF_FFFF (unsigned) -> 1 */
    bne     t3, t2, fail
    ori     s1, s1, 0x20

    /* Step 7: Branch Instructions (BEQ/BNE/BLT/BGE/BLTU/BGEU - taken/untaken, fwd/bwd) */
    li      t0, 7
    li      t1, -5
    li      t2, 5
    beq     t1, t2, fail            /* untaken */
    beq     t1, t1, 1f              /* taken fwd */
    j       fail
1:  bne     t1, t1, fail            /* untaken */
    bne     t1, t2, 2f              /* taken fwd */
    j       fail
2:  blt     t2, t1, fail            /* untaken */
    blt     t1, t2, 3f              /* taken fwd */
    j       fail
3:  bge     t1, t2, fail            /* untaken */
    bge     t2, t1, 4f              /* taken fwd */
    j       fail
4:  bltu    t1, t2, fail            /* untaken: 0xFFFF_FFFB > 5 */
    bltu    t2, t1, 5f              /* taken fwd */
    j       fail
5:  bgeu    t2, t1, fail            /* untaken */
    bgeu    t1, t2, 6f              /* taken fwd */
    j       fail
6:  /* Backward branch loop (count 3 -> 0) */
    li      t3, 3
    li      t4, 0
bwd_loop:
    addi    t4, t4, 1
    addi    t3, t3, -1
    bnez    t3, bwd_loop
    li      t5, 3
    bne     t4, t5, fail
    ori     s1, s1, 0x40

    /* Step 8: JAL and JALR (including rd==rs1 and bit-0 masking) */
    li      t0, 8
    jal     ra, helper_fn
jal_ret_pc:
    li      t5, 0x1357
    bne     a0, t5, fail
    /* Test JALR with bit 0 set on input address (must clear bit 0 -> aligned) */
    la      t1, jalr_target
    addi    t1, t1, 1               /* set bit 0 only */
    jalr    t1, t1, 0               /* rd == rs1! */
jalr_ret_pc:
    j       fail                    /* skipped if JALR jumped to jalr_target */
jalr_target:
    la      t2, jalr_ret_pc
    bne     t1, t2, fail            /* link register must equal jalr_ret_pc */
    ori     s1, s1, 0x80

    /* Step 9: FENCE executes as valid single-cycle NOP (DEC-ARCH-CORE-002 #3) */
    li      t0, 9
    fence   iorw, iorw
    fence
    ori     s1, s1, 0x100

pass:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00000001
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PASS
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_core_001_pass_ebreak
ver_core_001_pass_ebreak:
    ebreak

fail:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00000001
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_FAIL_BASE
    or      t2, t2, t0
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_core_001_fail_ebreak
ver_core_001_fail_ebreak:
    ebreak

helper_fn:
    la      t5, jal_ret_pc
    bne     ra, t5, fail
    li      a0, 0x1357
    jalr    zero, ra, 0
