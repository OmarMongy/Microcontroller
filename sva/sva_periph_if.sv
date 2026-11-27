// SVA Checkers: APB3 Peripherals (uart_apb, gpio_apb, timer_apb)
// Derived strictly from CON-PERIPH-001 v1.0 (DEC-ARCH-PERIPH-001) and CON-FLT-RST-001 v1.1.
// Implemented using Verilator 5.032-supported concurrent SVA + auxiliary shadow state.

module sva_uart_apb_if (
  input logic        PCLK,
  input logic        PRESETn,
  input logic        PSEL,
  input logic        PENABLE,
  input logic        PWRITE,
  input logic [31:0] PADDR,
  input logic [31:0] PWDATA,
  input logic        PREADY,
  input logic [31:0] PRDATA,
  input logic        PSLVERR,
  input logic        uart_tx_o
);

  logic uart_xfer, uart_rd;
  assign uart_xfer = PSEL && PENABLE && PREADY;
  assign uart_rd   = uart_xfer && !PWRITE;

  // SVA-UART-001: TX line idle HIGH during reset
  a_uart_001_rst_tx: assert property (@(posedge PCLK) !PRESETn |-> (uart_tx_o == 1'b1));

  // SVA-UART-002: Fixed 0-wait PREADY == 1
  a_uart_002_zero_wait: assert property (@(posedge PCLK) disable iff (!PRESETn)
    (PSEL && PENABLE) |-> PREADY);

  // SVA-UART-003: Exact PSLVERR rules
  a_uart_003_pslverr: assert property (@(posedge PCLK) disable iff (!PRESETn)
    uart_xfer |-> (PSLVERR == (
      !(PADDR[11:0] inside {12'h000, 12'h004, 12'h008, 12'h00C, 12'h010}) ||
      (PWRITE && PADDR[11:0] == 12'h00C) ||
      (!PWRITE && PADDR[11:0] == 12'h008) ||
      (PWRITE && PADDR[11:0] == 12'h010 && PWDATA[23:0] < 24'd2)
    )));

  // SVA-UART-004: Failing read returns PRDATA == 32'h0
  a_uart_004_err_rdata: assert property (@(posedge PCLK) disable iff (!PRESETn)
    (uart_rd && PSLVERR) |-> (PRDATA == 32'h0));

  // Cover properties (COV-SVA-011..015)
  c_uart_011_tx_wr: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (uart_xfer && PWRITE && PADDR[11:0] == 12'h008));
  c_uart_013_rx_rd: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (uart_rd && PADDR[11:0] == 12'h00C));
  c_uart_014_w1c: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (uart_xfer && PWRITE && PADDR[11:0] == 12'h004 && (PWDATA[4] || PWDATA[3])));
  c_uart_015_pslverr: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (uart_xfer && PSLVERR));

endmodule

module sva_gpio_apb_if (
  input logic        PCLK,
  input logic        PRESETn,
  input logic        PSEL,
  input logic        PENABLE,
  input logic        PWRITE,
  input logic [31:0] PADDR,
  input logic [31:0] PWDATA,
  input logic        PREADY,
  input logic [31:0] PRDATA,
  input logic        PSLVERR,
  input logic [7:0]  gpio_o,
  input logic [7:0]  gpio_oe_o
);

  logic        gpio_xfer;
  logic        q_wr_out, q_wr_dir, q_active_out;
  logic [7:0]  q_pwdata, q_gpio_o, q_gpio_oe_o;

  assign gpio_xfer = PSEL && PENABLE && PREADY;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      q_wr_out     <= 1'b0;
      q_wr_dir     <= 1'b0;
      q_active_out <= 1'b0;
      q_pwdata     <= 8'h00;
      q_gpio_o     <= 8'h00;
      q_gpio_oe_o  <= 8'h00;
    end else begin
      q_wr_out     <= (gpio_xfer && PWRITE && PADDR[11:0] == 12'h004);
      q_wr_dir     <= (gpio_xfer && PWRITE && PADDR[11:0] == 12'h008);
      q_active_out <= (gpio_oe_o != 8'h00 && gpio_o != 8'h00);
      q_pwdata     <= PWDATA[7:0];
      q_gpio_o     <= gpio_o;
      q_gpio_oe_o  <= gpio_oe_o;
    end
  end

  // SVA-GPIO-001: Reset outputs
  a_gpio_001_rst: assert property (@(posedge PCLK)
    !PRESETn |-> (gpio_o == 8'h00 && gpio_oe_o == 8'h00));

  // SVA-GPIO-002: Zero wait states
  a_gpio_002_zero_wait: assert property (@(posedge PCLK) disable iff (!PRESETn)
    (PSEL && PENABLE) |-> PREADY);

  // SVA-GPIO-003: Exact PSLVERR rules
  a_gpio_003_pslverr: assert property (@(posedge PCLK) disable iff (!PRESETn)
    gpio_xfer |-> (PSLVERR == (
      !(PADDR[11:0] inside {12'h000, 12'h004, 12'h008}) ||
      (PWRITE && PADDR[11:0] == 12'h000)
    )));

  // SVA-GPIO-004: Output update & stability
  a_gpio_004a_out_upd: assert property (@(posedge PCLK) disable iff (!PRESETn)
    q_wr_out |-> (gpio_o == q_pwdata));
  a_gpio_004b_out_hold: assert property (@(posedge PCLK) disable iff (!PRESETn)
    !q_wr_out |-> (gpio_o == q_gpio_o));
  a_gpio_004c_dir_upd: assert property (@(posedge PCLK) disable iff (!PRESETn)
    q_wr_dir |-> (gpio_oe_o == q_pwdata));
  a_gpio_004d_dir_hold: assert property (@(posedge PCLK) disable iff (!PRESETn)
    !q_wr_dir |-> (gpio_oe_o == q_gpio_oe_o));

  // Cover property (COV-SVA-016)
  c_gpio_016_io_active: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (q_active_out && gpio_xfer && !PWRITE && PADDR[11:0] == 12'h000 && PRDATA[7:0] != 8'h00));

endmodule

module sva_timer_apb_if (
  input logic        PCLK,
  input logic        PRESETn,
  input logic        PSEL,
  input logic        PENABLE,
  input logic        PWRITE,
  input logic [31:0] PADDR,
  input logic [31:0] PWDATA,
  input logic        PREADY,
  input logic [31:0] PRDATA,
  input logic        PSLVERR
);

  logic tmr_xfer;
  assign tmr_xfer = PSEL && PENABLE && PREADY;

  // SVA-TIMER-002: Zero wait states
  a_tmr_002_zero_wait: assert property (@(posedge PCLK) disable iff (!PRESETn)
    (PSEL && PENABLE) |-> PREADY);

  // SVA-TIMER-003: Exact PSLVERR rules
  a_tmr_003_pslverr: assert property (@(posedge PCLK) disable iff (!PRESETn)
    tmr_xfer |-> (PSLVERR == !(PADDR[11:0] inside {12'h000, 12'h004, 12'h008, 12'h00C})));

  // SVA-TIMER-004: CLR_CNT WO/SC & reserved bits read 0 in TIMER_CTRL
  a_tmr_004_ctrl_ro0: assert property (@(posedge PCLK) disable iff (!PRESETn)
    (tmr_xfer && !PWRITE && PADDR[11:0] == 12'h000) |-> (PRDATA[31:2] == 30'h0));

  // Cover property (COV-SVA-019)
  c_tmr_019_w1c: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (tmr_xfer && PWRITE && PADDR[11:0] == 12'h004 && PWDATA[1:0] == 2'b11));

endmodule
