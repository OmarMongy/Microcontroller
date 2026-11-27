/* Peripheral Register Map Constants (CON-PERIPH-001 v1.0, DEC-ARCH-PERIPH-001)
 * Used by SOC_VB_002 peripheral verification firmware.
 */

#ifndef PERIPH_REGS_INC
#define PERIPH_REGS_INC

#include "verif_mailbox.inc"

/* UART (uart_apb) — Base 0x4000_0000 */
#define UART_CTRL           (APB_UART_SLOT_BASE + 0x000)
#define UART_STATUS         (APB_UART_SLOT_BASE + 0x004)
#define UART_TX_DATA        (APB_UART_SLOT_BASE + 0x008)
#define UART_RX_DATA        (APB_UART_SLOT_BASE + 0x00C)
#define UART_BAUD_DIV       (APB_UART_SLOT_BASE + 0x010)
#define UART_UNIMPL_LOW     (APB_UART_SLOT_BASE + 0x014)
#define UART_UNIMPL_HIGH    (APB_UART_SLOT_BASE + 0xFFC)

#define UART_CTRL_TX_EN     (1 << 0)
#define UART_CTRL_RX_EN     (1 << 1)

#define UART_STS_TX_BUSY      (1 << 0)
#define UART_STS_TX_EMPTY     (1 << 1)
#define UART_STS_RX_VALID     (1 << 2)
#define UART_STS_RX_OVERRUN   (1 << 3)
#define UART_STS_RX_FRAME_ERR (1 << 4)

#define UART_BAUD_DIV_RST   434

/* GPIO (gpio_apb) — Base 0x4000_1000 */
#define GPIO_DATA_IN        (APB_GPIO_SLOT_BASE + 0x000)
#define GPIO_DATA_OUT       (APB_GPIO_SLOT_BASE + 0x004)
#define GPIO_DIR            (APB_GPIO_SLOT_BASE + 0x008)
#define GPIO_UNIMPL_LOW     (APB_GPIO_SLOT_BASE + 0x00C)
#define GPIO_UNIMPL_HIGH    (APB_GPIO_SLOT_BASE + 0xFFC)

/* Timer (timer_apb) — Base 0x4000_2000 */
#define TIMER_CTRL          (APB_TIMER_SLOT_BASE + 0x000)
#define TIMER_STATUS        (APB_TIMER_SLOT_BASE + 0x004)
#define TIMER_COUNTER       (APB_TIMER_SLOT_BASE + 0x008)
#define TIMER_COMPARE       (APB_TIMER_SLOT_BASE + 0x00C)
#define TIMER_UNIMPL_LOW    (APB_TIMER_SLOT_BASE + 0x010)
#define TIMER_UNIMPL_HIGH   (APB_TIMER_SLOT_BASE + 0xFFC)

#define TIMER_CTRL_EN         (1 << 0)
#define TIMER_CTRL_AUTO_RLD   (1 << 1)
#define TIMER_CTRL_CLR_CNT    (1 << 2)

#define TIMER_STS_MATCH       (1 << 0)
#define TIMER_STS_OVF         (1 << 1)

#endif /* PERIPH_REGS_INC */
