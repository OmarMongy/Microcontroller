/* Verification Firmware Linker Script
 * Authority: CON-ADDR-001 v1.1, CON-MEM-001 v1.1, DEC-ARCH-CORE-001
 * Modified Harvard: .text and .rodata reside in IROM; .data/.bss/stack/mailbox in DRAM.
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IROM (rx) : ORIGIN = 0x00000000, LENGTH = 32K
    DRAM (rw) : ORIGIN = 0x20000000, LENGTH = 32K
}

SECTIONS
{
    .text.init 0x00000000 : ALIGN(4)
    {
        KEEP(*(.text.init))
    } > IROM

    .text : ALIGN(4)
    {
        *(.text*)
    } > IROM

    /* Modified Harvard: .rodata resides in IROM and is loaded via irom_local Port B */
    .rodata : ALIGN(4)
    {
        *(.rodata*)
        *(.srodata*)
    } > IROM

    . = ALIGN(4);
    _etext = .;
    _sidata = LOADADDR(.data);

    .data : ALIGN(4)
    {
        _sdata = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        _edata = .;
    } > DRAM AT > IROM

    .bss (NOLOAD) : ALIGN(4)
    {
        _sbss = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > DRAM

    /* Reserve top 256 bytes of DRAM (0x2000_7F00..0x2000_7FFF) for testbench mailbox */
    _stack_top = 0x20007E00;
    _mailbox_base = 0x20007F00;

    ASSERT((_sidata + (_edata - _sdata)) <= 0x00008000, "ERROR: IROM 32KB overflow")
    ASSERT(_ebss <= 0x20007000, "ERROR: DRAM static allocation overlaps stack/mailbox")
}
