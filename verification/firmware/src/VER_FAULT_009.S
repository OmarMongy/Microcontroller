/* Test ID: VER-FAULT-009
 * Fault: FAULT_DATA_MISALIGNED (4'h6) — CON-MEM-001 §2.5, CON-APB3-001 §2, CON-FLT-RST-001 §1.1
 * Subcases (-DSUBCASE=0..6):
 *   0: LH at 0x0000_0201 (IROM odd halfword)
 *   1: LW at 0x0000_0202 (IROM non-4B word)
 *   2: LHU at 0x2000_0003 (DRAM odd halfword)
 *   3: LW at 0x2000_0001 (DRAM non-4B word)
 *   4: SH at 0x2000_0001 (DRAM odd halfword store)
 *   5: SW at 0x2000_0003 (DRAM non-4B word store)
 *   6: LW at 0x4000_0002 (APB3 Slot 0 non-4B word)
 * Expected:
 *   fault_o = 1, fault_code_o = 4'h6, fault_pc_o = fault_trigger_pc,
 *   fault_addr_o = target addr, fault_insn_o = misaligned insn, zero bus/RAM mutation.
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x1090 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      t3, 0xAABBCCDD

#if SUBCASE == 0
    li      t0, 0x00000201
    .globl fault_trigger_pc
fault_trigger_pc:
    lh      t3, 0(t0)
#elif SUBCASE == 1
    li      t0, 0x00000202
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#elif SUBCASE == 2
    li      t0, 0x20000003
    .globl fault_trigger_pc
fault_trigger_pc:
    lhu     t3, 0(t0)
#elif SUBCASE == 3
    li      t0, 0x20000001
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#elif SUBCASE == 4
    li      t0, 0x20000001
    .globl fault_trigger_pc
fault_trigger_pc:
    sh      t3, 0(t0)
#elif SUBCASE == 5
    li      t0, 0x20000003
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#elif SUBCASE == 6
    li      t0, (APB_UART_SLOT_BASE + 2)
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#else
#error "Invalid SUBCASE for VER-FAULT-009"
#endif

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
