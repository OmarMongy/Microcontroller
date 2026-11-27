/* Test ID: VER-UART-001
 * Requirements: CON-PERIPH-001 §1 & §2 (uart_apb)
 * Purpose:
 *   1. Verify reset defaults (UART_CTRL=0x3, UART_STATUS=0x2, UART_BAUD_DIV=434).
 *   2. Verify reserved-bit write-ignore and programmable BAUD_DIV (24-bit, set=16 for BFM).
 *   3. Verify TX_EN=0 ignores writes and keeps TX_EMPTY=1, TX_BUSY=0.
 *   4. Verify TX 8N1 polling (TX_BUSY/TX_EMPTY) + write-while-TX_BUSY ignored without PSLVERR.
 *   5. Verify RX 8N1 reception (BFM sends 0xA3 on TX=0x55), RX_VALID read-clear.
 *   6. Verify RX_OVERRUN sticky + W1C + old unread byte preserved (BFM sends 0x3C, 0x7E on TX=0x56).
 *   7. Verify RX_FRAME_ERR sticky + W1C + frame discarded (BFM sends stop=0 on TX=0x57).
 * Expected outcome:
 *   MBOX_TESTID_ADDR = 0x0000_2001, MBOX_STATUS_ADDR = 0xCAFE_0001,
 *   fault_code_o = 4'h5 (FAULT_EBREAK) at ver_uart_001_pass_ebreak.
 */

#include "periph_regs.inc"

    .section .text.init, "ax"
    .globl _start
_start:
    li      s1, 0

    /* Step 1: Reset defaults */
    li      t0, 1
    li      s0, APB_UART_SLOT_BASE
    lw      t1, 0x000(s0)           /* UART_CTRL */
    li      t2, 0x3
    bne     t1, t2, fail
    lw      t1, 0x004(s0)           /* UART_STATUS */
    li      t2, 0x2
    bne     t1, t2, fail
    lw      t1, 0x010(s0)           /* UART_BAUD_DIV */
    li      t2, UART_BAUD_DIV_RST
    bne     t1, t2, fail
    ori     s1, s1, 0x1

    /* Step 2: Reserved-bit write-ignore & BAUD_DIV programming (16 clks/bit for sim) */
    li      t0, 2
    li      t1, 0xFFFFFFFF
    sw      t1, 0x000(s0)           /* UART_CTRL: reserved [31:2] ignored */
    lw      t2, 0x000(s0)
    li      t3, 0x3
    bne     t2, t3, fail

    li      t1, 0xFF000010          /* BAUD_DIV=16, reserved [31:24]=0xFF ignored */
    sw      t1, 0x010(s0)
    lw      t2, 0x010(s0)
    li      t3, 16
    bne     t2, t3, fail
    ori     s1, s1, 0x2

    /* Step 3: TX_EN=0 ignores TX_DATA write */
    li      t0, 3
    li      t1, UART_CTRL_RX_EN     /* TX_EN=0, RX_EN=1 */
    sw      t1, 0x000(s0)
    li      t1, 0x77
    sw      t1, 0x008(s0)           /* ignored */
    lw      t2, 0x004(s0)
    andi    t2, t2, (UART_STS_TX_EMPTY | UART_STS_TX_BUSY)
    li      t3, UART_STS_TX_EMPTY
    bne     t2, t3, fail
    li      t1, (UART_CTRL_TX_EN | UART_CTRL_RX_EN)
    sw      t1, 0x000(s0)
    ori     s1, s1, 0x4

    /* Step 4: TX 0x55 + immediate write-while-TX_BUSY ignored + poll TX_EMPTY */
    li      t0, 4
    li      t1, 0x55
    sw      t1, 0x008(s0)           /* starts 8N1 TX of 0x55 */
    lw      t2, 0x004(s0)
    andi    t2, t2, (UART_STS_TX_EMPTY | UART_STS_TX_BUSY)
    li      t3, UART_STS_TX_BUSY    /* TX_BUSY=1, TX_EMPTY=0 */
    bne     t2, t3, fail
    li      t1, 0x99
    sw      t1, 0x008(s0)           /* must be ignored while busy */

    /* Write 1s to RO bits [2:0] in UART_STATUS: must not clear TX_BUSY or fault */
    li      t1, 0x7
    sw      t1, 0x004(s0)

    /* Poll for TX_EMPTY == 1 (also BFM will answer 0x55 with RX 0xA3) */
    li      t4, 2000
tx1_wait:
    lw      t2, 0x004(s0)
    andi    t3, t2, UART_STS_TX_EMPTY
    bnez    t3, tx1_done
    addi    t4, t4, -1
    bnez    t4, tx1_wait
    j       fail
tx1_done:
    ori     s1, s1, 0x8

    /* Step 5: Poll RX_VALID for 0xA3 and verify read-clear */
    li      t0, 5
    li      t4, 4000
rx1_wait:
    lw      t2, 0x004(s0)
    andi    t3, t2, UART_STS_RX_VALID
    bnez    t3, rx1_got
    addi    t4, t4, -1
    bnez    t4, rx1_wait
    j       fail
rx1_got:
    lw      t1, 0x00C(s0)           /* UART_RX_DATA */
    li      t3, 0xA3
    bne     t1, t3, fail
    lw      t2, 0x004(s0)
    andi    t3, t2, UART_STS_RX_VALID
    bnez    t3, fail                /* read must clear RX_VALID */
    ori     s1, s1, 0x10

    /* Step 6: Trigger RX_OVERRUN (TX=0x56 -> BFM sends 0x3C then 0x7E) */
    li      t0, 6
    li      t1, 0x56
    sw      t1, 0x008(s0)
    /* Poll until RX_OVERRUN == 1 (do NOT read UART_RX_DATA prematurely) */
    li      t4, 8000
ovr_wait:
    lw      t2, 0x004(s0)
    andi    t3, t2, UART_STS_RX_OVERRUN
    bnez    t3, ovr_got
    addi    t4, t4, -1
    bnez    t4, ovr_wait
    j       fail
ovr_got:
    /* Old unread byte 0x3C must be preserved */
    lw      t1, 0x00C(s0)
    li      t3, 0x3C
    bne     t1, t3, fail
    /* RX_OVERRUN must remain sticky until W1C */
    lw      t2, 0x004(s0)
    andi    t3, t2, UART_STS_RX_OVERRUN
    beqz    t3, fail
    li      t1, UART_STS_RX_OVERRUN
    sw      t1, 0x004(s0)           /* W1C */
    lw      t2, 0x004(s0)
    andi    t3, t2, UART_STS_RX_OVERRUN
    bnez    t3, fail
    ori     s1, s1, 0x20

    /* Step 7: Trigger RX_FRAME_ERR (TX=0x57 -> BFM sends stop=0 frame) */
    li      t0, 7
    li      t1, 0x57
    sw      t1, 0x008(s0)
    li      t4, 8000
ferr_wait:
    lw      t2, 0x004(s0)
    andi    t3, t2, UART_STS_RX_FRAME_ERR
    bnez    t3, ferr_got
    addi    t4, t4, -1
    bnez    t4, ferr_wait
    j       fail
ferr_got:
    /* Invalid frame must be discarded (RX_VALID == 0) */
    andi    t3, t2, UART_STS_RX_VALID
    bnez    t3, fail
    li      t1, UART_STS_RX_FRAME_ERR
    sw      t1, 0x004(s0)           /* W1C */
    lw      t2, 0x004(s0)
    andi    t3, t2, UART_STS_RX_FRAME_ERR
    bnez    t3, fail
    ori     s1, s1, 0x40

pass:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00002001
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PASS
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_uart_001_pass_ebreak
ver_uart_001_pass_ebreak:
    ebreak

fail:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00002001
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      s1, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_FAIL_BASE
    or      t2, t2, t0
    sw      t2, 0(t1)
    fence   iorw, iorw
    .globl ver_uart_001_fail_ebreak
ver_uart_001_fail_ebreak:
    ebreak
