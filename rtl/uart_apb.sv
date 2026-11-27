// APB3 UART Peripheral (8N1, Programmable 24-bit Baud Divider)
// Base Address: 0x4000_0000 (4 KB slot)
// Contracts: CON-PERIPH-001 v1.0 Section 2, CON-APB3-001 v1.1

module uart_apb (
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

    input  logic        uart_rx_i,
    output logic        uart_tx_o
);

    localparam logic [11:0] ADDR_CTRL     = 12'h000;
    localparam logic [11:0] ADDR_STATUS   = 12'h004;
    localparam logic [11:0] ADDR_TX_DATA  = 12'h008;
    localparam logic [11:0] ADDR_RX_DATA  = 12'h00C;
    localparam logic [11:0] ADDR_BAUD_DIV = 12'h010;

    localparam logic [23:0] DEFAULT_BAUD_DIV = 24'd434;

    /* verilator lint_off UNUSEDSIGNAL */
    logic [19:0] unused_paddr_hi;
    logic [7:0]  unused_pwdata_hi;
    /* verilator lint_on UNUSEDSIGNAL */
    assign unused_paddr_hi  = PADDR[31:12];
    assign unused_pwdata_hi = PWDATA[31:24];

    // Control & status registers
    logic        tx_en;
    logic        rx_en;
    logic [23:0] baud_div;
    logic [7:0]  rx_data;
    logic        rx_valid;
    logic        rx_overrun;
    logic        rx_frame_err;

    // TX state
    logic        tx_busy;
    logic        tx_line;
    logic [8:0]  tx_shift;   // {stop(1), data[7:0]}
    logic [3:0]  tx_bit_cnt; // 0..9 (Start, D0..D7, Stop)
    logic [23:0] tx_clk_cnt;

    // RX 2-FF synchronizer & state
    typedef enum logic [1:0] {
        RX_IDLE  = 2'b00,
        RX_START = 2'b01,
        RX_DATA  = 2'b10,
        RX_STOP  = 2'b11
    } rx_state_e;

    rx_state_e   rx_state;
    logic        rx_sync1;
    logic        rx_sync2;
    logic [7:0]  rx_shift;
    logic [2:0]  rx_bit_cnt;
    logic [23:0] rx_clk_cnt;

    // APB decode signals
    logic [11:0] reg_offset;
    logic        apb_access;
    logic        apb_wr;
    logic        apb_rd;
    logic        apb_err;
    logic [31:0] rdata_mux;

    logic        wr_ctrl;
    logic        wr_status;
    logic        wr_tx_data;
    logic        rd_rx_data;
    logic        wr_baud_div;

    assign PREADY     = 1'b1;
    assign reg_offset = PADDR[11:0];
    assign apb_access = PSEL && PENABLE && PREADY;
    assign apb_wr     = apb_access && PWRITE;
    assign apb_rd     = apb_access && !PWRITE;

    assign wr_ctrl     = apb_wr && (reg_offset == ADDR_CTRL);
    assign wr_status   = apb_wr && (reg_offset == ADDR_STATUS);
    assign wr_tx_data  = apb_wr && (reg_offset == ADDR_TX_DATA);
    assign rd_rx_data  = apb_rd && (reg_offset == ADDR_RX_DATA);
    assign wr_baud_div = apb_wr && (reg_offset == ADDR_BAUD_DIV);

    // APB read data & strict PSLVERR decode (CON-PERIPH-001 Section 1 & 2)
    always_comb begin
        apb_err   = 1'b0;
        rdata_mux = 32'h0000_0000;

        case (reg_offset)
            ADDR_CTRL: begin
                rdata_mux = {30'h0, rx_en, tx_en};
            end
            ADDR_STATUS: begin
                rdata_mux = {27'h0, rx_frame_err, rx_overrun, rx_valid, ~tx_busy, tx_busy};
            end
            ADDR_TX_DATA: begin
                if (!PWRITE) begin
                    apb_err = 1'b1; // WO register read -> PSLVERR
                end
            end
            ADDR_RX_DATA: begin
                if (PWRITE) begin
                    apb_err = 1'b1; // RO register write -> PSLVERR
                end else begin
                    rdata_mux = {24'h0, rx_data};
                end
            end
            ADDR_BAUD_DIV: begin
                if (PWRITE && (PWDATA[23:0] < 24'd2)) begin
                    apb_err = 1'b1; // Invalid BAUD_DIV < 2 -> PSLVERR
                end else begin
                    rdata_mux = {8'h00, baud_div};
                end
            end
            default: begin
                apb_err = 1'b1; // Unimplemented offset -> PSLVERR
            end
        endcase
    end

    assign PRDATA  = (PSEL && PENABLE && !PWRITE && !apb_err) ? rdata_mux : 32'h0000_0000;
    assign PSLVERR = apb_access && apb_err;

    // 2-FF RX pin synchronizer (reset to idle-HIGH 1'b1)
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= uart_rx_i;
            rx_sync2 <= rx_sync1;
        end
    end

    // Configuration registers
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            tx_en    <= 1'b1;
            rx_en    <= 1'b1;
            baud_div <= DEFAULT_BAUD_DIV;
        end else begin
            if (wr_ctrl) begin
                tx_en <= PWDATA[0];
                rx_en <= PWDATA[1];
            end
            if (wr_baud_div && (PWDATA[23:0] >= 24'd2)) begin
                baud_div <= PWDATA[23:0];
            end
        end
    end

    // UART Transmitter (8N1 LSB-first)
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            tx_busy    <= 1'b0;
            tx_line    <= 1'b1;
            tx_shift   <= 9'h1FF;
            tx_bit_cnt <= 4'd0;
            tx_clk_cnt <= 24'd0;
        end else if (!tx_en) begin
            tx_busy    <= 1'b0;
            tx_line    <= 1'b1;
            tx_shift   <= 9'h1FF;
            tx_bit_cnt <= 4'd0;
            tx_clk_cnt <= 24'd0;
        end else if (!tx_busy) begin
            tx_line <= 1'b1;
            if (wr_tx_data) begin
                tx_busy    <= 1'b1;
                tx_line    <= 1'b0; // Start bit
                tx_shift   <= {1'b1, PWDATA[7:0]};
                tx_bit_cnt <= 4'd0;
                tx_clk_cnt <= 24'd0;
            end
        end else begin
            if (tx_clk_cnt >= (baud_div - 24'd1)) begin
                tx_clk_cnt <= 24'd0;
                if (tx_bit_cnt == 4'd9) begin
                    tx_busy    <= 1'b0;
                    tx_line    <= 1'b1;
                    tx_bit_cnt <= 4'd0;
                end else begin
                    tx_bit_cnt <= tx_bit_cnt + 4'd1;
                    tx_line    <= tx_shift[0];
                    tx_shift   <= {1'b1, tx_shift[8:1]};
                end
            end else begin
                tx_clk_cnt <= tx_clk_cnt + 24'd1;
            end
        end
    end

    assign uart_tx_o = tx_en ? tx_line : 1'b1;

    // UART Receiver (8N1 LSB-first, mid-bit start sampling)
    logic rx_stop_ok;
    logic rx_stop_err;
    assign rx_stop_ok  = (rx_state == RX_STOP) && rx_en && (rx_clk_cnt >= (baud_div - 24'd1)) && (rx_sync2 == 1'b1);
    assign rx_stop_err = (rx_state == RX_STOP) && rx_en && (rx_clk_cnt >= (baud_div - 24'd1)) && (rx_sync2 == 1'b0);

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            rx_state     <= RX_IDLE;
            rx_shift     <= 8'h00;
            rx_bit_cnt   <= 3'd0;
            rx_clk_cnt   <= 24'd0;
            rx_data      <= 8'h00;
            rx_valid     <= 1'b0;
            rx_overrun   <= 1'b0;
            rx_frame_err <= 1'b0;
        end else begin
            // RX_VALID read-clear & hardware capture
            if (rd_rx_data) begin
                rx_valid <= 1'b0;
            end

            // Sticky W1C flags (hardware event takes precedence over W1C on same edge)
            if (rx_stop_ok && rx_valid) begin
                rx_overrun <= 1'b1;
            end else if (wr_status && PWDATA[3]) begin
                rx_overrun <= 1'b0;
            end

            if (rx_stop_err) begin
                rx_frame_err <= 1'b1;
            end else if (wr_status && PWDATA[4]) begin
                rx_frame_err <= 1'b0;
            end

            // Receiver FSM
            if (!rx_en) begin
                rx_state   <= RX_IDLE;
                rx_clk_cnt <= 24'd0;
                rx_bit_cnt <= 3'd0;
            end else begin
                case (rx_state)
                    RX_IDLE: begin
                        rx_clk_cnt <= 24'd0;
                        rx_bit_cnt <= 3'd0;
                        if (rx_sync2 == 1'b0) begin
                            rx_state <= RX_START;
                        end
                    end

                    RX_START: begin
                        if (rx_clk_cnt >= ((baud_div >> 1) - 24'd1)) begin
                            rx_clk_cnt <= 24'd0;
                            if (rx_sync2 == 1'b0) begin
                                rx_state   <= RX_DATA;
                                rx_bit_cnt <= 3'd0;
                            end else begin
                                rx_state <= RX_IDLE;
                            end
                        end else begin
                            rx_clk_cnt <= rx_clk_cnt + 24'd1;
                        end
                    end

                    RX_DATA: begin
                        if (rx_clk_cnt >= (baud_div - 24'd1)) begin
                            rx_clk_cnt <= 24'd0;
                            rx_shift   <= {rx_sync2, rx_shift[7:1]};
                            if (rx_bit_cnt == 3'd7) begin
                                rx_state <= RX_STOP;
                            end else begin
                                rx_bit_cnt <= rx_bit_cnt + 3'd1;
                            end
                        end else begin
                            rx_clk_cnt <= rx_clk_cnt + 24'd1;
                        end
                    end

                    RX_STOP: begin
                        if (rx_clk_cnt >= (baud_div - 24'd1)) begin
                            rx_clk_cnt <= 24'd0;
                            rx_state   <= RX_IDLE;
                            if ((rx_sync2 == 1'b1) && !rx_valid) begin
                                rx_data  <= rx_shift;
                                rx_valid <= 1'b1;
                            end
                        end else begin
                            rx_clk_cnt <= rx_clk_cnt + 24'd1;
                        end
                    end

                    default: begin
                        rx_state <= RX_IDLE;
                    end
                endcase
            end
        end
    end

endmodule
