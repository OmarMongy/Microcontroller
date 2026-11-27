/* Test ID: VER-TIMER-002
 * Requirements: CON-PERIPH-001 §1.3 & §4 (timer_apb PSLVERR), CON-FLT-RST-001
 * Subcases (-DSUBCASE=0..1):
 *   0: Read unimplemented offset 0x010 -> FAULT_APB_SLVERR (4'h9)
 *   1: Write unimplemented offset 0xFFC -> FAULT_APB_SLVERR (4'h9)
 */

#include "periph_regs.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x2050 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      t3, 0xDEAD1234

#if SUBCASE == 0
    li      t0, TIMER_UNIMPL_LOW
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#elif SUBCASE == 1
    li      t0, TIMER_UNIMPL_HIGH
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#else
#error "Invalid SUBCASE for VER-TIMER-002"
#endif

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
