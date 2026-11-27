/* Test ID: VER-GPIO-002
 * Requirements: CON-PERIPH-001 §1.3 & §3 (gpio_apb PSLVERR), CON-FLT-RST-001
 * Subcases (-DSUBCASE=0..2):
 *   0: Write RO GPIO_DATA_IN (0x000) -> FAULT_APB_SLVERR (4'h9)
 *   1: Read unimplemented offset 0x00C -> FAULT_APB_SLVERR (4'h9)
 *   2: Write unimplemented offset 0xFFC -> FAULT_APB_SLVERR (4'h9)
 */

#include "periph_regs.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x2030 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      t3, 0x000000A5

#if SUBCASE == 0
    li      t0, GPIO_DATA_IN
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#elif SUBCASE == 1
    li      t0, GPIO_UNIMPL_LOW
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#elif SUBCASE == 2
    li      t0, GPIO_UNIMPL_HIGH
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#else
#error "Invalid SUBCASE for VER-GPIO-002"
#endif

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
