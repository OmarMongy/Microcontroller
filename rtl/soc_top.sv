// SoC Top-Level Integration Wrapper
// Contracts: CON-TOP-001 v1.1, CON-ADDR-001 v1.1, CON-MEM-001 v1.1,
//            CON-APB3-001 v1.1, CON-FLT-RST-001 v1.1, CON-PERIPH-001 v1.0

module soc_top #(
    parameter IROM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        uart_rx_i,
    output logic        uart_tx_o,
    input  logic [7:0]  gpio_i,
    output logic [7:0]  gpio_o,
    output logic [7:0]  gpio_oe_o,
    output logic        fault_o,
    output logic [3:0]  fault_code_o,
    output logic [31:0] fault_pc_o,
    output logic [31:0] fault_addr_o,
    output logic [31:0] fault_insn_o
);

    // Synchronized active-low reset (PRESETn)
    logic sys_rst_n;

    // CPU <-> IROM Port A
    logic        irom_en;
    logic [14:0] irom_addr;
    logic [31:0] irom_rdata;

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

    // data_bus_decode <-> IROM Port B
    logic        irom_dreq;
    logic [14:0] irom_daddr;
    logic [31:0] irom_drdata;

    // data_bus_decode <-> DRAM
    logic        dram_req;
    logic        dram_we;
    logic [3:0]  dram_be;
    logic [14:0] dram_addr;
    logic [31:0] dram_wdata;
    logic [31:0] dram_rdata;

    // data_bus_decode <-> APB3 Bridge
    logic        apb_req_valid;
    logic        apb_req_write;
    logic [31:0] apb_req_addr;
    logic [31:0] apb_req_wdata;
    logic        apb_rsp_ready;
    logic [31:0] apb_rsp_rdata;
    logic        apb_rsp_err;

    // APB3 Bus
    logic [31:0] paddr;
    logic        psel_uart;
    logic        psel_gpio;
    logic        psel_timer;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;

    logic        pready_uart;
    logic [31:0] prdata_uart;
    logic        pslverr_uart;

    logic        pready_gpio;
    logic [31:0] prdata_gpio;
    logic        pslverr_gpio;

    logic        pready_timer;
    logic [31:0] prdata_timer;
    logic        pslverr_timer;

    // Reset Synchronizer
    rst_sync u_rst_sync (
        .clk       (clk),
        .rst_n     (rst_n),
        .sys_rst_n (sys_rst_n)
    );

    // RV32I CPU Core
    rv32i_cpu u_rv32i_cpu (
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
        .fault_valid      (fault_o),
        .fault_code       (fault_code_o),
        .fault_pc         (fault_pc_o),
        .fault_addr       (fault_addr_o),
        .fault_insn       (fault_insn_o)
    );

    // 32 KB Modified Harvard Instruction ROM
    irom_local #(
        .INIT_FILE  (IROM_INIT_FILE),
        .DEPTH      (8192),
        .ADDR_WIDTH (15),
        .DATA_WIDTH (32)
    ) u_irom_local (
        .clk         (clk),
        .sys_rst_n   (sys_rst_n),
        .irom_en     (irom_en),
        .irom_addr   (irom_addr),
        .irom_rdata  (irom_rdata),
        .irom_dreq   (irom_dreq),
        .irom_daddr  (irom_daddr),
        .irom_drdata (irom_drdata)
    );

    // Data Path Decoder & Fault Checker
    data_bus_decode u_data_bus_decode (
        .clk              (clk),
        .sys_rst_n        (sys_rst_n),
        .cpu_fault_valid  (fault_o),
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

    // 32 KB Local Data RAM (Option RAM-B)
    dram_local #(
        .DEPTH      (8192),
        .ADDR_WIDTH (15),
        .DATA_WIDTH (32)
    ) u_dram_local (
        .clk        (clk),
        .sys_rst_n  (sys_rst_n),
        .dram_req   (dram_req),
        .dram_we    (dram_we),
        .dram_be    (dram_be),
        .dram_addr  (dram_addr),
        .dram_wdata (dram_wdata),
        .dram_rdata (dram_rdata)
    );

    // AMBA APB3 Requester Bridge
    apb3_bridge u_apb3_bridge (
        .clk           (clk),
        .sys_rst_n     (sys_rst_n),
        .apb_req_valid (apb_req_valid),
        .apb_req_write (apb_req_write),
        .apb_req_addr  (apb_req_addr),
        .apb_req_wdata (apb_req_wdata),
        .apb_rsp_ready (apb_rsp_ready),
        .apb_rsp_rdata (apb_rsp_rdata),
        .apb_rsp_err   (apb_rsp_err),
        .PADDR         (paddr),
        .PSEL_UART     (psel_uart),
        .PSEL_GPIO     (psel_gpio),
        .PSEL_TIMER    (psel_timer),
        .PENABLE       (penable),
        .PWRITE        (pwrite),
        .PWDATA        (pwdata),
        .PREADY_UART   (pready_uart),
        .PRDATA_UART   (prdata_uart),
        .PSLVERR_UART  (pslverr_uart),
        .PREADY_GPIO   (pready_gpio),
        .PRDATA_GPIO   (prdata_gpio),
        .PSLVERR_GPIO  (pslverr_gpio),
        .PREADY_TIMER  (pready_timer),
        .PRDATA_TIMER  (prdata_timer),
        .PSLVERR_TIMER (pslverr_timer)
    );

    // APB3 Slot 0: UART
    uart_apb u_uart_apb (
        .PCLK      (clk),
        .PRESETn   (sys_rst_n),
        .PADDR     (paddr),
        .PSEL      (psel_uart),
        .PENABLE   (penable),
        .PWRITE    (pwrite),
        .PWDATA    (pwdata),
        .PREADY    (pready_uart),
        .PRDATA    (prdata_uart),
        .PSLVERR   (pslverr_uart),
        .uart_rx_i (uart_rx_i),
        .uart_tx_o (uart_tx_o)
    );

    // APB3 Slot 1: 8-bit GPIO
    gpio_apb u_gpio_apb (
        .PCLK      (clk),
        .PRESETn   (sys_rst_n),
        .PADDR     (paddr),
        .PSEL      (psel_gpio),
        .PENABLE   (penable),
        .PWRITE    (pwrite),
        .PWDATA    (pwdata),
        .PREADY    (pready_gpio),
        .PRDATA    (prdata_gpio),
        .PSLVERR   (pslverr_gpio),
        .gpio_i    (gpio_i),
        .gpio_o    (gpio_o),
        .gpio_oe_o (gpio_oe_o)
    );

    // APB3 Slot 2: 32-bit Timer
    timer_apb u_timer_apb (
        .PCLK    (clk),
        .PRESETn (sys_rst_n),
        .PADDR   (paddr),
        .PSEL    (psel_timer),
        .PENABLE (penable),
        .PWRITE  (pwrite),
        .PWDATA  (pwdata),
        .PREADY  (pready_timer),
        .PRDATA  (prdata_timer),
        .PSLVERR (pslverr_timer)
    );

endmodule
