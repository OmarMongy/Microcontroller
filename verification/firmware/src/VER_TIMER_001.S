/* Test ID: VER-TIMER-001
 * Requirements: CON-PERIPH-001 §1 & §4 (timer_apb)
 * Purpose:
 *   1. Verify reset defaults (CTRL=0, STATUS=0, COUNTER=0, COMPARE=0xFFFF_FFFF).
 *   2. Verify EN=0 pause & reserved-bit write-ignore.
 *   3. Verify free-running EN=1, AUTO_RELOAD=0 compare match (sticky MATCH, counter keeps counting, W1C clear).
 *   4. Verify CLR_CNT (WO/SC: always reads 0, clears counter).
 *   5. Verify AUTO_RELOAD=1 periodic reload (COMPARE=99 -> 100-cycle period, two consecutive MATCHes, OVF=0).
 *   6. Verify direct TIMER_COUNTER write while EN=1 + 0xFFFF_FFFF wrap setting sticky OVF + W1C clear.
 * Expected outcome:
 *   MBOX_TESTID_ADDR = 0x0000_2040, MBOX_STATUS_ADDR = 0xCAFE_0001,
 *   fault_code_o = 4'h5 (FAULT_EBREAK) at ver_timer_001_pass_ebreak.
 */

#include "periph_regs.inc"

    .section .text.init, "ax"
    .globl _start
_start:
    li      s1, 0
    li      s0, APB_TIMER_SLOT_BASE

    /* Step 1: Reset defaults + EN=0 pause */
    li      t0, 1
    lw      t1, 0x000(s0)           /* TIMER_CTRL */
    bnez    t1, fail
    lw      t1, 0x004(s0)           /* TIMER_STATUS */
    bnez    t1, fail
    lw      t1, 0x008(s0)           /* TIMER_COUNTER */
    bnez    t1, fail
    lw      t2, 0x008(s0)
    bnez    t2, fail                /* still paused at 0 */
    lw      t1, 0x00C(s0)           /* TIMER_COMPARE */
    li      t2, 0xFFFFFFFF
    bne     t1, t2, fail
    ori     s1, s1, 0x1

    /* Step 2: Reserved-bit write-ignore on CTRL & STATUS */
    li      t0, 2
    li      t1, 0xFFFFFFF8
    sw      t1, 0x000(s0)
    lw      t2, 0x000(s0)
    bnez    t2, fail
    li      t1, 0xFFFFFFFC
    sw      t1, 0x004(s0)
    lw      t2, 0x004(s0)
    bnez    t2, fail
    ori     s1, s1, 0x2

    /* Step 3: Free-running compare match + sticky MATCH + W1C */
    li      t0, 3
    li      t1, 20
    sw      t1, 0x00C(s0)           /* COMPARE = 20 */
    li      t1, TIMER_CTRL_EN
    sw      t1, 0x000(s0)
    li      t4, 200
wait_m1:
    lw      t2, 0x004(s0)
    andi    t3, t2, TIMER_STS_MATCH
    bnez    t3, got_m1
    addi    t4, t4, -1
    bnez    t4, wait_m1
    j       fail
got_m1:
    /* Free-running: counter must be > 20 */
    lw      t5, 0x008(s0)
    li      t6, 20
    bleu    t5, t6, fail
    /* Sticky across read, then W1C */
    lw      t2, 0x004(s0)
    andi    t3, t2, TIMER_STS_MATCH
    beqz    t3, fail
    li      t1, TIMER_STS_MATCH
    sw      t1, 0x004(s0)
    lw      t2, 0x004(s0)
    andi    t3, t2, TIMER_STS_MATCH
    bnez    t3, fail
    ori     s1, s1, 0x4

    /* Step 4: Pause & CLR_CNT (WO/SC) */
    li      t0, 4
    sw      zero, 0x000(s0)         /* EN=0 */
    li      t1, 0x1234
    sw      t1, 0x008(s0)
    lw      t2, 0x008(s0)
    bne     t2, t1, fail
    li      t1, TIMER_CTRL_CLR_CNT
    sw      t1, 0x000(s0)
    lw      t2, 0x000(s0)           /* CLR_CNT must read 0 */
    bnez    t2, fail
    lw      t2, 0x008(s0)           /* COUNTER cleared to 0 */
    bnez    t2, fail
    ori     s1, s1, 0x8

    /* Step 5: AUTO_RELOAD=1 periodic match (COMPARE=99 -> 100 cycles) */
    li      t0, 5
    li      t1, 99
    sw      t1, 0x00C(s0)
    li      t1, (TIMER_STS_MATCH | TIMER_STS_OVF)
    sw      t1, 0x004(s0)
    li      t1, (TIMER_CTRL_EN | TIMER_CTRL_AUTO_RLD)
    sw      t1, 0x000(s0)
    li      t4, 200
wait_ar1:
    lw      t2, 0x004(s0)
    andi    t3, t2, TIMER_STS_MATCH
    bnez    t3, got_ar1
    addi    t4, t4, -1
    bnez    t4, wait_ar1
    j       fail
got_ar1:
    li      t1, TIMER_STS_MATCH
    sw      t1, 0x004(s0)           /* W1C clear */
    li      t4, 200
wait_ar2:
    lw      t2, 0x004(s0)
    andi    t3, t2, TIMER_STS_MATCH
    bnez    t3, got_ar2
    addi    t4, t4, -1
    bnez    t4, wait_ar2
    j       fail
got_ar2:
    /* Counter must stay <= 99 in auto-reload */
    lw      t5, 0x008(s0)
    li      t6, 99
    bgtu    t5, t6, fail
    ori     s1, s1, 0x10

    /* Step 6: Direct COUNTER write while EN=1 + 0xFFFF_FFFF wrap OVF */
    li      t0, 6
    li      t1, 0x00001000          /* COMPARE far from 0xFFFF_FFFF */
    sw      t1, 0x00C(s0)
    li      t1, TIMER_CTRL_EN       /* AUTO_RELOAD=0, EN=1 */
    sw      t1, 0x000(s0)
    li      t1, (TIMER_STS_MATCH | TIMER_STS_OVF)
    sw      t1, 0x004(s0)
    li      t1, 0xFFFFFFF0
    sw      t1, 0x008(s0)           /* direct COUNTER write while EN=1 */
    li      t4, 200
wait_ovf:
    lw      t2, 0x004(s0)
    andi    t3, t2, TIMER_STS_OVF
    bnez    t3, got_ovf
    addi    t4, t4, -1
    bnez    t4, wait_ovf
    j       fail
got_ovf:
    andi    t3, t2, TIMER_STS_MATCH
    bnez    t3, fail                /* MATCH must still be 0 */
    li      t1, TIMER_STS_OVF
    sw      t1, 0x004(s0)           /* W1C clear OVF */
    lw      t2, 0x004(s0)
    bnez    t2, fail
    ori     s1, s1, 0x20

pass:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00002040
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PASS
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_timer_001_pass_ebreak
ver_timer_001_pass_ebreak:
    ebreak

fail:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00002040
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_FAIL_BASE
    or      t2, t2, t0
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_timer_001_fail_ebreak
ver_timer_001_fail_ebreak:
    ebreak
