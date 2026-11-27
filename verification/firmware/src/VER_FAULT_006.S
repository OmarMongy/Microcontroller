/* Test ID: VER-FAULT-006
 * Fault: FAULT_DATA_UNMAPPED (4'h7) — CON-ADDR-001 §2, §3, §4.2, CON-FLT-RST-001 §1.1
 * Subcases (-DSUBCASE=0..5):
 *   0: LW at 0x0000_8000 (Gap 0 start — right after IROM)
 *   1: SW at 0x1FFF_FFFC (Gap 0 end — right before DRAM)
 *   2: LW at 0x2000_8000 (Gap 1 start — right after DRAM)
 *   3: SW at 0x4000_3000 (Reserved APB3 Slot 3 base)
 *   4: LW at 0x4000_FFFC (Reserved APB3 Slot 15 top word)
 *   5: LW at 0x4001_0000 (Gap 2 start — right after APB3 window)
 * Expected:
 *   fault_o = 1, fault_code_o = 4'h7, fault_pc_o = fault_trigger_pc,
 *   fault_addr_o = target addr, fault_insn_o = LW/SW insn, zero APB/DRAM/IROM_B activity.
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x1060 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      t3, 0x12345678          /* rd sentinel for LW cases */

#if SUBCASE == 0
    li      t0, 0x00008000
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#elif SUBCASE == 1
    li      t0, 0x1FFFFFFC
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#elif SUBCASE == 2
    li      t0, 0x20008000
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#elif SUBCASE == 3
    li      t0, 0x40003000
    .globl fault_trigger_pc
fault_trigger_pc:
    sw      t3, 0(t0)
#elif SUBCASE == 4
    li      t0, 0x4000FFFC
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#elif SUBCASE == 5
    li      t0, 0x40010000
    .globl fault_trigger_pc
fault_trigger_pc:
    lw      t3, 0(t0)
#else
#error "Invalid SUBCASE for VER-FAULT-006"
#endif

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
