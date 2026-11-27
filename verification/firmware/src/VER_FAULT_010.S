/* Test ID: VER-FAULT-010
 * Fault: FAULT_APB_SLVERR (4'h9) — CON-APB3-001 §5.2.4, CON-FLT-RST-001 §1.1
 * Scope Note: Executed in TB-CORE-BUS with Mock APB3 Completer configured to return
 *             PREADY=1, PSLVERR=1 on the targeted APB3 slot.
 * Subcases (-DSUBCASE=0..1):
 *   0: LW from 0x4000_0000 (verifies rd t3=0x11223344 is NOT overwritten by PRDATA on PSLVERR!)
 *   1: SW to   0x4000_1000 (verifies write fault halts immediately without advancing PC)
 * Expected:
 *   fault_o = 1, fault_code_o = 4'h9, fault_pc_o = fault_trigger_pc,
 *   fault_addr_o = target APB3 addr, fault_insn_o = LW/SW insn,
 *   MBOX_DETAIL_ADDR remains 0 (no post-fault writes), sentinel untouched.
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x10A0 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      t3, 0x11223344

#if SUBCASE == 0
    li      t0, APB_UART_SLOT_BASE
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#elif SUBCASE == 1
    li      t0, APB_GPIO_SLOT_BASE
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#else
#error "Invalid SUBCASE for VER-FAULT-010"
#endif

    /* Sentinel + check whether t3 was mutated on LW PSLVERR */
    li      t1, MBOX_DETAIL_ADDR
    sw      t3, 0(t1)
    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
