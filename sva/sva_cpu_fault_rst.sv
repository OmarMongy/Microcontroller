// SVA Checkers: Top-Level Fault/Reset Boundary (Part A) & CPU/Reset Internals (Part B)
// Derived strictly from CON-FLT-RST-001 v1.1, CON-TOP-001 v1.1, DEC-ARCH-CORE-002.
// Implemented using Verilator 5.032-supported concurrent SVA + auxiliary shadow state.

// Part A: Top-level soc_top boundary checker (no internal RTL dependencies)
module sva_soc_fault_rst_if (
  input logic        clk,
  input logic        rst_n,
  input logic        uart_tx_o,
  input logic [7:0]  gpio_o,
  input logic [7:0]  gpio_oe_o,
  input logic        fault_o,
  input logic [3:0]  fault_code_o,
  input logic [31:0] fault_pc_o,
  input logic [31:0] fault_addr_o,
  input logic [31:0] fault_insn_o
);

  logic        q_fault_o, q_fault_seen;
  logic [3:0]  q_fault_code_o;
  logic [31:0] q_fault_pc_o, q_fault_addr_o, q_fault_insn_o;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      q_fault_o      <= 1'b0;
      q_fault_code_o <= 4'h0;
      q_fault_pc_o   <= 32'h0;
      q_fault_addr_o <= 32'h0;
      q_fault_insn_o <= 32'h0;
    end else begin
      q_fault_o      <= fault_o;
      q_fault_code_o <= fault_code_o;
      q_fault_pc_o   <= fault_pc_o;
      q_fault_addr_o <= fault_addr_o;
      q_fault_insn_o <= fault_insn_o;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      q_fault_seen <= q_fault_seen || fault_o;
    end else if (fault_o) begin
      q_fault_seen <= 1'b1;
    end
  end

  // SVA-FLT-001: Valid fault_code_o encoding
  a_flt_001a_no_fault_code: assert property (@(posedge clk) disable iff (!rst_n)
    !fault_o |-> (fault_code_o == 4'h0));
  a_flt_001b_fault_code_range: assert property (@(posedge clk) disable iff (!rst_n)
    fault_o |-> (fault_code_o >= 4'h1 && fault_code_o <= 4'hA));

  // SVA-FLT-002: Fault context format rules
  a_flt_002a_if_fmt: assert property (@(posedge clk) disable iff (!rst_n)
    (fault_o && (fault_code_o == 4'h1 || fault_code_o == 4'h2)) |->
      (fault_insn_o == 32'h0 && fault_addr_o == fault_pc_o));
  a_flt_002b_dec_fmt: assert property (@(posedge clk) disable iff (!rst_n)
    (fault_o && (fault_code_o == 4'h3 || fault_code_o == 4'h4 || fault_code_o == 4'h5)) |->
      (fault_addr_o == 32'h0));

  // SVA-FLT-003: Sticky fault capture until rst_n == 0
  a_flt_003_sticky: assert property (@(posedge clk) disable iff (!rst_n)
    q_fault_o |-> (fault_o && fault_code_o == q_fault_code_o &&
                   fault_pc_o == q_fault_pc_o && fault_addr_o == q_fault_addr_o &&
                   fault_insn_o == q_fault_insn_o));

  // SVA-RST-003 / SVA-RST-005: External reset holds pins & fault outputs in reset state
  a_rst_003_005_top: assert property (@(posedge clk)
    !rst_n |-> (!fault_o && fault_code_o == 4'h0 && fault_pc_o == 32'h0 &&
                fault_addr_o == 32'h0 && fault_insn_o == 32'h0 &&
                uart_tx_o == 1'b1 && gpio_oe_o == 8'h00 && gpio_o == 8'h00));

  // SVA-RST-006: fault_o can only fall when !rst_n
  a_rst_006_fault_recovery: assert property (@(posedge clk)
    (q_fault_o && !fault_o) |-> !rst_n);

  c_rst_010_fault_recover: cover property (@(posedge clk)
    (rst_n && !fault_o && q_fault_seen));

endmodule

// Part B: Internal CPU / Reset Synchronizer / Decoder assertions
module sva_cpu_internal (
  input logic        clk,
  input logic        rst_n,
  input logic        sys_rst_n,
  input logic        sync_ff1,
  input logic        sync_ff2,
  input logic [31:0] pc,
  input logic [31:0] insn,
  input logic [31:0] rf_x0,
  input logic        rf_we,
  input logic        dmem_req,
  input logic        dmem_stall,
  input logic        local_rd_valid,
  input logic        fault_detect,
  input logic        fault_valid,
  input logic [3:0]  fault_code,
  input logic [31:0] fault_pc
);

  logic        q_stall_hold, q_stall_released, q_fence_valid, q_local_rd;
  logic        q_rst_n, q_sync_ff2, q_rst_rose_stage1;
  logic [31:0] q_pc;
  logic [3:0]  unused_fc;
  assign unused_fc = fault_code;

  always_ff @(posedge clk) begin
    if (!sys_rst_n) begin
      q_stall_hold     <= 1'b0;
      q_stall_released <= 1'b0;
      q_fence_valid    <= 1'b0;
      q_local_rd       <= 1'b0;
      q_pc             <= 32'h0;
    end else begin
      q_stall_hold     <= (dmem_stall && !fault_valid);
      q_stall_released <= (q_stall_hold && !dmem_stall && !fault_detect && !fault_valid);
      q_fence_valid    <= (!fault_valid && (pc[31:15] == 17'h0000_0) && (pc[1:0] == 2'b00) &&
                           insn[6:0] == 7'b0001111 && insn[14:12] == 3'b000);
      q_local_rd       <= local_rd_valid;
      q_pc             <= pc;
    end
  end

  always_ff @(posedge clk) begin
    q_rst_n           <= rst_n;
    q_sync_ff2        <= sync_ff2;
    q_rst_rose_stage1 <= (!q_rst_n && rst_n && !q_sync_ff2);
  end

  // SVA-CPU-001: x0 immutability
  a_cpu_001_x0_zero: assert property (@(posedge clk) (rf_x0 == 32'h0));

  // SVA-CPU-003: PC frozen during dmem_stall
  a_cpu_003_pc_hold: assert property (@(posedge clk) disable iff (!sys_rst_n)
    q_stall_hold |-> (pc == q_pc));

  // SVA-CPU-004: No premature or faulted RF writeback
  a_cpu_004_rf_we_gate: assert property (@(posedge clk) disable iff (!sys_rst_n)
    rf_we |-> (!dmem_stall && !fault_detect && !fault_valid));

  // SVA-CPU-005: Exactly-once advance when dmem_stall releases without fault
  a_cpu_005_commit_release: assert property (@(posedge clk) disable iff (!sys_rst_n)
    q_stall_released |-> (pc == (q_pc + 32'd4)));

  // SVA-CPU-006 (V2 clean split): FENCE NOP
  a_cpu_006a_fence_ctrl: assert property (@(posedge clk) disable iff (!sys_rst_n)
    (!fault_valid && (pc[31:15] == 17'h0000_0) && (pc[1:0] == 2'b00) &&
     insn[6:0] == 7'b0001111 && insn[14:12] == 3'b000) |->
      (!dmem_req && !dmem_stall && !rf_we && !fault_detect));
  a_cpu_006b_fence_pc: assert property (@(posedge clk) disable iff (!sys_rst_n)
    q_fence_valid |-> (pc == (q_pc + 32'd4)));

  // SVA-INT-001: local_rd_valid is at most 1-cycle pulse
  a_int_001_local_rd_pulse: assert property (@(posedge clk) disable iff (!sys_rst_n)
    q_local_rd |-> !local_rd_valid);

  // SVA-FLT-004: Halt quiescence
  a_flt_004_halt_quiescent: assert property (@(posedge clk) disable iff (!sys_rst_n)
    fault_valid |-> (pc == fault_pc && !rf_we && !dmem_req));

  // SVA-RST-001: Async assert clears sync_ff1, sync_ff2, sys_rst_n
  a_rst_001_async_assert: assert property (@(posedge clk)
    !rst_n |-> (!sync_ff1 && !sync_ff2 && !sys_rst_n));

  // SVA-RST-002: 2-FF sync deassert (first cycle after rst_n rises, sys_rst_n still 0)
  a_rst_002_sync_release: assert property (@(posedge clk)
    (q_rst_rose_stage1 && rst_n) |-> !sys_rst_n);

  // SVA-RST-004: Reset clears local_rd_valid & PC
  a_rst_004_clear_state: assert property (@(posedge clk)
    !sys_rst_n |-> (!local_rd_valid && pc == 32'h0));

endmodule
