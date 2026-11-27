/* Test ID: VER-FAULT-001
 * Fault: FAULT_IF_UNMAPPED (4'h2) — CON-ADDR-001 §4.1, CON-FLT-RST-001 §1.1
 * Subcases (-DSUBCASE=0..2):
 *   0: JALR to 0x0000_8000 (first byte past IROM)
 *   1: JALR to 0x2000_0000 (DRAM base — non-executable under Harvard)
 *   2: JALR to 0x4000_0000 (APB3 base — non-executable)
 * Expected:
 *   MBOX_STATUS_ADDR (0x2000_7F00) = 0xAAAA_0001 (STATUS_PRE_FAULT)
 *   MBOX_SENTINEL_ADDR (0x2000_7F0C) = 0x0000_0000 (never written)
 *   fault_o = 1, fault_code_o = 4'h2, fault_pc_o = target, fault_addr_o = target, fault_insn_o = 32'h0
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x1010 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)

#if SUBCASE == 0
    li      t0, 0x00008000
#elif SUBCASE == 1
    li      t0, DRAM_BASE
#elif SUBCASE == 2
    li      t0, APB_UART_SLOT_BASE
#else
#error "Invalid SUBCASE for VER-FAULT-001"
#endif

    .globl fault_trigger_pc
fault_trigger_pc:
    jalr    x0, t0, 0

    /* Sentinel: must NEVER execute */
    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
