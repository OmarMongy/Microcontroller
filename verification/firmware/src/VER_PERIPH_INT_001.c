/* Test ID: VER-PERIPH-INT-001
 * Requirements: CON-PERIPH-001 (UART + GPIO + Timer), SPEC H2
 * Purpose: Bare-metal C integrated verification program combining:
 *          1. Timer polling delay (COMPARE + AUTO_RELOAD / W1C)
 *          2. GPIO direction/output + 2-FF input echo check
 *          3. UART baud programming (16 clks/bit), 8N1 TX string/byte + RX echo check
 *          4. Verification DRAM mailbox pass/fail reporting (distinct from demo firmware!)
 */

#include <stdint.h>
#include "../include/periph_regs.inc"

#define REG32(addr) (*(volatile uint32_t *)(addr))

static const uint8_t k_tx_seq[4] = { 0x4F, 0x4B, 0x21, 0x55 }; /* "OK!" + 0x55 RX trigger */

static void timer_delay_cycles(uint32_t ticks) {
    REG32(TIMER_CTRL) = 0U;
    REG32(TIMER_STATUS) = (TIMER_STS_MATCH | TIMER_STS_OVF);
    REG32(TIMER_COUNTER) = 0U;
    REG32(TIMER_COMPARE) = ticks;
    REG32(TIMER_CTRL) = TIMER_CTRL_EN;
    while ((REG32(TIMER_STATUS) & TIMER_STS_MATCH) == 0U) {
        /* poll MATCH */
    }
    REG32(TIMER_CTRL) = 0U;
    REG32(TIMER_STATUS) = TIMER_STS_MATCH;
}

int main(void) {
    /* 1. Configure UART BAUD_DIV = 16 for deterministic fast simulation */
    REG32(UART_BAUD_DIV) = 16U;
    if (REG32(UART_BAUD_DIV) != 16U) {
        return 1;
    }

    /* 2. Configure GPIO [3:0] as output, [7:4] as input; pace with Timer */
    REG32(GPIO_DIR) = 0x0FU;
    for (uint32_t v = 0U; v < 4U; ++v) {
        uint32_t pat = (v * 3U) & 0x0FU; /* 0, 3, 6, 9 */
        REG32(GPIO_DATA_OUT) = pat;
        timer_delay_cycles(10U); /* > 2-FF sync delay */
        uint32_t exp_in = ((pat ^ 0x0FU) << 4) | pat;
        if (REG32(GPIO_DATA_IN) != exp_in) {
            return 2;
        }
    }

    /* 3. Transmit .rodata sequence over UART; 0x55 triggers TB BFM RX 0xA3 */
    for (uint32_t i = 0U; i < 4U; ++i) {
        while ((REG32(UART_STATUS) & UART_STS_TX_EMPTY) == 0U) {
            /* wait TX ready */
        }
        REG32(UART_TX_DATA) = (uint32_t)k_tx_seq[i];
        /* Mirror byte lower nibble onto GPIO while transmitting */
        REG32(GPIO_DATA_OUT) = (uint32_t)(k_tx_seq[i] & 0x0FU);
    }

    /* 4. Poll UART RX for 0xA3 reply paced with bounded timer timeout */
    REG32(TIMER_CTRL) = 0U;
    REG32(TIMER_STATUS) = (TIMER_STS_MATCH | TIMER_STS_OVF);
    REG32(TIMER_COUNTER) = 0U;
    REG32(TIMER_COMPARE) = 2000U;
    REG32(TIMER_CTRL) = TIMER_CTRL_EN;
    while ((REG32(UART_STATUS) & UART_STS_RX_VALID) == 0U) {
        if ((REG32(TIMER_STATUS) & TIMER_STS_MATCH) != 0U) {
            return 3; /* RX timeout */
        }
    }
    REG32(TIMER_CTRL) = 0U;

    uint32_t rx = REG32(UART_RX_DATA);
    if (rx != 0xA3U) {
        return 4;
    }

    __asm__ volatile ("fence iorw, iorw" ::: "memory");
    return 0;
}
