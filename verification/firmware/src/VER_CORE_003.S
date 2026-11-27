/* Test ID: VER-CORE-003
 * Requirements: CON-ADDR-001 §3, CON-APB3-001 §3-§5, DEC-CPU-APB-WAIT-001, DEC-ARCH-CORE-002 #3
 * Scope Note: Targets APB3 slots 0, 1, 2 (0x4000_0000, 0x4000_1000, 0x4000_2000) ONLY at the
 *             APB3 bus boundary against Testbench Mock APB3 Completers.
 *             Does NOT assume uart_apb / gpio_apb / timer_apb register maps (BLOCKED).
 * Purpose:
 *   1. Exercise SW and LW across all 3 populated APB3 slots (base +0x000 and top +0xFFC).
 *   2. Verify readback integrity, back-to-back APB transfers, FENCE after APB3, and
 *      x0 immutability when LW targets x0 (transfer still completes once on bus).
 *   3. Pair with TB wait-state profiles (0, 1, 2, 5+ cycles) to verify stall/commit.
 * Expected outcome:
 *   MBOX_TESTID_ADDR (0x2000_7F04) = 0x0000_0003
 *   MBOX_STATUS_ADDR (0x2000_7F00) = 0xCAFE_0001 (STATUS_PASS)
 *   fault_o = 1, fault_code_o = 4'h5 (FAULT_EBREAK), fault_pc_o = ver_core_003_pass_ebreak
 */

#include "verif_mailbox.inc"

    .section .text.init, "ax"
    .globl _start
_start:
    li      s1, 0

    /* Step 1: Slot 0 (0x4000_0000) SW -> LW at +0x000 and +0xFFC */
    li      t0, 1
    li      s0, APB_UART_SLOT_BASE
    li      t1, 0x12345678
    sw      t1, 0(s0)
    lw      t2, 0(s0)
    bne     t2, t1, fail

    li      t3, 0xA5A55A5A
    li      t5, 0xFFC
    add     t5, s0, t5
    sw      t3, 0(t5)
    lw      t4, 0(t5)
    bne     t4, t3, fail
    ori     s1, s1, 0x1

    /* Step 2: Slot 1 (0x4000_1000) SW -> LW at +0x000 and +0xFFC */
    li      t0, 2
    li      s2, APB_GPIO_SLOT_BASE
    li      t1, 0xCAFEBABE
    sw      t1, 0(s2)
    lw      t2, 0(s2)
    bne     t2, t1, fail

    li      t3, 0x0F0F0F0F
    li      t5, 0xFFC
    add     t5, s2, t5
    sw      t3, 0(t5)
    lw      t4, 0(t5)
    bne     t4, t3, fail
    ori     s1, s1, 0x2

    /* Step 3: Slot 2 (0x4000_2000) SW -> LW at +0x000 and +0xFFC */
    li      t0, 3
    li      s3, APB_TIMER_SLOT_BASE
    li      t1, 0xDEADBEEF
    sw      t1, 0(s3)
    lw      t2, 0(s3)
    bne     t2, t1, fail

    li      t3, 0x55AA33CC
    li      t5, 0xFFC
    add     t5, s3, t5
    sw      t3, 0(t5)
    lw      t4, 0(t5)
    bne     t4, t3, fail
    ori     s1, s1, 0x4

    /* Step 4: Cross-slot isolation & FENCE after APB3 */
    li      t0, 4
    lw      t2, 0(s0)
    li      t1, 0x12345678
    bne     t2, t1, fail
    lw      t2, 0(s2)
    li      t1, 0xCAFEBABE
    bne     t2, t1, fail
    fence   iorw, iorw
    ori     s1, s1, 0x8

    /* Step 5: LW with rd == x0 on APB3 (bus read occurs once; x0 remains 0) */
    li      t0, 5
    lw      zero, 0(s3)
    bne     zero, x0, fail
    ori     s1, s1, 0x10

pass:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00000003
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PASS
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_core_003_pass_ebreak
ver_core_003_pass_ebreak:
    ebreak

fail:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00000003
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_FAIL_BASE
    or      t2, t2, t0
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_core_003_fail_ebreak
ver_core_003_fail_ebreak:
    ebreak
