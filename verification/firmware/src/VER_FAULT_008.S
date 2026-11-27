/* Test ID: VER-FAULT-008
 * Fault: FAULT_DATA_SIZE_UNSUP (4'h8) — CON-APB3-001 §2 (Option APB-W1), CON-FLT-RST-001 §1.1
 * Subcases (-DSUBCASE=0..5):
 *   0: LB  at 0x4000_0000 (Slot 0)
 *   1: LBU at 0x4000_1000 (Slot 1)
 *   2: LH  at 0x4000_2000 (Slot 2)
 *   3: LHU at 0x4000_0004 (Slot 0)
 *   4: SB  at 0x4000_1004 (Slot 1)
 *   5: SH  at 0x4000_2004 (Slot 2)
 * Expected:
 *   fault_o = 1, fault_code_o = 4'h8, fault_pc_o = fault_trigger_pc,
 *   fault_addr_o = target addr, fault_insn_o = sub-word insn,
 *   ZERO PSELx / APB3 activity, sentinel untouched.
 */

#include "verif_mailbox.inc"

#ifndef SUBCASE
#define SUBCASE 0
#endif

    .section .text.init, "ax"
    .globl _start
_start:
    li      t1, MBOX_TESTID_ADDR
    li      t2, (0x1080 + SUBCASE)
    sw      t2, 0(t1)
    li      t1, MBOX_STATUS_ADDR
    li      t2, STATUS_PRE_FAULT
    sw      t2, 0(t1)
    li      t3, 0x12345678

#if SUBCASE == 0
    li      t0, APB_UART_SLOT_BASE
    .globl fault_trigger_pc
fault_trigger_pc:
    lb      t3, 0(t0)
#elif SUBCASE == 1
    li      t0, APB_GPIO_SLOT_BASE
    .globl fault_trigger_pc
fault_trigger_pc:
    lbu     t3, 0(t0)
#elif SUBCASE == 2
    li      t0, APB_TIMER_SLOT_BASE
    .globl fault_trigger_pc
fault_trigger_pc:
    lh      t3, 0(t0)
#elif SUBCASE == 3
    li      t0, (APB_UART_SLOT_BASE + 4)
    .globl fault_trigger_pc
fault_trigger_pc:
    lhu     t3, 0(t0)
#elif SUBCASE == 4
    li      t0, (APB_GPIO_SLOT_BASE + 4)
    .globl fault_trigger_pc
fault_trigger_pc:
    sb      t3, 0(t0)
#elif SUBCASE == 5
    li      t0, (APB_TIMER_SLOT_BASE + 4)
    .globl fault_trigger_pc
fault_trigger_pc:
    sh      t3, 0(t0)
#else
#error "Invalid SUBCASE for VER-FAULT-008"
#endif

    li      t1, MBOX_SENTINEL_ADDR
    li      t2, SENTINEL_FORBIDDEN
    sw      t2, 0(t1)
1:  j       1b
