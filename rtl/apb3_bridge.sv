// AMBA APB3 Requester Bridge (Design 4A: IDLE -> SETUP -> ACCESS)
// Strict ARM IHI0024E APB3 subset (no APB4/APB5 signals)
// Contracts: CON-APB3-001 v1.1, CON-ADDR-001 v1.1

module apb3_bridge (
    input  logic        clk,
    input  logic        sys_rst_n,

    // data_bus_decode handshake
    input  logic        apb_req_valid,
    input  logic        apb_req_write,
    input  logic [31:0] apb_req_addr,
    input  logic [31:0] apb_req_wdata,
    output logic        apb_rsp_ready,
    output logic [31:0] apb_rsp_rdata,
    output logic        apb_rsp_err,

    // APB3 Requester bus outputs (registered)
    output logic [31:0] PADDR,
    output logic        PSEL_UART,
    output logic        PSEL_GPIO,
    output logic        PSEL_TIMER,
    output logic        PENABLE,
    output logic        PWRITE,
    output logic [31:0] PWDATA,

    // APB3 Completer bus inputs
    input  logic        PREADY_UART,
    input  logic [31:0] PRDATA_UART,
    input  logic        PSLVERR_UART,
    input  logic        PREADY_GPIO,
    input  logic [31:0] PRDATA_GPIO,
    input  logic        PSLVERR_GPIO,
    input  logic        PREADY_TIMER,
    input  logic [31:0] PRDATA_TIMER,
    input  logic        PSLVERR_TIMER
);

    typedef enum logic [1:0] {
        APB_IDLE   = 2'b00,
        APB_SETUP  = 2'b01,
        APB_ACCESS = 2'b10
    } apb_state_e;

    apb_state_e state;

    logic        pready_mux;
    logic [31:0] prdata_mux;
    logic        pslverr_mux;

    // Completer response mux (selected by one-hot PSELx)
    always_comb begin
        if (PSEL_UART) begin
            pready_mux  = PREADY_UART;
            prdata_mux  = PRDATA_UART;
            pslverr_mux = PSLVERR_UART;
        end else if (PSEL_GPIO) begin
            pready_mux  = PREADY_GPIO;
            prdata_mux  = PRDATA_GPIO;
            pslverr_mux = PSLVERR_GPIO;
        end else if (PSEL_TIMER) begin
            pready_mux  = PREADY_TIMER;
            prdata_mux  = PRDATA_TIMER;
            pslverr_mux = PSLVERR_TIMER;
        end else begin
            pready_mux  = 1'b0;
            prdata_mux  = 32'h0000_0000;
            pslverr_mux = 1'b0;
        end
    end

    // Registered APB3 FSM & bus outputs (Design 4A)
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            state      <= APB_IDLE;
            PSEL_UART  <= 1'b0;
            PSEL_GPIO  <= 1'b0;
            PSEL_TIMER <= 1'b0;
            PENABLE    <= 1'b0;
            PWRITE     <= 1'b0;
            PADDR      <= 32'h0000_0000;
            PWDATA     <= 32'h0000_0000;
        end else begin
            case (state)
                APB_IDLE: begin
                    if (apb_req_valid) begin
                        state      <= APB_SETUP;
                        PSEL_UART  <= (apb_req_addr[31:12] == soc_pkg::APB_UART_PREFIX);
                        PSEL_GPIO  <= (apb_req_addr[31:12] == soc_pkg::APB_GPIO_PREFIX);
                        PSEL_TIMER <= (apb_req_addr[31:12] == soc_pkg::APB_TIMER_PREFIX);
                        PENABLE    <= 1'b0;
                        PWRITE     <= apb_req_write;
                        PADDR      <= apb_req_addr;
                        PWDATA     <= apb_req_write ? apb_req_wdata : 32'h0000_0000;
                    end else begin
                        state      <= APB_IDLE;
                        PSEL_UART  <= 1'b0;
                        PSEL_GPIO  <= 1'b0;
                        PSEL_TIMER <= 1'b0;
                        PENABLE    <= 1'b0;
                        PWRITE     <= 1'b0;
                        PADDR      <= 32'h0000_0000;
                        PWDATA     <= 32'h0000_0000;
                    end
                end

                APB_SETUP: begin
                    state   <= APB_ACCESS;
                    PENABLE <= 1'b1;
                end

                APB_ACCESS: begin
                    if (pready_mux) begin
                        state      <= APB_IDLE;
                        PSEL_UART  <= 1'b0;
                        PSEL_GPIO  <= 1'b0;
                        PSEL_TIMER <= 1'b0;
                        PENABLE    <= 1'b0;
                        PWRITE     <= 1'b0;
                        PADDR      <= 32'h0000_0000;
                        PWDATA     <= 32'h0000_0000;
                    end
                end

                default: begin
                    state      <= APB_IDLE;
                    PSEL_UART  <= 1'b0;
                    PSEL_GPIO  <= 1'b0;
                    PSEL_TIMER <= 1'b0;
                    PENABLE    <= 1'b0;
                    PWRITE     <= 1'b0;
                    PADDR      <= 32'h0000_0000;
                    PWDATA     <= 32'h0000_0000;
                end
            endcase
        end
    end

    // Combinational completion handshake
    assign apb_rsp_ready = (state == APB_ACCESS) && pready_mux;
    assign apb_rsp_rdata = prdata_mux;
    assign apb_rsp_err   = apb_rsp_ready && pslverr_mux;

endmodule
