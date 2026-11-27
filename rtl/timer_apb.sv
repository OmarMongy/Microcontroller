// APB3 32-bit Timer Peripheral (Up-counter with Compare & Auto-Reload)
// Base Address: 0x4000_2000 (4 KB slot)
// Contracts: CON-PERIPH-001 v1.0 Section 4, CON-APB3-001 v1.1

module timer_apb (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic [31:0] PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,
    output logic        PREADY,
    output logic [31:0] PRDATA,
    output logic        PSLVERR
);

    localparam logic [11:0] ADDR_CTRL    = 12'h000;
    localparam logic [11:0] ADDR_STATUS  = 12'h004;
    localparam logic [11:0] ADDR_COUNTER = 12'h008;
    localparam logic [11:0] ADDR_COMPARE = 12'h00C;

    /* verilator lint_off UNUSEDSIGNAL */
    logic [19:0] unused_paddr_hi;
    /* verilator lint_on UNUSEDSIGNAL */
    assign unused_paddr_hi = PADDR[31:12];

    logic        en;
    logic        auto_reload;
    logic        status_match;
    logic        status_ovf;
    logic [31:0] counter;
    logic [31:0] compare;

    logic [11:0] reg_offset;
    logic        apb_access;
    logic        apb_wr;
    logic        apb_err;
    logic [31:0] rdata_mux;

    logic        wr_ctrl;
    logic        wr_status;
    logic        wr_counter;
    logic        wr_compare;
    logic        clr_cnt_pulse;
    logic        hw_match;
    logic        hw_ovf;

    assign PREADY     = 1'b1;
    assign reg_offset = PADDR[11:0];
    assign apb_access = PSEL && PENABLE && PREADY;
    assign apb_wr     = apb_access && PWRITE;

    assign wr_ctrl       = apb_wr && (reg_offset == ADDR_CTRL);
    assign wr_status     = apb_wr && (reg_offset == ADDR_STATUS);
    assign wr_counter    = apb_wr && (reg_offset == ADDR_COUNTER);
    assign wr_compare    = apb_wr && (reg_offset == ADDR_COMPARE);
    assign clr_cnt_pulse = wr_ctrl && PWDATA[2];

    // APB read data & strict PSLVERR decode
    always_comb begin
        apb_err   = 1'b0;
        rdata_mux = 32'h0000_0000;

        case (reg_offset)
            ADDR_CTRL: begin
                rdata_mux = {29'h0, 1'b0, auto_reload, en}; // CLR_CNT always reads 0
            end
            ADDR_STATUS: begin
                rdata_mux = {30'h0, status_ovf, status_match};
            end
            ADDR_COUNTER: begin
                rdata_mux = counter;
            end
            ADDR_COMPARE: begin
                rdata_mux = compare;
            end
            default: begin
                apb_err = 1'b1; // Unimplemented offset -> PSLVERR
            end
        endcase
    end

    assign PRDATA  = (PSEL && PENABLE && !PWRITE && !apb_err) ? rdata_mux : 32'h0000_0000;
    assign PSLVERR = apb_access && apb_err;

    // Hardware match & overflow event detection (CON-PERIPH-001 Section 4.3)
    always_comb begin
        hw_match = 1'b0;
        hw_ovf   = 1'b0;

        if (!wr_counter && !clr_cnt_pulse && en) begin
            if (auto_reload && (counter == compare)) begin
                hw_match = 1'b1;
            end else begin
                if (counter == compare) begin
                    hw_match = 1'b1;
                end
                if (counter == 32'hFFFF_FFFF) begin
                    hw_ovf = 1'b1;
                end
            end
        end
    end

    // Sequential state update with strict precedence
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            en           <= 1'b0;
            auto_reload  <= 1'b0;
            status_match <= 1'b0;
            status_ovf   <= 1'b0;
            counter      <= 32'h0000_0000;
            compare      <= 32'hFFFF_FFFF;
        end else begin
            if (wr_ctrl) begin
                en          <= PWDATA[0];
                auto_reload <= PWDATA[1];
            end

            if (wr_compare) begin
                compare <= PWDATA;
            end

            // Counter next-state precedence:
            // 1. APB write to TIMER_COUNTER
            // 2. APB write to TIMER_CTRL with CLR_CNT == 1
            // 3. EN && AUTO_RELOAD && COUNTER == COMPARE
            // 4. EN (increment)
            // 5. Hold
            if (wr_counter) begin
                counter <= PWDATA;
            end else if (clr_cnt_pulse) begin
                counter <= 32'h0000_0000;
            end else if (en) begin
                if (auto_reload && (counter == compare)) begin
                    counter <= 32'h0000_0000;
                end else begin
                    counter <= counter + 32'd1;
                end
            end

            // Status flags: hardware event takes precedence over W1C on same edge
            if (hw_match) begin
                status_match <= 1'b1;
            end else if (wr_status && PWDATA[0]) begin
                status_match <= 1'b0;
            end

            if (hw_ovf) begin
                status_ovf <= 1'b1;
            end else if (wr_status && PWDATA[1]) begin
                status_ovf <= 1'b0;
            end
        end
    end

endmodule
