// Core & APB3 Bus-Boundary Testbench Harness (VER-CORE-003, VER-BUS-001, VER-FAULT-010, VER-RST-002)
// Instantiates core modules + 3 Mock APB3 Completers strictly from frozen contracts:
// CON-ADDR-001, CON-MEM-001, CON-APB3-001, CON-FLT-RST-001, CON-TOP-001.

module tb_core_bus #(
  parameter string INIT_FILE = ""
);
  import tb_pkg::*;

  // Clock & External Reset
  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  always #10 clk = ~clk; // 50 MHz (20 ns period)

  // Synchronized Reset
  logic sys_rst_n;

  // IF Port A
  logic        irom_en;
  logic [14:0] irom_addr;
  logic [31:0] irom_rdata;

  // IROM Port B (Data RO)
  logic        irom_dreq;
  logic [14:0] irom_daddr;
  logic [31:0] irom_drdata;

  // CPU <-> data_bus_decode
  logic        dmem_req;
  logic        dmem_we;
  logic [1:0]  dmem_size;
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [31:0] dmem_rdata;
  logic        dmem_stall;
  logic        dmem_fault_valid;
  logic [3:0]  dmem_fault_code;

  // DRAM Local
  logic        dram_req;
  logic        dram_we;
  logic [3:0]  dram_be;
  logic [14:0] dram_addr;
  logic [31:0] dram_wdata;
  logic [31:0] dram_rdata;

  // APB3 Bridge Internal Handshake
  logic        apb_req_valid;
  logic        apb_req_write;
  logic [31:0] apb_req_addr;
  logic [31:0] apb_req_wdata;
  logic        apb_rsp_ready;
  logic [31:0] apb_rsp_rdata;
  logic        apb_rsp_err;

  // APB3 Bus Signals (Strict APB3 / IHI 0024E Issue B subset)
  logic [31:0] PADDR;
  logic        PSEL_UART, PSEL_GPIO, PSEL_TIMER;
  logic        PENABLE;
  logic        PWRITE;
  logic [31:0] PWDATA;
  logic        PREADY_UART, PREADY_GPIO, PREADY_TIMER;
  logic [31:0] PRDATA_UART, PRDATA_GPIO, PRDATA_TIMER;
  logic        PSLVERR_UART, PSLVERR_GPIO, PSLVERR_TIMER;
  logic        PREADY_mux;
  logic [31:0] PRDATA_mux;
  logic        PSLVERR_mux;

  // CPU Fault Outputs
  logic        fault_valid;
  logic [3:0]  fault_code;
  logic [31:0] fault_pc;
  logic [31:0] fault_insn;
  logic [31:0] fault_addr;

  // APB3 Completer Mux (for Golden ISS & Coverage Collector)
  always_comb begin
    PREADY_mux  = 1'b1;
    PRDATA_mux  = 32'h0;
    PSLVERR_mux = 1'b0;
    if (PSEL_UART) begin
      PREADY_mux  = PREADY_UART;
      PRDATA_mux  = PRDATA_UART;
      PSLVERR_mux = PSLVERR_UART;
    end else if (PSEL_GPIO) begin
      PREADY_mux  = PREADY_GPIO;
      PRDATA_mux  = PRDATA_GPIO;
      PSLVERR_mux = PSLVERR_GPIO;
    end else if (PSEL_TIMER) begin
      PREADY_mux  = PREADY_TIMER;
      PRDATA_mux  = PRDATA_TIMER;
      PSLVERR_mux = PSLVERR_TIMER;
    end
  end

  // DUT Subsystems (Frozen Contract Module Names & Ports)
  rst_sync u_rst_sync (
    .clk       (clk),
    .rst_n     (rst_n),
    .sys_rst_n (sys_rst_n)
  );

  rv32i_cpu u_cpu (
    .clk              (clk),
    .sys_rst_n        (sys_rst_n),
    .irom_en          (irom_en),
    .irom_addr        (irom_addr),
    .irom_rdata       (irom_rdata),
    .dmem_req         (dmem_req),
    .dmem_we          (dmem_we),
    .dmem_size        (dmem_size),
    .dmem_addr        (dmem_addr),
    .dmem_wdata       (dmem_wdata),
    .dmem_rdata       (dmem_rdata),
    .dmem_stall       (dmem_stall),
    .dmem_fault_valid (dmem_fault_valid),
    .dmem_fault_code  (dmem_fault_code),
    .fault_valid      (fault_valid),
    .fault_code       (fault_code),
    .fault_pc         (fault_pc),
    .fault_insn       (fault_insn),
    .fault_addr       (fault_addr)
  );

  irom_local #(.INIT_FILE(INIT_FILE)) u_irom (
    .clk         (clk),
    .sys_rst_n   (sys_rst_n),
    .irom_en     (irom_en),
    .irom_addr   (irom_addr),
    .irom_rdata  (irom_rdata),
    .irom_dreq   (irom_dreq),
    .irom_daddr  (irom_daddr),
    .irom_drdata (irom_drdata)
  );

  data_bus_decode u_decode (
    .clk              (clk),
    .sys_rst_n        (sys_rst_n),
    .cpu_fault_valid  (fault_valid),
    .dmem_req         (dmem_req),
    .dmem_we          (dmem_we),
    .dmem_size        (dmem_size),
    .dmem_addr        (dmem_addr),
    .dmem_wdata       (dmem_wdata),
    .dmem_rdata       (dmem_rdata),
    .dmem_stall       (dmem_stall),
    .dmem_fault_valid (dmem_fault_valid),
    .dmem_fault_code  (dmem_fault_code),
    .irom_dreq        (irom_dreq),
    .irom_daddr       (irom_daddr),
    .irom_drdata      (irom_drdata),
    .dram_req         (dram_req),
    .dram_we          (dram_we),
    .dram_be          (dram_be),
    .dram_addr        (dram_addr),
    .dram_wdata       (dram_wdata),
    .dram_rdata       (dram_rdata),
    .apb_req_valid    (apb_req_valid),
    .apb_req_write    (apb_req_write),
    .apb_req_addr     (apb_req_addr),
    .apb_req_wdata    (apb_req_wdata),
    .apb_rsp_ready    (apb_rsp_ready),
    .apb_rsp_rdata    (apb_rsp_rdata),
    .apb_rsp_err      (apb_rsp_err)
  );

  dram_local u_dram (
    .clk        (clk),
    .sys_rst_n  (sys_rst_n),
    .dram_req   (dram_req),
    .dram_we    (dram_we),
    .dram_be    (dram_be),
    .dram_addr  (dram_addr),
    .dram_wdata (dram_wdata),
    .dram_rdata (dram_rdata)
  );

  apb3_bridge u_apb_bridge (
    .clk           (clk),
    .sys_rst_n     (sys_rst_n),
    .apb_req_valid (apb_req_valid),
    .apb_req_write (apb_req_write),
    .apb_req_addr  (apb_req_addr),
    .apb_req_wdata (apb_req_wdata),
    .apb_rsp_ready (apb_rsp_ready),
    .apb_rsp_rdata (apb_rsp_rdata),
    .apb_rsp_err   (apb_rsp_err),
    .PADDR         (PADDR),
    .PSEL_UART     (PSEL_UART),
    .PSEL_GPIO     (PSEL_GPIO),
    .PSEL_TIMER    (PSEL_TIMER),
    .PENABLE       (PENABLE),
    .PWRITE        (PWRITE),
    .PWDATA        (PWDATA),
    .PREADY_UART   (PREADY_UART),
    .PRDATA_UART   (PRDATA_UART),
    .PSLVERR_UART  (PSLVERR_UART),
    .PREADY_GPIO   (PREADY_GPIO),
    .PRDATA_GPIO   (PRDATA_GPIO),
    .PSLVERR_GPIO  (PSLVERR_GPIO),
    .PREADY_TIMER  (PREADY_TIMER),
    .PRDATA_TIMER  (PRDATA_TIMER),
    .PSLVERR_TIMER (PSLVERR_TIMER)
  );

  // Mock APB3 Completer Configurations
  int unsigned cfg_wait_uart, cfg_wait_gpio, cfg_wait_timer;
  logic        cfg_slverr_uart, cfg_slverr_gpio, cfg_slverr_timer;
  logic [11:0] cfg_slverr_off;
  logic        cfg_glitch_slverr;
  int unsigned xfer_cnt_uart, xfer_cnt_gpio, xfer_cnt_timer;
  logic [31:0] last_addr_uart, last_addr_gpio, last_addr_timer;
  logic [31:0] last_wdata_uart, last_wdata_gpio, last_wdata_timer;
  logic        last_wr_uart, last_wr_gpio, last_wr_timer;
  logic        proto_err_uart, proto_err_gpio, proto_err_timer;

  mock_apb_completer #(.SLOT_PREFIX(20'h4000_0)) u_mock_uart (
    .PCLK(clk), .PRESETn(sys_rst_n), .PSEL(PSEL_UART), .PENABLE(PENABLE),
    .PWRITE(PWRITE), .PADDR(PADDR), .PWDATA(PWDATA),
    .PREADY(PREADY_UART), .PRDATA(PRDATA_UART), .PSLVERR(PSLVERR_UART),
    .cfg_wait_cycles(cfg_wait_uart), .cfg_slverr_en(cfg_slverr_uart),
    .cfg_slverr_off(cfg_slverr_off), .cfg_glitch_slverr_on_wait(cfg_glitch_slverr),
    .mon_xfer_count(xfer_cnt_uart), .mon_last_addr(last_addr_uart),
    .mon_last_wdata(last_wdata_uart), .mon_last_write(last_wr_uart),
    .mon_proto_err(proto_err_uart)
  );

  mock_apb_completer #(.SLOT_PREFIX(20'h4000_1)) u_mock_gpio (
    .PCLK(clk), .PRESETn(sys_rst_n), .PSEL(PSEL_GPIO), .PENABLE(PENABLE),
    .PWRITE(PWRITE), .PADDR(PADDR), .PWDATA(PWDATA),
    .PREADY(PREADY_GPIO), .PRDATA(PRDATA_GPIO), .PSLVERR(PSLVERR_GPIO),
    .cfg_wait_cycles(cfg_wait_gpio), .cfg_slverr_en(cfg_slverr_gpio),
    .cfg_slverr_off(cfg_slverr_off), .cfg_glitch_slverr_on_wait(cfg_glitch_slverr),
    .mon_xfer_count(xfer_cnt_gpio), .mon_last_addr(last_addr_gpio),
    .mon_last_wdata(last_wdata_gpio), .mon_last_write(last_wr_gpio),
    .mon_proto_err(proto_err_gpio)
  );

  mock_apb_completer #(.SLOT_PREFIX(20'h4000_2)) u_mock_timer (
    .PCLK(clk), .PRESETn(sys_rst_n), .PSEL(PSEL_TIMER), .PENABLE(PENABLE),
    .PWRITE(PWRITE), .PADDR(PADDR), .PWDATA(PWDATA),
    .PREADY(PREADY_TIMER), .PRDATA(PRDATA_TIMER), .PSLVERR(PSLVERR_TIMER),
    .cfg_wait_cycles(cfg_wait_timer), .cfg_slverr_en(cfg_slverr_timer),
    .cfg_slverr_off(cfg_slverr_off), .cfg_glitch_slverr_on_wait(cfg_glitch_slverr),
    .mon_xfer_count(xfer_cnt_timer), .mon_last_addr(last_addr_timer),
    .mon_last_wdata(last_wdata_timer), .mon_last_write(last_wr_timer),
    .mon_proto_err(proto_err_timer)
  );

  // Mailbox write snoop (captures DRAM writes to 0x2000_7F00..0x2000_7F0F)
  logic [31:0] mbox_status, mbox_testid, mbox_detail, mbox_sentinel;
  always_ff @(posedge clk) begin
    if (sys_rst_n && dram_req && dram_we && dram_be == 4'b1111) begin
      case ({17'b0010_0000_0000_0000_0, dram_addr})
        MBOX_STATUS_ADDR:   mbox_status   <= dram_wdata;
        MBOX_TESTID_ADDR:   mbox_testid   <= dram_wdata;
        MBOX_DETAIL_ADDR:   mbox_detail   <= dram_wdata;
        MBOX_SENTINEL_ADDR: mbox_sentinel <= dram_wdata;
        default: ;
      endcase
    end
  end

  // Golden ISS & Coverage Collector
  int unsigned sb_retires, sb_errors;
  logic apb_xfer_done_sig;
  assign apb_xfer_done_sig = (PSEL_UART || PSEL_GPIO || PSEL_TIMER) && PENABLE && PREADY_mux;

  rv32i_golden_iss #(.INIT_FILE(INIT_FILE)) u_iss (
    .clk              (clk),
    .sys_rst_n        (sys_rst_n),
    .dut_pc           ({17'h0, irom_addr}),
    .dut_dmem_stall   (dmem_stall),
    .dut_fault_valid  (fault_valid),
    .dut_fault_code   (fault_code),
    .dut_fault_pc     (fault_pc),
    .dut_fault_addr   (fault_addr),
    .dut_fault_insn   (fault_insn),
    .apb_xfer_done    (apb_xfer_done_sig),
    .apb_xfer_write   (PWRITE),
    .apb_xfer_addr    (PADDR),
    .apb_xfer_wdata   (PWDATA),
    .apb_xfer_rdata   (PRDATA_mux),
    .apb_xfer_slverr  (PSLVERR_mux),
    .dut_rf_we        (1'b0),
    .dut_rf_waddr     (5'd0),
    .dut_rf_wdata     (32'h0),
    .sb_retire_count  (sb_retires),
    .sb_error_count   (sb_errors)
  );

  tb_cov_collector u_cov (
    .clk          (clk),
    .sys_rst_n    (sys_rst_n),
    .retire_valid (!dmem_stall && !fault_valid),
    .retire_pc    ({17'h0, irom_addr}),
    .retire_insn  (irom_rdata),
    .dmem_stall   (dmem_stall),
    .dmem_req     (dmem_req),
    .dmem_we      (dmem_we),
    .dmem_size    (dmem_size),
    .dmem_addr    (dmem_addr),
    .dram_be      (dram_be),
    .psel_uart    (PSEL_UART),
    .psel_gpio    (PSEL_GPIO),
    .psel_timer   (PSEL_TIMER),
    .penable      (PENABLE),
    .pwrite       (PWRITE),
    .paddr        (PADDR),
    .pready       (PREADY_mux),
    .pslverr      (PSLVERR_mux),
    .fault_o      (fault_valid),
    .fault_code_o (fault_code)
  );

  // Test Runner
  int unsigned cfg_waits      = 0;
  int unsigned exp_fault_code = 5; // Default FAULT_EBREAK for pass
  int unsigned inject_slverr  = 0;
  int unsigned rst_during_apb = 0;
  int unsigned max_cycles     = 50000;
  logic [31:0] exp_pc_hex     = 32'h0;
  logic        check_exp_pc   = 1'b0;
  logic [31:0] exp_addr_hex   = 32'h0;
  logic        check_exp_addr = 1'b0;
  logic [31:0] exp_status_hex = STATUS_PASS;
  string       mem_file       = "";

  initial begin
    mbox_status       = 32'h0;
    mbox_testid       = 32'h0;
    mbox_detail       = 32'h0;
    mbox_sentinel     = 32'h0;
    cfg_glitch_slverr = 1'b0;

    void'($value$plusargs("APB_WAITS=%d", cfg_waits));
    void'($value$plusargs("EXP_FAULT=%d", exp_fault_code));
    void'($value$plusargs("INJECT_SLVERR=%d", inject_slverr));
    void'($value$plusargs("GLITCH_SLVERR=%d", cfg_glitch_slverr));
    void'($value$plusargs("RST_DURING_APB=%d", rst_during_apb));
    void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
    if ($value$plusargs("EXP_PC_HEX=%h", exp_pc_hex))     check_exp_pc   = 1'b1;
    if ($value$plusargs("EXP_ADDR_HEX=%h", exp_addr_hex)) check_exp_addr = 1'b1;
    void'($value$plusargs("EXP_STATUS_HEX=%h", exp_status_hex));

    cfg_wait_uart    = cfg_waits;
    cfg_wait_gpio    = (cfg_waits > 0) ? (cfg_waits + 1) : 0;
    cfg_wait_timer   = (cfg_waits > 0) ? (cfg_waits + 2) : 0;
    cfg_slverr_uart  = (inject_slverr != 0);
    cfg_slverr_gpio  = (inject_slverr != 0);
    cfg_slverr_timer = 1'b0;
    cfg_slverr_off   = 12'h000;

    // Async reset held while optionally loading +MEM_FILE= past time-0 initial blocks
    rst_n = 1'b0;
    #1;
    if ($value$plusargs("MEM_FILE=%s", mem_file)) begin
      for (int i = 0; i < IROM_WORDS; i++) u_irom.mem[i] = 32'h0;
      $readmemh(mem_file, u_irom.mem);
      u_iss.load_irom(mem_file);
    end
    #34;
    rst_n = 1'b1;

    if (rst_during_apb != 0) begin
      wait (PENABLE && !PREADY_mux);
      #5;
      rst_n = 1'b0; // Async reset while stalled in APB ACCESS
      #40;
      rst_n = 1'b1;
    end

    // Wait for halt (fault_valid) or timeout
    for (int unsigned c = 0; c < max_cycles; c++) begin
      @(posedge clk);
      if (fault_valid) break;
    end

    if (!fault_valid) begin
      $fatal(1, "[TB_CORE_BUS] FAIL: Timeout waiting for fault_valid/halt after %0d cycles", max_cycles);
    end

    if (fault_code !== exp_fault_code[3:0]) begin
      $fatal(1, "[TB_CORE_BUS] FAIL: Expected fault_code=%0h got=%0h (pc=%h addr=%h insn=%h)",
             exp_fault_code[3:0], fault_code, fault_pc, fault_addr, fault_insn);
    end

    if (check_exp_pc && (fault_pc !== exp_pc_hex)) begin
      $fatal(1, "[TB_CORE_BUS] FAIL: Expected fault_pc=%h got=%h", exp_pc_hex, fault_pc);
    end

    if (check_exp_addr && (fault_addr !== exp_addr_hex)) begin
      $fatal(1, "[TB_CORE_BUS] FAIL: Expected fault_addr=%h got=%h", exp_addr_hex, fault_addr);
    end

    if (mbox_status !== exp_status_hex) begin
      $fatal(1, "[TB_CORE_BUS] FAIL: MBOX_STATUS=%h (expected=%h), detail=%h",
             mbox_status, exp_status_hex, mbox_detail);
    end

    if (mbox_sentinel !== 32'h0) begin
      $fatal(1, "[TB_CORE_BUS] FAIL: Sentinel mutated (%h) after fault!", mbox_sentinel);
    end

    if (proto_err_uart || proto_err_gpio || proto_err_timer || sb_errors != 0) begin
      $fatal(1, "[TB_CORE_BUS] FAIL: proto_err={%b,%b,%b} sb_errors=%0d",
             proto_err_uart, proto_err_gpio, proto_err_timer, sb_errors);
    end

    u_cov.print_summary();
    $display("[TB_CORE_BUS] PASS: testid=%h fault=%s retires=%0d",
             mbox_testid, fault_name(fault_code), sb_retires);
    $finish;
  end

endmodule
