/* Test ID: VER-UART-002
 * Requirements: CON-PERIPH-001 §1.3 & §2 (uart_apb PSLVERR), CON-FLT-RST-001
 * Subcases (-DSUBCASE=0..4):
 *   0: Read WO UART_TX_DATA (0x008) -> FAULT_APB_SLVERR (4'h9)
 *   1: Write RO UART_RX_DATA (0x00C) -> FAULT_APB_SLVERR (4'h9)
 *   2: Write UART_BAUD_DIV = 1 (< 2) -> FAULT_APB_SLVERR (4'h9)
 *   3: Write UART_BAUD_DIV = 0 (< 2) -> FAULT_APB_SLVERR (4'h9)
 *   4: Read unimplemented offset 0x014 -> FAULT_APB_SLVERR (4'h9)
 */

#include "periph_regs.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x2010 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      t3, 0x12345678

#if SUBCASE == 0
    li      t0, UART_TX_DATA
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#elif SUBCASE == 1
    li      t0, UART_RX_DATA
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#elif SUBCASE == 2
    li      t0, UART_BAUD_DIV
    li      t3, 1
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#elif SUBCASE == 3
    li      t0, UART_BAUD_DIV
    li      t3, 0
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#elif SUBCASE == 4
    li      t0, UART_UNIMPL_LOW
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#else
#error "Invalid SUBCASE for VER-UART-002"
#endif

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
