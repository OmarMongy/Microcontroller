// Shared package for RV32I Microcontroller SoC
// Contracts: CON-ADDR-001 v1.1, CON-MEM-001 v1.1, CON-APB3-001 v1.1,
//            CON-FLT-RST-001 v1.1, CON-TOP-001 v1.1, CON-PERIPH-001 v1.0

package soc_pkg;

    // Fault codes (CON-FLT-RST-001 Section 1.1)
    typedef enum logic [3:0] {
        FAULT_NONE            = 4'h0,
        FAULT_IF_MISALIGNED   = 4'h1,
        FAULT_IF_UNMAPPED     = 4'h2,
        FAULT_ILLEGAL_INSN    = 4'h3,
        FAULT_ECALL           = 4'h4,
        FAULT_EBREAK          = 4'h5,
        FAULT_DATA_MISALIGNED = 4'h6,
        FAULT_DATA_UNMAPPED   = 4'h7,
        FAULT_DATA_SIZE_UNSUP = 4'h8,
        FAULT_APB_SLVERR      = 4'h9,
        FAULT_DATA_RO_WRITE   = 4'hA
    } fault_code_e;

    // Data access size encoding (CON-TOP-001 Section 4)
    typedef enum logic [1:0] {
        DMEM_SIZE_BYTE = 2'b00,
        DMEM_SIZE_HALF = 2'b01,
        DMEM_SIZE_WORD = 2'b10
    } dmem_size_e;

    // Address map constants (CON-ADDR-001 Sections 2 & 3)
    localparam logic [16:0] IROM_BASE_PREFIX = 17'h0000_0; // 0x0000_0000 - 0x0000_7FFF (32 KB)
    localparam logic [16:0] DRAM_BASE_PREFIX = 17'h0400_0; // 0x2000_0000 - 0x2000_7FFF (32 KB)

    localparam logic [19:0] APB_UART_PREFIX  = 20'h4000_0; // 0x4000_0000 - 0x4000_0FFF (4 KB)
    localparam logic [19:0] APB_GPIO_PREFIX  = 20'h4000_1; // 0x4000_1000 - 0x4000_1FFF (4 KB)
    localparam logic [19:0] APB_TIMER_PREFIX = 20'h4000_2; // 0x4000_2000 - 0x4000_2FFF (4 KB)

endpackage
