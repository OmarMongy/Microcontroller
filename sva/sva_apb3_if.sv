// SVA Checker: APB3 Bus & Bridge Handshake Interface (Part A — Port Boundary)
// Derived strictly from ARM IHI 0024E (Issue B / APB3) and CON-APB3-001 v1.1.
// Implemented using Verilator 5.032-supported concurrent SVA + auxiliary shadow state.

module sva_apb3_if (
  input logic        PCLK,
  input logic        PRESETn,
  input logic [31:0] PADDR,
  input logic        PSEL_UART,
  input logic        PSEL_GPIO,
  input logic        PSEL_TIMER,
  input logic        PENABLE,
  input logic        PWRITE,
  input logic [31:0] PWDATA,
  input logic        PREADY_mux,
  input logic [31:0] PRDATA_mux,
  input logic        PSLVERR_mux,

  // Bridge <-> data_bus_decode boundary signals (CON-APB3-001 §3.1)
  input logic        apb_req_valid,
  input logic        apb_req_write,
  input logic [31:0] apb_req_addr,
  input logic [31:0] apb_req_wdata,
  input logic        apb_rsp_ready,
  input logic        dmem_fault_valid,
  input logic [3:0]  dmem_fault_code
);

  logic [2:0] psel_vec;
  logic       psel_any;
  logic       apb_setup;
  logic       apb_access;
  logic       apb_xfer_done;

  assign psel_vec      = {PSEL_TIMER, PSEL_GPIO, PSEL_UART};
  assign psel_any      = |psel_vec;
  assign apb_setup     = psel_any && !PENABLE;
  assign apb_access    = psel_any && PENABLE;
  assign apb_xfer_done = apb_access && PREADY_mux;

  // Auxiliary shadow state for sequence checks & covers (Verilator 5.032 safe)
  logic        q_in_setup, q_in_wait, q_done, q_idle_no_req, q_idle_req;
  logic [2:0]  q_psel_vec;
  logic [31:0] q_paddr, q_pwdata, q_req_addr, q_req_wdata;
  logic        q_pwrite, q_req_write;
  int unsigned q_wait_cnt;
  logic        q_slverr_seen_in_wait;
  logic [31:0] unused_prdata;
  assign unused_prdata = PRDATA_mux;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      q_in_setup            <= 1'b0;
      q_in_wait             <= 1'b0;
      q_done                <= 1'b0;
      q_idle_no_req         <= 1'b0;
      q_idle_req            <= 1'b0;
      q_psel_vec            <= 3'b000;
      q_paddr               <= 32'h0;
      q_pwdata              <= 32'h0;
      q_pwrite              <= 1'b0;
      q_req_addr            <= 32'h0;
      q_req_wdata           <= 32'h0;
      q_req_write           <= 1'b0;
      q_wait_cnt            <= 0;
      q_slverr_seen_in_wait <= 1'b0;
    end else begin
      q_in_setup    <= apb_setup;
      q_in_wait     <= (apb_access && !PREADY_mux);
      q_done        <= apb_xfer_done;
      q_idle_no_req <= (!psel_any && !apb_req_valid);
      q_idle_req    <= (!psel_any && apb_req_valid);
      q_psel_vec    <= psel_vec;
      q_paddr       <= PADDR;
      q_pwdata      <= PWDATA;
      q_pwrite      <= PWRITE;
      q_req_addr    <= apb_req_addr;
      q_req_wdata   <= apb_req_wdata;
      q_req_write   <= apb_req_write;

      if (apb_setup) begin
        q_wait_cnt            <= 0;
        q_slverr_seen_in_wait <= 1'b0;
      end else if (apb_access && !PREADY_mux) begin
        q_wait_cnt            <= q_wait_cnt + 1;
        q_slverr_seen_in_wait <= q_slverr_seen_in_wait || PSLVERR_mux;
      end else if (apb_xfer_done) begin
        q_wait_cnt            <= 0;
        q_slverr_seen_in_wait <= 1'b0;
      end
    end
  end

  // SVA-APB-001: Reset state quiescent (no disable iff)
  a_apb_001_reset_idle: assert property (@(posedge PCLK)
    !PRESETn |-> (!psel_any && !PENABLE && !PWRITE && PADDR == 32'h0 && PWDATA == 32'h0));

  // SVA-APB-002: One-hot0 PSELx
  a_apb_002_onehot0: assert property (@(posedge PCLK) disable iff (!PRESETn)
    $onehot0(psel_vec));

  // SVA-APB-003: PSELx address range & 4-byte alignment (Option APB-W1)
  a_apb_003a_uart_addr: assert property (@(posedge PCLK) disable iff (!PRESETn)
    PSEL_UART |-> (PADDR[31:12] == 20'h4000_0 && PADDR[1:0] == 2'b00));
  a_apb_003b_gpio_addr: assert property (@(posedge PCLK) disable iff (!PRESETn)
    PSEL_GPIO |-> (PADDR[31:12] == 20'h4000_1 && PADDR[1:0] == 2'b00));
  a_apb_003c_timer_addr: assert property (@(posedge PCLK) disable iff (!PRESETn)
    PSEL_TIMER |-> (PADDR[31:12] == 20'h4000_2 && PADDR[1:0] == 2'b00));

  // SVA-APB-004: No PENABLE without PSELx
  a_apb_004_penable_psel: assert property (@(posedge PCLK) disable iff (!PRESETn)
    PENABLE |-> psel_any);

  // SVA-APB-005: Single-cycle SETUP -> ACCESS for same Completer
  a_apb_005_setup_to_access: assert property (@(posedge PCLK) disable iff (!PRESETn)
    q_in_setup |-> (apb_access && (psel_vec == q_psel_vec)));

  // SVA-APB-006: Control/address/write-data stability across SETUP->ACCESS & wait states
  a_apb_006_hold_stable: assert property (@(posedge PCLK) disable iff (!PRESETn)
    (q_in_setup || q_in_wait) |->
      (PADDR == q_paddr && PWRITE == q_pwrite && psel_vec == q_psel_vec &&
       (!PWRITE || PWDATA == q_pwdata)));

  // SVA-APB-007: No restart of SETUP during ACCESS wait states
  a_apb_007_wait_penable: assert property (@(posedge PCLK) disable iff (!PRESETn)
    q_in_wait |-> PENABLE);

  // SVA-APB-008: Design 4A transitions ACCESS && PREADY -> IDLE
  a_apb_008_done_to_idle: assert property (@(posedge PCLK) disable iff (!PRESETn)
    q_done |-> (!psel_any && !PENABLE));

  // SVA-APB-009: Bridge request-to-APB consistency
  a_apb_009a_req_gate: assert property (@(posedge PCLK) disable iff (!PRESETn)
    q_idle_no_req |-> !psel_any);
  a_apb_009b_req_match: assert property (@(posedge PCLK) disable iff (!PRESETn)
    q_idle_req |-> (apb_setup && PADDR == q_req_addr && PWRITE == q_req_write &&
                    (!PWRITE || PWDATA == q_req_wdata)));

  // SVA-APB-010: PSLVERR ignored outside ACCESS && PREADY; apb_rsp_ready exact
  a_apb_010a_rsp_ready: assert property (@(posedge PCLK) disable iff (!PRESETn)
    apb_rsp_ready == apb_xfer_done);
  a_apb_010b_no_early_slverr: assert property (@(posedge PCLK) disable iff (!PRESETn)
    (apb_setup || (apb_access && !PREADY_mux)) |->
      (!apb_rsp_ready && !(dmem_fault_valid && dmem_fault_code == 4'h9)));

  // Functional Cover Properties (COV-SVA-001..005)
  c_apb_001_wr_0wait: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (apb_xfer_done && PWRITE && q_wait_cnt == 0));
  c_apb_002_rd_0wait: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (apb_xfer_done && !PWRITE && q_wait_cnt == 0));
  c_apb_003_multi_wait: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (apb_xfer_done && q_wait_cnt >= 2));
  c_apb_004_slverr_ignored: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (apb_xfer_done && q_slverr_seen_in_wait && !PSLVERR_mux));
  c_apb_005_slverr_fault: cover property (@(posedge PCLK) disable iff (!PRESETn)
    (apb_xfer_done && PSLVERR_mux));

endmodule
