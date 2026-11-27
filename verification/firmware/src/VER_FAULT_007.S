/* Test ID: VER-FAULT-007
 * Fault: FAULT_DATA_RO_WRITE (4'hA) — DEC-ARCH-CORE-002 #2, CON-ADDR-001 §4.2, CON-FLT-RST-001 §1.1
 * Subcases (-DSUBCASE=0..2):
 *   0: SW to 0x0000_0000 (IROM base word)
 *   1: SH to 0x0000_0200 (IROM mid halfword)
 *   2: SB to 0x0000_7FFF (IROM top byte)
 * Expected:
 *   fault_o = 1, fault_code_o = 4'hA, fault_pc_o = fault_trigger_pc,
 *   fault_addr_o = target addr, fault_insn_o = store insn, sentinel untouched.
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x1070 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      t3, 0xDEADBEEF

#if SUBCASE == 0
    li      t0, IROM_BASE
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#elif SUBCASE == 1
    li      t0, 0x00000200
    .globl fault_trigger_pc
fault_trigger_pc:
    sh      t3, 0(t0)
#elif SUBCASE == 2
    li      t0, 0x00007FFF
    .globl fault_trigger_pc
fault_trigger_pc:
    sb      t3, 0(t0)
#else
#error "Invalid SUBCASE for VER-FAULT-007"
#endif

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
