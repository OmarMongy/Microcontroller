/* Bare-metal RV32I startup for C verification tests
 * Copies .data from IROM LMA (_sidata) to DRAM VMA (_sdata.._edata),
 * clears .bss (_sbss.._ebss), sets SP = _stack_top, calls main(), then EBREAK.
 */

#include "verif_mailbox.inc"

    .section .text.init, "ax"
    .globl _start
_start:
    la      sp, _stack_top

    /* Copy .data from IROM (Port B 2-cycle loads) to DRAM */
    la      t0, _sidata
    la      t1, _sdata
    la      t2, _edata
copy_data_loop:
    bgeu    t1, t2, copy_data_done
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    j       copy_data_loop
copy_data_done:

    /* Clear .bss in DRAM (required for warm-reset safety per CON-MEM-001 §2.6) */
    la      t1, _sbss
    la      t2, _ebss
zero_bss_loop:
    bgeu    t1, t2, zero_bss_done
    sw      zero, 0(t1)
    addi    t1, t1, 4
    j       zero_bss_loop
zero_bss_done:

    call    main

    /* main() return value in a0: 0 = PASS, non-zero = FAIL */
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x00000004
    sw      t2, 0(t1)
    li      t1, MBOX_DETAIL_ADDR
    sw      a0, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    bnez    a0, c_fail
    li      t2, STATUS_PASS
    sw      t2, 0(t1)
    j       c_done
c_fail:
    li      t2, STATUS_FAIL_BASE
    or      t2, t2, a0
    sw      t2, 0(t1)
c_done:
    fence   iorw, iorw
    .globl ver_core_004_done_ebreak
ver_core_004_done_ebreak:
    ebreak
