// APB3 8-bit GPIO Peripheral (with 2-FF input synchronizer)
// Base Address: 0x4000_1000 (4 KB slot)
// Contracts: CON-PERIPH-001 v1.0 Section 3, CON-APB3-001 v1.1

module gpio_apb (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic [31:0] PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,
    output logic        PREADY,
    output logic [31:0] PRDATA,
    output logic        PSLVERR,

    input  logic [7:0]  gpio_i,
    output logic [7:0]  gpio_o,
    output logic [7:0]  gpio_oe_o
);

    localparam logic [11:0] ADDR_DATA_IN  = 12'h000;
    localparam logic [11:0] ADDR_DATA_OUT = 12'h004;
    localparam logic [11:0] ADDR_DIR      = 12'h008;

    /* verilator lint_off UNUSEDSIGNAL */
    logic [19:0] unused_paddr_hi;
    logic [23:0] unused_pwdata_hi;
    /* verilator lint_on UNUSEDSIGNAL */
    assign unused_paddr_hi  = PADDR[31:12];
    assign unused_pwdata_hi = PWDATA[31:8];

    logic [7:0] sync1;
    logic [7:0] sync2;
    logic [7:0] data_out;
    logic [7:0] dir;

    logic [11:0] reg_offset;
    logic        apb_access;
    logic        apb_wr;
    logic        apb_err;
    logic [31:0] rdata_mux;

    assign PREADY     = 1'b1;
    assign reg_offset = PADDR[11:0];
    assign apb_access = PSEL && PENABLE && PREADY;
    assign apb_wr     = apb_access && PWRITE;

    // 2-FF input synchronizer
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            sync1 <= 8'h00;
            sync2 <= 8'h00;
        end else begin
            sync1 <= gpio_i;
            sync2 <= sync1;
        end
    end

    // APB read data & strict PSLVERR decode
    always_comb begin
        apb_err   = 1'b0;
        rdata_mux = 32'h0000_0000;

        case (reg_offset)
            ADDR_DATA_IN: begin
                if (PWRITE) begin
                    apb_err = 1'b1; // RO register write -> PSLVERR
                end else begin
                    rdata_mux = {24'h0, sync2};
                end
            end
            ADDR_DATA_OUT: begin
                rdata_mux = {24'h0, data_out};
            end
            ADDR_DIR: begin
                rdata_mux = {24'h0, dir};
            end
            default: begin
                apb_err = 1'b1; // Unimplemented offset -> PSLVERR
            end
        endcase
    end

    assign PRDATA  = (PSEL && PENABLE && !PWRITE && !apb_err) ? rdata_mux : 32'h0000_0000;
    assign PSLVERR = apb_access && apb_err;

    // Output & direction registers
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            data_out <= 8'h00;
            dir      <= 8'h00;
        end else if (apb_wr) begin
            case (reg_offset)
                ADDR_DATA_OUT: data_out <= PWDATA[7:0];
                ADDR_DIR:      dir      <= PWDATA[7:0];
                default: ;
            endcase
        end
    end

    assign gpio_o    = data_out;
    assign gpio_oe_o = dir;

endmodule
