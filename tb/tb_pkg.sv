// Shared Verification Package for RV32I Microcontroller SoC (SOC_VB_002)
// Derived strictly from CON-ADDR-001, CON-MEM-001, CON-APB3-001, CON-FLT-RST-001,
// CON-TOP-001, and CON-PERIPH-001.

package tb_pkg;

  // Address Map Constants (CON-ADDR-001 v1.1)
  localparam logic [31:0] IROM_BASE           = 32'h0000_0000;
  localparam logic [31:0] IROM_END_INCL       = 32'h0000_7FFF;
  localparam logic [31:0] DRAM_BASE           = 32'h2000_0000;
  localparam logic [31:0] DRAM_END_INCL       = 32'h2000_7FFF;
  localparam logic [31:0] APB_UART_BASE       = 32'h4000_0000;
  localparam logic [31:0] APB_GPIO_BASE       = 32'h4000_1000;
  localparam logic [31:0] APB_TIMER_BASE      = 32'h4000_2000;
  localparam logic [31:0] APB_RSVD_BASE       = 32'h4000_3000;
  localparam logic [31:0] APB_END_INCL        = 32'h4000_FFFF;

  localparam int unsigned IROM_WORDS          = 8192;
  localparam int unsigned DRAM_WORDS          = 8192;

  // DRAM Signature Mailbox Constants (TEST_MANIFEST.md)
  localparam logic [31:0] MBOX_STATUS_ADDR    = 32'h2000_7F00;
  localparam logic [31:0] MBOX_TESTID_ADDR    = 32'h2000_7F04;
  localparam logic [31:0] MBOX_DETAIL_ADDR    = 32'h2000_7F08;
  localparam logic [31:0] MBOX_SENTINEL_ADDR  = 32'h2000_7F0C;

  localparam logic [31:0] STATUS_PASS         = 32'hCAFE_0001;
  localparam logic [31:0] STATUS_PRE_FAULT    = 32'hAAAA_0001;
  localparam logic [31:0] SENTINEL_FORBIDDEN  = 32'hBAD0_BAD0;

  // Fault Codes (CON-FLT-RST-001 v1.1)
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

  // Peripheral Register Offsets (CON-PERIPH-001 v1.0)
  localparam logic [11:0] UART_CTRL_OFF       = 12'h000;
  localparam logic [11:0] UART_STATUS_OFF     = 12'h004;
  localparam logic [11:0] UART_TX_DATA_OFF    = 12'h008;
  localparam logic [11:0] UART_RX_DATA_OFF    = 12'h00C;
  localparam logic [11:0] UART_BAUD_DIV_OFF   = 12'h010;

  localparam logic [11:0] GPIO_DATA_IN_OFF    = 12'h000;
  localparam logic [11:0] GPIO_DATA_OUT_OFF   = 12'h004;
  localparam logic [11:0] GPIO_DIR_OFF        = 12'h008;

  localparam logic [11:0] TIMER_CTRL_OFF      = 12'h000;
  localparam logic [11:0] TIMER_STATUS_OFF    = 12'h004;
  localparam logic [11:0] TIMER_COUNTER_OFF   = 12'h008;
  localparam logic [11:0] TIMER_COMPARE_OFF   = 12'h00C;

  // Helper predicates matching CON-ADDR-001 exact decode equations
  function automatic logic is_in_irom(input logic [31:0] addr);
    return (addr[31:15] == 17'h0000_0);
  endfunction

  function automatic logic is_in_dram(input logic [31:0] addr);
    return (addr[31:15] == 17'b0010_0000_0000_0000_0);
  endfunction

  function automatic logic is_in_apb_pop(input logic [31:0] addr);
    return (addr[31:12] == 20'h4000_0) ||
           (addr[31:12] == 20'h4000_1) ||
           (addr[31:12] == 20'h4000_2);
  endfunction

  function automatic string fault_name(input logic [3:0] code);
    case (code)
      FAULT_NONE:            return "FAULT_NONE";
      FAULT_IF_MISALIGNED:   return "FAULT_IF_MISALIGNED";
      FAULT_IF_UNMAPPED:     return "FAULT_IF_UNMAPPED";
      FAULT_ILLEGAL_INSN:    return "FAULT_ILLEGAL_INSN";
      FAULT_ECALL:           return "FAULT_ECALL";
      FAULT_EBREAK:          return "FAULT_EBREAK";
      FAULT_DATA_MISALIGNED: return "FAULT_DATA_MISALIGNED";
      FAULT_DATA_UNMAPPED:   return "FAULT_DATA_UNMAPPED";
      FAULT_DATA_SIZE_UNSUP: return "FAULT_DATA_SIZE_UNSUP";
      FAULT_APB_SLVERR:      return "FAULT_APB_SLVERR";
      FAULT_DATA_RO_WRITE:   return "FAULT_DATA_RO_WRITE";
      default:               return "FAULT_RESERVED";
    endcase
  endfunction

endpackage
