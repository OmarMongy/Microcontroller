/* Test ID: VER-FAULT-011
 * Requirements: CON-FLT-RST-001 §1.2 (Fault Priority Matrix)
 * Subcases (-DSUBCASE=0..4):
 *   0: IF_UNMAPPED (P1) > IF_MISALIGNED (P2): JALR to 0x0000_8002 -> 4'h2
 *   1: DATA_UNMAPPED (P4) > DATA_MISALIGNED (P7): SH to 0x0000_8001 -> 4'h7
 *   2: DATA_UNMAPPED (P4) > DATA_SIZE_UNSUP (P6) > MISALIGNED (P7): SH to 0x4000_3001 -> 4'h7
 *   3: DATA_RO_WRITE (P5) > DATA_MISALIGNED (P7): SW to 0x0000_0102 -> 4'hA
 *   4: DATA_SIZE_UNSUP (P6) > DATA_MISALIGNED (P7): LH to 0x4000_0001 -> 4'h8
 * Expected:
 *   fault_o = 1, fault_code_o = highest-priority fault code listed above,
 *   sentinel untouched.
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x10B0 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      t3, 0xCAFEBABE

#if SUBCASE == 0
    li      t0, 0x00008002
    .globl fault_trigger_pc
fault_trigger_pc:
    jalr    x0, t0, 0
#elif SUBCASE == 1
    li      t0, 0x00008001
    .globl fault_trigger_pc
fault_trigger_pc:
    sh      t3, 0(t0)
#elif SUBCASE == 2
    li      t0, 0x40003001
    .globl fault_trigger_pc
fault_trigger_pc:
    sh      t3, 0(t0)
#elif SUBCASE == 3
    li      t0, 0x00000102
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#elif SUBCASE == 4
    li      t0, (APB_UART_SLOT_BASE + 1)
    .globl fault_trigger_pc
fault_trigger_pc:
    lh      t3, 0(t0)
#else
#error "Invalid SUBCASE for VER-FAULT-011"
#endif

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
