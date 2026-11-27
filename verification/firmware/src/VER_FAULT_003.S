/* Test ID: VER-FAULT-003
 * Fault: FAULT_ILLEGAL_INSN (4'h3) — CON-FLT-RST-001 §1.1
 * Subcases (-DSUBCASE=0..5):
 *   0: 0x0000_0000 (all zeros)
 *   1: 0xFFFF_FFFF (all ones)
 *   2: 0x3000_9073 (CSRRW x0, mstatus, x1 — Zicsr unsupported)
 *   3: 0x3020_0073 (MRET — privileged unsupported)
 *   4: 0x0231_00B3 (MUL x1, x2, x3 — M extension unsupported)
 *   5: 0x0000_100F (FENCE.I — MISC-MEM funct3!=000 unsupported)
 * Expected:
 *   fault_o = 1, fault_code_o = 4'h3, fault_pc_o = fault_trigger_pc,
 *   fault_insn_o = offending word, fault_addr_o = 32'h0
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x1030 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      x1, 0x11111111
    li      x2, 3
    li      x3, 4

    .globl fault_trigger_pc
fault_trigger_pc:
#if SUBCASE == 0
    .word   0x00000000
#elif SUBCASE == 1
    .word   0xFFFFFFFF
#elif SUBCASE == 2
    .word   0x30009073
#elif SUBCASE == 3
    .word   0x30200073
#elif SUBCASE == 4
    .word   0x023100B3
#elif SUBCASE == 5
    .word   0x0000100F
#else
#error "Invalid SUBCASE for VER-FAULT-003"
#endif

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
