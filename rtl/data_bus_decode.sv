// Modified Harvard Data Path Decoder, Fault Checker & Local Read Handshake
// Contracts: CON-ADDR-001 v1.1, CON-MEM-001 v1.1, CON-APB3-001 v1.1,
//            CON-FLT-RST-001 v1.1, CON-TOP-001 v1.1

module data_bus_decode (
    input  logic        clk,
    input  logic        sys_rst_n,
    input  logic        cpu_fault_valid,

    // CPU data interface
    input  logic        dmem_req,
    input  logic        dmem_we,
    input  logic [1:0]  dmem_size,
    input  logic [31:0] dmem_addr,
    input  logic [31:0] dmem_wdata,
    output logic [31:0] dmem_rdata,
    output logic        dmem_stall,
    output logic        dmem_fault_valid,
    output logic [3:0]  dmem_fault_code,

    // IROM Port B (read-only data)
    output logic        irom_dreq,
    output logic [14:0] irom_daddr,
    input  logic [31:0] irom_drdata,

    // DRAM interface
    output logic        dram_req,
    output logic        dram_we,
    output logic [3:0]  dram_be,
    output logic [14:0] dram_addr,
    output logic [31:0] dram_wdata,
    input  logic [31:0] dram_rdata,

    // APB3 bridge interface
    output logic        apb_req_valid,
    output logic        apb_req_write,
    output logic [31:0] apb_req_addr,
    output logic [31:0] apb_req_wdata,
    input  logic        apb_rsp_ready,
    input  logic [31:0] apb_rsp_rdata,
    input  logic        apb_rsp_err
);

    logic data_in_irom;
    logic data_in_dram;
    logic data_in_uart;
    logic data_in_gpio;
    logic data_in_timer;
    logic data_in_apb;

    logic pre_fault_valid;
    logic [3:0] pre_fault_code;
    logic misaligned_access;

    logic local_rd_valid;
    logic local_rd_issue;
    logic local_read_stall;
    logic apb_stall;
    logic apb_bus_err;
    logic active_req;

    // Region decode (CON-ADDR-001 Section 4.2)
    assign data_in_irom  = (dmem_addr[31:15] == soc_pkg::IROM_BASE_PREFIX);
    assign data_in_dram  = (dmem_addr[31:15] == soc_pkg::DRAM_BASE_PREFIX);
    assign data_in_uart  = (dmem_addr[31:12] == soc_pkg::APB_UART_PREFIX);
    assign data_in_gpio  = (dmem_addr[31:12] == soc_pkg::APB_GPIO_PREFIX);
    assign data_in_timer = (dmem_addr[31:12] == soc_pkg::APB_TIMER_PREFIX);
    assign data_in_apb   = data_in_uart || data_in_gpio || data_in_timer;

    assign active_req = sys_rst_n && !cpu_fault_valid && dmem_req;

    // Alignment check (CON-MEM-001 Section 2.5)
    always_comb begin
        case (dmem_size)
            soc_pkg::DMEM_SIZE_HALF: misaligned_access = dmem_addr[0];
            soc_pkg::DMEM_SIZE_WORD: misaligned_access = (dmem_addr[1:0] != 2'b00);
            default:                 misaligned_access = 1'b0;
        endcase
    end

    // Pre-check data fault evaluation in strict priority order (CON-FLT-RST-001 Section 1.2)
    always_comb begin
        pre_fault_valid = 1'b0;
        pre_fault_code  = soc_pkg::FAULT_NONE;

        if (active_req) begin
            if (!(data_in_irom || data_in_dram || data_in_apb)) begin
                pre_fault_valid = 1'b1;
                pre_fault_code  = soc_pkg::FAULT_DATA_UNMAPPED;
            end else if (data_in_irom && dmem_we) begin
                pre_fault_valid = 1'b1;
                pre_fault_code  = soc_pkg::FAULT_DATA_RO_WRITE;
            end else if (data_in_apb && (dmem_size != soc_pkg::DMEM_SIZE_WORD)) begin
                pre_fault_valid = 1'b1;
                pre_fault_code  = soc_pkg::FAULT_DATA_SIZE_UNSUP;
            end else if (misaligned_access) begin
                pre_fault_valid = 1'b1;
                pre_fault_code  = soc_pkg::FAULT_DATA_MISALIGNED;
            end
        end
    end

    // 2-cycle local synchronous read handshake (IROM Port B & DRAM)
    assign local_rd_issue = active_req && !dmem_we && (data_in_dram || data_in_irom)
                          && !pre_fault_valid && !local_rd_valid;
    assign local_read_stall = local_rd_issue;

    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            local_rd_valid <= 1'b0;
        end else begin
            local_rd_valid <= local_rd_issue;
        end
    end

    // IROM Port B (RO data)
    assign irom_dreq  = local_rd_issue && data_in_irom;
    assign irom_daddr = dmem_addr[14:0];

    // DRAM request & little-endian byte-enable / lane placement
    assign dram_req  = active_req && !pre_fault_valid && data_in_dram
                     && (dmem_we || !local_rd_valid);
    assign dram_we   = dmem_we;
    assign dram_addr = dmem_addr[14:0];

    always_comb begin
        dram_be    = 4'b0000;
        dram_wdata = 32'h0000_0000;
        if (dram_req && dram_we) begin
            case (dmem_size)
                soc_pkg::DMEM_SIZE_BYTE: begin
                    case (dmem_addr[1:0])
                        2'b00: begin
                            dram_be    = 4'b0001;
                            dram_wdata = {24'h0, dmem_wdata[7:0]};
                        end
                        2'b01: begin
                            dram_be    = 4'b0010;
                            dram_wdata = {16'h0, dmem_wdata[7:0], 8'h0};
                        end
                        2'b10: begin
                            dram_be    = 4'b0100;
                            dram_wdata = {8'h0, dmem_wdata[7:0], 16'h0};
                        end
                        2'b11: begin
                            dram_be    = 4'b1000;
                            dram_wdata = {dmem_wdata[7:0], 24'h0};
                        end
                    endcase
                end
                soc_pkg::DMEM_SIZE_HALF: begin
                    if (dmem_addr[1] == 1'b0) begin
                        dram_be    = 4'b0011;
                        dram_wdata = {16'h0, dmem_wdata[15:0]};
                    end else begin
                        dram_be    = 4'b1100;
                        dram_wdata = {dmem_wdata[15:0], 16'h0};
                    end
                end
                soc_pkg::DMEM_SIZE_WORD: begin
                    dram_be    = 4'b1111;
                    dram_wdata = dmem_wdata;
                end
                default: begin
                    dram_be    = 4'b0000;
                    dram_wdata = 32'h0000_0000;
                end
            endcase
        end
    end

    // APB3 bridge request
    assign apb_req_valid = active_req && !pre_fault_valid && data_in_apb;
    assign apb_req_write = dmem_we;
    assign apb_req_addr  = dmem_addr;
    assign apb_req_wdata = dmem_wdata;

    assign apb_stall   = apb_req_valid && !apb_rsp_ready;
    assign apb_bus_err = apb_req_valid && apb_rsp_ready && apb_rsp_err;

    // Unified CPU stall & fault return
    assign dmem_stall       = (local_read_stall || apb_stall) && !cpu_fault_valid;
    assign dmem_fault_valid = pre_fault_valid || apb_bus_err;
    assign dmem_fault_code  = pre_fault_valid ? pre_fault_code :
                              (apb_bus_err    ? soc_pkg::FAULT_APB_SLVERR : soc_pkg::FAULT_NONE);

    // Read data mux
    always_comb begin
        if (data_in_irom) begin
            dmem_rdata = irom_drdata;
        end else if (data_in_dram) begin
            dmem_rdata = dram_rdata;
        end else if (data_in_apb) begin
            dmem_rdata = apb_rsp_rdata;
        end else begin
            dmem_rdata = 32'h0000_0000;
        end
    end

endmodule
