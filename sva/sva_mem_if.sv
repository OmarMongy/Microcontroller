// SVA Checker: Local Memories (irom_local, dram_local) & Decoder Boundary (Part A)
// Derived strictly from CON-MEM-001 v1.1, CON-ADDR-001 v1.1, CON-APB3-001 v1.1.
// Implemented using Verilator 5.032-supported concurrent SVA + auxiliary shadow state.

module sva_mem_if (
  input logic        clk,
  input logic        sys_rst_n,
  input logic        fault_valid,

  // irom_local Port A & Port B
  input logic        irom_en,
  input logic [14:0] irom_addr,
  input logic [31:0] irom_rdata,
  input logic        irom_dreq,
  input logic [14:0] irom_daddr,
  input logic [31:0] irom_drdata,

  // dram_local (Option RAM-B)
  input logic        dram_req,
  input logic        dram_we,
  input logic [3:0]  dram_be,
  input logic [14:0] dram_addr,
  input logic [31:0] dram_rdata,

  // CPU <-> data_bus_decode boundary
  input logic        dmem_req,
  input logic        dmem_we,
  input logic [1:0]  dmem_size,
  input logic [31:0] dmem_addr,
  input logic [31:0] dmem_wdata,
  input logic        dmem_stall,
  input logic        dmem_fault_valid,
  input logic [3:0]  dmem_fault_code,
  input logic        apb_req_valid
);

  logic        q_irom_dreq, q_dram_rd, q_stall_hold;
  logic [31:0] q_irom_drdata, q_dram_rdata;
  logic        q_dmem_req, q_dmem_we;
  logic [1:0]  q_dmem_size;
  logic [31:0] q_dmem_addr, q_dmem_wdata;
  logic [14:0] unused_daddrs;
  assign unused_daddrs = irom_daddr ^ dram_addr;

  always_ff @(posedge clk) begin
    if (!sys_rst_n) begin
      q_irom_dreq   <= 1'b0;
      q_dram_rd     <= 1'b0;
      q_stall_hold  <= 1'b0;
      q_irom_drdata <= 32'h0;
      q_dram_rdata  <= 32'h0;
      q_dmem_req    <= 1'b0;
      q_dmem_we     <= 1'b0;
      q_dmem_size   <= 2'b0;
      q_dmem_addr   <= 32'h0;
      q_dmem_wdata  <= 32'h0;
    end else begin
      q_irom_dreq   <= irom_dreq;
      q_dram_rd     <= (dram_req && !dram_we);
      q_stall_hold  <= (dmem_stall && !fault_valid);
      q_irom_drdata <= irom_drdata;
      q_dram_rdata  <= dram_rdata;
      q_dmem_req    <= dmem_req;
      q_dmem_we     <= dmem_we;
      q_dmem_size   <= dmem_size;
      q_dmem_addr   <= dmem_addr;
      q_dmem_wdata  <= dmem_wdata;
    end
  end

  // SVA-MEM-001: irom_local Port A alignment & zero when disabled
  a_mem_001a_porta_en: assert property (@(posedge clk) disable iff (!sys_rst_n)
    irom_en |-> (irom_addr[1:0] == 2'b00 && !fault_valid));
  a_mem_001b_porta_zero: assert property (@(posedge clk)
    !irom_en |-> (irom_rdata == 32'h0));

  // SVA-MEM-002: irom_local Port B 1-cycle strobe (C0 only)
  a_mem_002_portb_pulse: assert property (@(posedge clk) disable iff (!sys_rst_n)
    q_irom_dreq |-> !irom_dreq);

  // SVA-MEM-003: irom_local Port B registered output stable when !irom_dreq in prior cycle
  a_mem_003_portb_hold: assert property (@(posedge clk) disable iff (!sys_rst_n)
    !q_irom_dreq |-> (irom_drdata == q_irom_drdata));

  // SVA-MEM-004: No write path on IROM stores
  a_mem_004_no_irom_wr: assert property (@(posedge clk) disable iff (!sys_rst_n)
    (dmem_req && dmem_addr[31:15] == 17'h0000_0 && dmem_we) |->
      (!irom_dreq && !dram_req && !apb_req_valid));

  // SVA-MEM-005: dram_local byte enables & fault gating
  a_mem_005a_dram_rd_be: assert property (@(posedge clk) disable iff (!sys_rst_n)
    (dram_req && !dram_we) |-> (dram_be == 4'b0000));
  a_mem_005b_dram_wr_be: assert property (@(posedge clk) disable iff (!sys_rst_n)
    (dram_req && dram_we) |->
      (dram_be inside {4'b0001, 4'b0010, 4'b0100, 4'b1000, 4'b0011, 4'b1100, 4'b1111}));
  a_mem_005c_dram_no_fault: assert property (@(posedge clk) disable iff (!sys_rst_n)
    dram_req |-> !fault_valid);

  // SVA-MEM-006: dram_local read 1-cycle strobe (C0 only)
  a_mem_006_dram_rd_pulse: assert property (@(posedge clk) disable iff (!sys_rst_n)
    q_dram_rd |-> !(dram_req && !dram_we));

  // SVA-MEM-007: dram_rdata stable when prior cycle was not a DRAM read issue
  a_mem_007_dram_rdata_hold: assert property (@(posedge clk) disable iff (!sys_rst_n)
    !q_dram_rd |-> (dram_rdata == q_dram_rdata));

  // SVA-MEM-008: Mutual exclusion of local & APB requests
  a_mem_008_mutex: assert property (@(posedge clk) disable iff (!sys_rst_n)
    $onehot0({irom_dreq, dram_req, apb_req_valid}));

  // SVA-MEM-009: Reset gating of memory requests & outputs (no disable iff)
  a_mem_009_reset: assert property (@(posedge clk)
    !sys_rst_n |-> (!irom_en && !irom_dreq && !dram_req && !apb_req_valid &&
                    irom_drdata == 32'h0 && dram_rdata == 32'h0));

  // SVA-DEC-001: Pre-check fault suppresses all memory/APB requests
  a_dec_001_fault_suppress: assert property (@(posedge clk) disable iff (!sys_rst_n)
    (dmem_fault_valid && dmem_fault_code != 4'h9) |->
      (!irom_dreq && !dram_req && !apb_req_valid));

  // SVA-DEC-002: APB3 sub-word / unaligned rejection (Option APB-W1)
  a_dec_002_apb_w1: assert property (@(posedge clk) disable iff (!sys_rst_n)
    (dmem_req &&
     (dmem_addr[31:12] inside {20'h4000_0, 20'h4000_1, 20'h4000_2}) &&
     (dmem_size != 2'b10 || dmem_addr[1:0] != 2'b00)) |->
      (!apb_req_valid && dmem_fault_valid));

  // SVA-DEC-003: CPU holds dmem_* request lines stable while stalled
  a_dec_003_dmem_hold: assert property (@(posedge clk) disable iff (!sys_rst_n)
    q_stall_hold |->
      (dmem_req == q_dmem_req && dmem_we == q_dmem_we && dmem_size == q_dmem_size &&
       dmem_addr == q_dmem_addr && dmem_wdata == q_dmem_wdata));

  // Cover properties (COV-SVA-006..007)
  c_mem_006_irom_portb_load: cover property (@(posedge clk) disable iff (!sys_rst_n)
    (q_irom_dreq && !irom_dreq && !dmem_stall));

  c_mem_007_dram_ld_then_st: cover property (@(posedge clk) disable iff (!sys_rst_n)
    (!q_dram_rd && !dmem_stall && dram_req && dram_we));

endmodule
