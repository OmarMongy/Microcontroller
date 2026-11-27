// SVA Bind Directives (SOC_VB_002)
// Separates Part A (frozen contract port binds) from Part B (internal binds,
// guarded by `ifdef SVA_ENABLE_INTERNAL_BINDS for Gate 5 hierarchical alignment).

// Part A: Top-level soc_top boundary bind (CON-TOP-001 §3)
bind soc_top sva_soc_fault_rst_if u_sva_soc_top (
  .clk          (clk),
  .rst_n        (rst_n),
  .uart_tx_o    (uart_tx_o),
  .gpio_o       (gpio_o),
  .gpio_oe_o    (gpio_oe_o),
  .fault_o      (fault_o),
  .fault_code_o (fault_code_o),
  .fault_pc_o   (fault_pc_o),
  .fault_addr_o (fault_addr_o),
  .fault_insn_o (fault_insn_o)
);

// Part A: APB3 bridge boundary bind (CON-APB3-001 §3.1 & §3.2; rtl/apb3_bridge.sv ports)
bind apb3_bridge sva_apb3_if u_sva_apb3 (
  .PCLK             (clk),
  .PRESETn          (sys_rst_n),
  .PADDR            (PADDR),
  .PSEL_UART        (PSEL_UART),
  .PSEL_GPIO        (PSEL_GPIO),
  .PSEL_TIMER       (PSEL_TIMER),
  .PENABLE          (PENABLE),
  .PWRITE           (PWRITE),
  .PWDATA           (PWDATA),
  .PREADY_mux       (PSEL_UART ? PREADY_UART : (PSEL_GPIO ? PREADY_GPIO : (PSEL_TIMER ? PREADY_TIMER : 1'b1))),
  .PRDATA_mux       (PSEL_UART ? PRDATA_UART : (PSEL_GPIO ? PRDATA_GPIO : (PSEL_TIMER ? PRDATA_TIMER : 32'h0))),
  .PSLVERR_mux      (PSEL_UART ? PSLVERR_UART : (PSEL_GPIO ? PSLVERR_GPIO : (PSEL_TIMER ? PSLVERR_TIMER : 1'b0))),
  .apb_req_valid    (apb_req_valid),
  .apb_req_write    (apb_req_write),
  .apb_req_addr     (apb_req_addr),
  .apb_req_wdata    (apb_req_wdata),
  .apb_rsp_ready    (apb_rsp_ready),
  .dmem_fault_valid (1'b0),
  .dmem_fault_code  (4'h0)
);

// Part A: Peripheral Completer boundary binds (CON-PERIPH-001)
bind uart_apb sva_uart_apb_if u_sva_uart (
  .PCLK      (PCLK),
  .PRESETn   (PRESETn),
  .PSEL      (PSEL),
  .PENABLE   (PENABLE),
  .PWRITE    (PWRITE),
  .PADDR     (PADDR),
  .PWDATA    (PWDATA),
  .PREADY    (PREADY),
  .PRDATA    (PRDATA),
  .PSLVERR   (PSLVERR),
  .uart_tx_o (uart_tx_o)
);

bind gpio_apb sva_gpio_apb_if u_sva_gpio (
  .PCLK      (PCLK),
  .PRESETn   (PRESETn),
  .PSEL      (PSEL),
  .PENABLE   (PENABLE),
  .PWRITE    (PWRITE),
  .PADDR     (PADDR),
  .PWDATA    (PWDATA),
  .PREADY    (PREADY),
  .PRDATA    (PRDATA),
  .PSLVERR   (PSLVERR),
  .gpio_o    (gpio_o),
  .gpio_oe_o (gpio_oe_o)
);

bind timer_apb sva_timer_apb_if u_sva_timer (
  .PCLK    (PCLK),
  .PRESETn (PRESETn),
  .PSEL    (PSEL),
  .PENABLE (PENABLE),
  .PWRITE  (PWRITE),
  .PADDR   (PADDR),
  .PWDATA  (PWDATA),
  .PREADY  (PREADY),
  .PRDATA  (PRDATA),
  .PSLVERR (PSLVERR)
);

`ifdef SVA_ENABLE_INTERNAL_BINDS
// Gate 5 hierarchical bind for Part A/B memory & CPU internal checks
// (aligned to soc_top instance names at Gate 5 without changing property semantics)
bind soc_top sva_mem_if u_sva_mem (
  .clk              (clk),
  .sys_rst_n        (sys_rst_n),
  .fault_valid      (fault_o),
  .irom_en          (irom_en),
  .irom_addr        (irom_addr),
  .irom_rdata       (irom_rdata),
  .irom_dreq        (irom_dreq),
  .irom_daddr       (irom_daddr),
  .irom_drdata      (irom_drdata),
  .dram_req         (dram_req),
  .dram_we          (dram_we),
  .dram_be          (dram_be),
  .dram_addr        (dram_addr),
  .dram_rdata       (dram_rdata),
  .dmem_req         (dmem_req),
  .dmem_we          (dmem_we),
  .dmem_size        (dmem_size),
  .dmem_addr        (dmem_addr),
  .dmem_wdata       (dmem_wdata),
  .dmem_stall       (dmem_stall),
  .dmem_fault_valid (dmem_fault_valid),
  .dmem_fault_code  (dmem_fault_code),
  .apb_req_valid    (apb_req_valid)
);
`endif
