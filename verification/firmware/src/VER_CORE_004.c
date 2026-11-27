/* Test ID: VER-CORE-004
 * Requirements: SPEC H1, DEC-ARCH-CORE-001 (Modified Harvard C .rodata + RAM-B),
 *               CON-MEM-001, CON-APB3-001 (Mock slot boundary)
 * Purpose: Bare-metal C test verifying compiler-generated .rodata in IROM (Port B),
 *          .data copy from IROM to DRAM, .bss zeroing, stack frames/calls,
 *          byte/halfword/word struct accesses in DRAM, and volatile APB3 word access.
 */

#include <stdint.h>
#include "../include/verif_mailbox.inc"

static const uint32_t k_ro_words[4] = {
    0x10203040U, 0x8090A0B0U, 0xCAFE1234U, 0x00FF00AAU
};
static const int8_t k_ro_bytes[4] = { -128, -1, 0, 127 };
static const int16_t k_ro_halves[2] = { -32768, 12345 };

static uint32_t g_init_data = 0x55AA1234U;
static uint32_t g_bss_array[4];

typedef struct {
    uint8_t  b0;
    uint8_t  b1;
    uint16_t h1;
    uint32_t w2;
} packed_rec_t;

static uint32_t sum_rodata(const uint32_t *arr, uint32_t count) {
    uint32_t acc = 0U;
    for (uint32_t i = 0U; i < count; ++i) {
        acc += arr[i];
    }
    return acc;
}

int main(void) {
    /* 1. Verify .data copy and .bss zeroing */
    if (g_init_data != 0x55AA1234U) {
        return 1;
    }
    for (uint32_t i = 0U; i < 4U; ++i) {
        if (g_bss_array[i] != 0U) {
            return 2;
        }
    }

    /* 2. Verify .rodata loads via IROM Port B */
    if (sum_rodata(k_ro_words, 4U) != 0x5CADE3CEU) {
        return 3;
    }
    if ((int32_t)k_ro_bytes[0] != -128 || (int32_t)k_ro_bytes[1] != -1 ||
        (int32_t)k_ro_bytes[2] != 0    || (int32_t)k_ro_bytes[3] != 127) {
        return 4;
    }
    if ((int32_t)k_ro_halves[0] != -32768 || (int32_t)k_ro_halves[1] != 12345) {
        return 5;
    }

    /* 3. Verify stack-allocated struct byte/halfword/word writes & reads in DRAM */
    volatile packed_rec_t rec;
    rec.b0 = 0x12U;
    rec.b1 = 0xABU;
    rec.h1 = 0xCDEFU;
    rec.w2 = 0x87654321U;
    if (rec.b0 != 0x12U || rec.b1 != 0xABU || rec.h1 != 0xCDEFU || rec.w2 != 0x87654321U) {
        return 6;
    }

    /* 4. Verify volatile 32-bit APB3 access at Slot 0 base (Mock Completer in TB-CORE-BUS) */
    volatile uint32_t *const apb_slot0 = (volatile uint32_t *)APB_UART_SLOT_BASE;
    *apb_slot0 = 0xA1B2C3D4U;
    if (*apb_slot0 != 0xA1B2C3D4U) {
        return 7;
    }

    /* 5. FENCE compiler/memory barrier */
    __asm__ volatile ("fence iorw, iorw" ::: "memory");
    return 0;
}
