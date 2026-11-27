/* Verification Firmware Signature Mailbox & Contract Constants
 * Derived strictly from CON-ADDR-001 v1.1, CON-MEM-001 v1.1, CON-FLT-RST-001 v1.1.
 * NO peripheral register offsets are defined here (BLOCKED awaiting peripheral contract).
 */

#ifndef VERIF_MAILBOX_INC
#define VERIF_MAILBOX_INC

/* Memory Region Bases (CON-ADDR-001 v1.1) */
#define IROM_BASE           0x00000000
#define IROM_TOP_WORD       0x00007FFC
#define DRAM_BASE           0x20000000
#define DRAM_TOP_WORD       0x20007FFC

/* APB3 Slot Bases (CON-ADDR-001 v1.1 — bus boundary ONLY, no register offsets) */
#define APB_UART_SLOT_BASE  0x40000000
#define APB_GPIO_SLOT_BASE  0x40001000
#define APB_TIMER_SLOT_BASE 0x40002000
#define APB_RSVD_SLOT_BASE  0x40003000

/* Verification Signature Mailbox in DRAM (0x2000_7F00 .. 0x2000_7F1F) */
#define MBOX_STATUS_ADDR    0x20007F00
#define MBOX_TESTID_ADDR    0x20007F04
#define MBOX_DETAIL_ADDR    0x20007F08
#define MBOX_SENTINEL_ADDR  0x20007F0C

/* Mailbox Status Magic Words */
#define STATUS_PASS         0xCAFE0001
#define STATUS_FAIL_BASE    0xDEAD0000
#define STATUS_PRE_FAULT    0xAAAA0001
#define SENTINEL_FORBIDDEN  0xBAD0BAD0

/* Fault Codes (CON-FLT-RST-001 v1.1) */
#define FAULT_NONE            0x0
#define FAULT_IF_MISALIGNED   0x1
#define FAULT_IF_UNMAPPED     0x2
#define FAULT_ILLEGAL_INSN    0x3
#define FAULT_ECALL           0x4
#define FAULT_EBREAK          0x5
#define FAULT_DATA_MISALIGNED 0x6
#define FAULT_DATA_UNMAPPED   0x7
#define FAULT_DATA_SIZE_UNSUP 0x8
#define FAULT_APB_SLVERR      0x9
#define FAULT_DATA_RO_WRITE   0xA

#endif /* VERIF_MAILBOX_INC */
