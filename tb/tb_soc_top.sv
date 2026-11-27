// Full-Chip soc_top Testbench Harness (CON-TOP-001 v1.1, CON-PERIPH-001 v1.0)
// Includes:
//   - 50 MHz clk + asynchronous rst_n reset waveforms
//   - UART 8N1 serial BFM (TX decoder + TX-triggered RX stimulus/overrun/frame-err)
//   - GPIO BFM (ECHO_INV mode for VER-GPIO-001 / VER-PERIPH-INT-001)
//   - Golden RV32I ISS scoreboard + Functional Coverage Collector
//   - Watchdog timeout & DRAM mailbox + fault_*_o checker

module tb_soc_top #(
  parameter string INIT_FILE = ""
);
  import tb_pkg::*;

  logic        clk   = 1'b0;
  logic        rst_n = 1'b0;
  logic        uart_rx_i = 1'b1;
  logic        uart_tx_o;
  logic [7:0]  gpio_i;
  logic [7:0]  gpio_o;
  logic [7:0]  gpio_oe_o;
  logic        fault_o;
  logic [3:0]  fault_code_o;
  logic [31:0] fault_pc_o;
  logic [31:0] fault_addr_o;
  logic [31:0] fault_insn_o;

  always #10 clk = ~clk; // 50 MHz

  // DUT: soc_top (CON-TOP-001 §3 exact port list; rtl/soc_top.sv uses IROM_INIT_FILE)
  soc_top #(.IROM_INIT_FILE(INIT_FILE)) u_dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .uart_rx_i    (uart_rx_i),
    .uart_tx_o    (uart_tx_o),
    .gpio_i       (gpio_i),
    .gpio_o       (gpio_o),
    .gpio_oe_o    (gpio_oe_o),
    .fault_o      (fault_o),
    .fault_code_o (fault_code_o),
    .fault_pc_o   (fault_pc_o),
    .fault_addr_o (fault_addr_o),
    .fault_insn_o (fault_insn_o)
  );

  // Mailbox write snoop on soc_top internal DRAM bus
  logic [31:0] mbox_status, mbox_testid, mbox_detail, mbox_sentinel;
  always_ff @(posedge clk) begin
    if (u_dut.sys_rst_n && u_dut.dram_req && u_dut.dram_we && u_dut.dram_be == 4'b1111) begin
      case ({17'b0010_0000_0000_0000_0, u_dut.dram_addr})
        MBOX_STATUS_ADDR:   mbox_status   <= u_dut.dram_wdata;
        MBOX_TESTID_ADDR:   mbox_testid   <= u_dut.dram_wdata;
        MBOX_DETAIL_ADDR:   mbox_detail   <= u_dut.dram_wdata;
        MBOX_SENTINEL_ADDR: mbox_sentinel <= u_dut.dram_wdata;
        default: ;
      endcase
    end
  end

  // Golden ISS Scoreboard & Coverage Collector
  int unsigned sb_retires, sb_errors;
  logic apb_xfer_done_sig, pready_mux_snoop, pslverr_mux_snoop;
  logic [31:0] prdata_mux_snoop;
  always_comb begin
    pready_mux_snoop  = 1'b1;
    prdata_mux_snoop  = 32'h0;
    pslverr_mux_snoop = 1'b0;
    if (u_dut.psel_uart) begin
      pready_mux_snoop  = u_dut.pready_uart;
      prdata_mux_snoop  = u_dut.prdata_uart;
      pslverr_mux_snoop = u_dut.pslverr_uart;
    end else if (u_dut.psel_gpio) begin
      pready_mux_snoop  = u_dut.pready_gpio;
      prdata_mux_snoop  = u_dut.prdata_gpio;
      pslverr_mux_snoop = u_dut.pslverr_gpio;
    end else if (u_dut.psel_timer) begin
      pready_mux_snoop  = u_dut.pready_timer;
      prdata_mux_snoop  = u_dut.prdata_timer;
      pslverr_mux_snoop = u_dut.pslverr_timer;
    end
  end
  assign apb_xfer_done_sig = (u_dut.psel_uart || u_dut.psel_gpio || u_dut.psel_timer) &&
                             u_dut.penable && pready_mux_snoop;

  rv32i_golden_iss #(.INIT_FILE(INIT_FILE)) u_iss (
    .clk              (clk),
    .sys_rst_n        (u_dut.sys_rst_n),
    .dut_pc           ({17'h0, u_dut.irom_addr}),
    .dut_dmem_stall   (u_dut.dmem_stall),
    .dut_fault_valid  (fault_o),
    .dut_fault_code   (fault_code_o),
    .dut_fault_pc     (fault_pc_o),
    .dut_fault_addr   (fault_addr_o),
    .dut_fault_insn   (fault_insn_o),
    .apb_xfer_done    (apb_xfer_done_sig),
    .apb_xfer_write   (u_dut.pwrite),
    .apb_xfer_addr    (u_dut.paddr),
    .apb_xfer_wdata   (u_dut.pwdata),
    .apb_xfer_rdata   (prdata_mux_snoop),
    .apb_xfer_slverr  (pslverr_mux_snoop),
    .dut_rf_we        (1'b0),
    .dut_rf_waddr     (5'd0),
    .dut_rf_wdata     (32'h0),
    .sb_retire_count  (sb_retires),
    .sb_error_count   (sb_errors)
  );

  tb_cov_collector u_cov (
    .clk          (clk),
    .sys_rst_n    (u_dut.sys_rst_n),
    .retire_valid (!u_dut.dmem_stall && !fault_o),
    .retire_pc    ({17'h0, u_dut.irom_addr}),
    .retire_insn  (u_dut.irom_rdata),
    .dmem_stall   (u_dut.dmem_stall),
    .dmem_req     (u_dut.dmem_req),
    .dmem_we      (u_dut.dmem_we),
    .dmem_size    (u_dut.dmem_size),
    .dmem_addr    (u_dut.dmem_addr),
    .dram_be      (u_dut.dram_be),
    .psel_uart    (u_dut.psel_uart),
    .psel_gpio    (u_dut.psel_gpio),
    .psel_timer   (u_dut.psel_timer),
    .penable      (u_dut.penable),
    .pwrite       (u_dut.pwrite),
    .paddr        (u_dut.paddr),
    .pready       (pready_mux_snoop),
    .pslverr      (pslverr_mux_snoop),
    .fault_o      (fault_o),
    .fault_code_o (fault_code_o)
  );

  // GPIO BFM
  int unsigned gpio_mode = 0; // 0 = zero, 1 = ECHO_INV {~gpio_o[3:0], gpio_o[3:0]}
  always_comb begin
    if (!rst_n) begin
      gpio_i = 8'h00;
    end else if (gpio_mode == 1 && gpio_oe_o == 8'h0F) begin
      gpio_i = {~gpio_o[3:0], gpio_o[3:0]};
    end else begin
      gpio_i = 8'h00;
    end
  end

  // UART 8N1 BFM (TX Monitor + TX-Triggered RX Injector)
  int unsigned uart_baud_div = 16;
  byte         uart_rx_queue[$];
  bit          uart_rx_ferr_queue[$];

  task automatic uart_send_frame(input logic [7:0] data, input logic bad_stop);
    int unsigned bit_clks;
    bit_clks = uart_baud_div;
    uart_rx_i = 1'b0;
    repeat (bit_clks) @(posedge clk);
    for (int i = 0; i < 8; i++) begin
      uart_rx_i = data[i];
      repeat (bit_clks) @(posedge clk);
    end
    uart_rx_i = bad_stop ? 1'b0 : 1'b1;
    repeat (bit_clks) @(posedge clk);
    uart_rx_i = 1'b1;
    repeat (bit_clks) @(posedge clk);
  endtask

  initial begin
    uart_rx_i = 1'b1;
    forever begin
      @(posedge clk);
      if (rst_n && uart_rx_queue.size() > 0) begin
        byte b;
        bit  fe;
        b  = uart_rx_queue.pop_front();
        fe = uart_rx_ferr_queue.pop_front();
        uart_send_frame(b, fe);
      end
    end
  end

  initial begin
    forever begin
      logic [7:0] rx_byte;
      logic       stop_bit;
      @(negedge uart_tx_o);
      if (!rst_n) continue;
      repeat (uart_baud_div / 2) @(posedge clk);
      if (uart_tx_o !== 1'b0) continue;
      for (int i = 0; i < 8; i++) begin
        repeat (uart_baud_div) @(posedge clk);
        rx_byte[i] = uart_tx_o;
      end
      repeat (uart_baud_div) @(posedge clk);
      stop_bit = uart_tx_o;
      if (stop_bit !== 1'b1) begin
        $fatal(1, "[UART_BFM] ERROR: TX framing error (stop_bit=0) byte=%h at %0t", rx_byte, $time);
      end else begin
        $display("[UART_BFM] Decoded TX byte=0x%02h at %0t", rx_byte, $time);
        if (rx_byte == 8'h55) begin
          uart_rx_queue.push_back(8'hA3);
          uart_rx_ferr_queue.push_back(1'b0);
        end else if (rx_byte == 8'h56) begin
          uart_rx_queue.push_back(8'h3C);
          uart_rx_ferr_queue.push_back(1'b0);
          uart_rx_queue.push_back(8'h7E);
          uart_rx_ferr_queue.push_back(1'b0);
        end else if (rx_byte == 8'h57) begin
          uart_rx_queue.push_back(8'hC1);
          uart_rx_ferr_queue.push_back(1'b1);
        end
      end
    end
  end

  // Main Simulation Sequence
  int unsigned exp_fault_code = 5; // FAULT_EBREAK
  int unsigned max_cycles     = 100000;
  int unsigned reset_recovery = 0;
  int unsigned rst_during_ld  = 0;
  logic [31:0] exp_pc_hex     = 32'h0;
  logic        check_exp_pc   = 1'b0;
  logic [31:0] exp_addr_hex   = 32'h0;
  logic        check_exp_addr = 1'b0;
  logic [31:0] exp_insn_hex   = 32'h0;
  logic        check_exp_insn = 1'b0;
  logic [31:0] exp_status_hex = STATUS_PASS;
  string       mem_file       = "";

  initial begin
    mbox_status   = 32'h0;
    mbox_testid   = 32'h0;
    mbox_detail   = 32'h0;
    mbox_sentinel = 32'h0;

    void'($value$plusargs("UART_BAUD_DIV=%d", uart_baud_div));
    void'($value$plusargs("GPIO_MODE=%d", gpio_mode));
    void'($value$plusargs("EXP_FAULT=%d", exp_fault_code));
    void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
    void'($value$plusargs("RESET_RECOVERY=%d", reset_recovery));
    void'($value$plusargs("RST_DURING_LD=%d", rst_during_ld));
    if ($value$plusargs("EXP_PC_HEX=%h", exp_pc_hex))     check_exp_pc   = 1'b1;
    if ($value$plusargs("EXP_ADDR_HEX=%h", exp_addr_hex)) check_exp_addr = 1'b1;
    if ($value$plusargs("EXP_INSN_HEX=%h", exp_insn_hex)) check_exp_insn = 1'b1;
    void'($value$plusargs("EXP_STATUS_HEX=%h", exp_status_hex));

    // Verify reset pin defaults while rst_n == 0 and optionally load +MEM_FILE=
    rst_n = 1'b0;
    #1;
    if ($value$plusargs("MEM_FILE=%s", mem_file)) begin
      for (int i = 0; i < IROM_WORDS; i++) u_dut.u_irom_local.mem[i] = 32'h0;
      $readmemh(mem_file, u_dut.u_irom_local.mem);
      u_iss.load_irom(mem_file);
    end
    #24;
    if (uart_tx_o !== 1'b1 || gpio_oe_o !== 8'h00 || gpio_o !== 8'h00 || fault_o !== 1'b0) begin
      $fatal(1, "[TB_SOC_TOP] FAIL: Reset pin check failed (tx=%b oe=%h o=%h fault=%b)",
             uart_tx_o, gpio_oe_o, gpio_o, fault_o);
    end
    #10;
    rst_n = 1'b1;

    // Optional reset during 2-cycle local load (VER-RST-002 Subcase B)
    if (rst_during_ld != 0) begin
      wait (u_dut.irom_dreq || (u_dut.dram_req && !u_dut.dram_we));
      @(posedge clk); // C1: local_rd_valid == 1
      #3;
      rst_n = 1'b0;
      #30;
      rst_n = 1'b1;
    end

    // Wait for fault_o / halt or timeout
    for (int unsigned c = 0; c < max_cycles; c++) begin
      @(posedge clk);
      if (fault_o) break;
    end

    if (!fault_o) begin
      $fatal(1, "[TB_SOC_TOP] FAIL: Watchdog timeout (%0d cycles) without fault_o/EBREAK", max_cycles);
    end

    if (fault_code_o !== exp_fault_code[3:0]) begin
      $fatal(1, "[TB_SOC_TOP] FAIL: Expected fault_code_o=%0h got=%0h pc=%h addr=%h insn=%h",
             exp_fault_code[3:0], fault_code_o, fault_pc_o, fault_addr_o, fault_insn_o);
    end

    if (check_exp_pc && (fault_pc_o !== exp_pc_hex)) begin
      $fatal(1, "[TB_SOC_TOP] FAIL: Expected fault_pc_o=%h got=%h", exp_pc_hex, fault_pc_o);
    end

    if (check_exp_addr && (fault_addr_o !== exp_addr_hex)) begin
      $fatal(1, "[TB_SOC_TOP] FAIL: Expected fault_addr_o=%h got=%h", exp_addr_hex, fault_addr_o);
    end

    if (check_exp_insn && (fault_insn_o !== exp_insn_hex)) begin
      $fatal(1, "[TB_SOC_TOP] FAIL: Expected fault_insn_o=%h got=%h", exp_insn_hex, fault_insn_o);
    end

    if (mbox_status !== exp_status_hex) begin
      $fatal(1, "[TB_SOC_TOP] FAIL: MBOX_STATUS=%h (expected=%h), detail=%h",
             mbox_status, exp_status_hex, mbox_detail);
    end

    if (mbox_sentinel !== 32'h0) begin
      $fatal(1, "[TB_SOC_TOP] FAIL: Sentinel mutated (%h) after fault!", mbox_sentinel);
    end

    if (sb_errors != 0) begin
      $fatal(1, "[TB_SOC_TOP] FAIL: Golden ISS reported %0d mismatches!", sb_errors);
    end

    // Optional reset-from-fault recovery test (VER-RST-002 Subcase C)
    if (reset_recovery != 0) begin
      #25;
      rst_n = 1'b0;
      #25;
      if (fault_o !== 1'b0 || fault_code_o !== 4'h0) begin
        $fatal(1, "[TB_SOC_TOP] FAIL: fault_o did not clear on rst_n=0");
      end
      mbox_status   = 32'h0;
      mbox_sentinel = 32'h0;
      rst_n = 1'b1;
      for (int unsigned c = 0; c < max_cycles; c++) begin
        @(posedge clk);
        if (fault_o) break;
      end
      if (!fault_o || fault_code_o !== exp_fault_code[3:0] || sb_errors != 0) begin
        $fatal(1, "[TB_SOC_TOP] FAIL: Recovery run failed (fault=%b code=%h sb_errors=%0d)",
               fault_o, fault_code_o, sb_errors);
      end
    end

    u_cov.print_summary();
    $display("[TB_SOC_TOP] PASS: testid=%h fault=%s pc=%h addr=%h insn=%h retires=%0d",
             mbox_testid, fault_name(fault_code_o), fault_pc_o, fault_addr_o, fault_insn_o, sb_retires);
    $finish;
  end

endmodule
