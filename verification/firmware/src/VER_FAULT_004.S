/* Test ID: VER-FAULT-004
 * Fault: FAULT_ECALL (4'h4) — CON-FLT-RST-001 §1.1
 * Expected:
 *   fault_o = 1, fault_code_o = 4'h4, fault_pc_o = fault_trigger_pc,
 *   fault_insn_o = 0x0000_0073, fault_addr_o = 32'h0, sentinel untouched.
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, 0x1040
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)

    .globl fault_trigger_pc
fault_trigger_pc:
    ecall

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
