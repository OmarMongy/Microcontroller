/* Test ID: VER-GPIO-001
 * Requirements: CON-PERIPH-001 §1 & §3 (gpio_apb)
 * Purpose:
 *   1. Verify reset defaults (GPIO_DIR=0, GPIO_DATA_OUT=0, GPIO_DATA_IN=0 when gpio_i=0).
 *   2. Verify reserved upper bits [31:8] read 0 and ignore writes.
 *   3. Verify GPIO_DIR & GPIO_DATA_OUT walking-1 / walking-0 patterns.
 *   4. Verify 2-FF gpio_i sampling via BFM echo mode (gpio_i = {~gpio_o[3:0], gpio_o[3:0]}).
 * Expected outcome:
 *   MBOX_TESTID_ADDR = 0x0000_2020, MBOX_STATUS_ADDR = 0xCAFE_0001,
 *   fault_code_o = 4'h5 (FAULT_EBREAK) at ver_gpio_001_pass_ebreak.
 */

#include "periph_regs.inc"

    .section .text.init, "ax"
    .globl _start
_start:
    li      s1, 0
    li      s0, APB_GPIO_SLOT_BASE

    /* Step 1: Reset defaults */
    li      t0, 1
    lw      t1, 0x008(s0)           /* GPIO_DIR */
    bnez    t1, fail
    lw      t1, 0x004(s0)           /* GPIO_DATA_OUT */
    bnez    t1, fail
    lw      t1, 0x000(s0)           /* GPIO_DATA_IN (TB drives 0 initially) */
    bnez    t1, fail
    ori     s1, s1, 0x1

    /* Step 2: Reserved [31:8] ignored */
    li      t0, 2
    li      t1, 0xFFFFFF5A
    sw      t1, 0x008(s0)
    lw      t2, 0x008(s0)
    li      t3, 0x0000005A
    bne     t2, t3, fail

    li      t1, 0xFFFFFFA5
    sw      t1, 0x004(s0)
    lw      t2, 0x004(s0)
    li      t3, 0x000000A5
    bne     t2, t3, fail
    ori     s1, s1, 0x2

    /* Step 3: Walking-1 and Walking-0 on GPIO_DIR=0xFF / GPIO_DATA_OUT */
    li      t0, 3
    li      t1, 0xFF
    sw      t1, 0x008(s0)
    li      t2, 1
    li      t3, 0x100
walk1_loop:
    sw      t2, 0x004(s0)
    lw      t4, 0x004(s0)
    bne     t4, t2, fail
    slli    t2, t2, 1
    bne     t2, t3, walk1_loop

    li      t2, 1
    li      t5, 0xFF
walk0_loop:
    xor     t4, t5, t2
    sw      t4, 0x004(s0)
    lw      t6, 0x004(s0)
    bne     t6, t4, fail
    slli    t2, t2, 1
    bne     t2, t3, walk0_loop
    ori     s1, s1, 0x4

    /* Step 4: 2-FF gpio_i sampling with BFM echo (gpio_i = {~gpio_o[3:0], gpio_o[3:0]}) */
    li      t0, 4
    li      t1, 0x0F                /* [3:0] outputs, [7:4] inputs */
    sw      t1, 0x008(s0)
    li      t2, 0
    li      t3, 16
echo_loop:
    sw      t2, 0x004(s0)
    nop                             /* wait >= 3 PCLK edges for 2-FF sync */
    nop
    nop
    nop
    lw      t4, 0x000(s0)           /* GPIO_DATA_IN */
    xori    t5, t2, 0xF             /* ~t2[3:0] */
    slli    t5, t5, 4
    or      t5, t5, t2              /* expected {~t2[3:0], t2[3:0]} */
    bne     t4, t5, fail
    addi    t2, t2, 1
    bne     t2, t3, echo_loop
    ori     s1, s1, 0x8

pass:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00002020
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PASS
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_gpio_001_pass_ebreak
ver_gpio_001_pass_ebreak:
    ebreak

fail:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00002020
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_FAIL_BASE
    or      t2, t2, t0
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_gpio_001_fail_ebreak
ver_gpio_001_fail_ebreak:
    ebreak
