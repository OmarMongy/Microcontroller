/* Test ID: VER-FAULT-002
 * Fault: FAULT_IF_MISALIGNED (4'h1) — CON-ADDR-001 §4.1, CON-FLT-RST-001 §1.1
 * Subcases (-DSUBCASE=0..1):
 *   0: JALR to 0x0000_0202 (inside IROM, pc[1:0] == 2'b10)
 *   1: JALR with raw addr 0x0000_0203 (RV32I JALR clears bit 0 -> target 0x0000_0202, still misaligned!)
 * Expected:
 *   fault_o = 1, fault_code_o = 4'h1, fault_pc_o = 0x0000_0202, fault_addr_o = 0x0000_0202, fault_insn_o = 32'h0
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x1020 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)

#if SUBCASE == 0
    li      t0, 0x00000202
#elif SUBCASE == 1
    li      t0, 0x00000203
#else
#error "Invalid SUBCASE for VER-FAULT-002"
#endif

    .globl fault_trigger_pc
fault_trigger_pc:
    jalr    x0, t0, 0

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
