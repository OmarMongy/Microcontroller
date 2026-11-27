// Deterministic Functional Coverage Collector (COVERAGE_PLAN_V2.md / SOC_VB_002)
// Samples committed RV32I instructions, memory regions, APB3 protocol events,
// fault codes/priorities, reset recovery, and peripheral register operations.

module tb_cov_collector
  import tb_pkg::*;
(
  input logic        clk,
  input logic        sys_rst_n,

  // Retirement / CPU observation
  input logic        retire_valid,
  input logic [31:0] retire_pc,
  input logic [31:0] retire_insn,
  input logic        dmem_stall,

  // Data access observation
  input logic        dmem_req,
  input logic        dmem_we,
  input logic [1:0]  dmem_size,
  input logic [31:0] dmem_addr,
  input logic [3:0]  dram_be,

  // APB3 observation
  input logic        psel_uart,
  input logic        psel_gpio,
  input logic        psel_timer,
  input logic        penable,
  input logic        pwrite,
  input logic [31:0] paddr,
  input logic        pready,
  input logic        pslverr,

  // Fault observation
  input logic        fault_o,
  input logic [3:0]  fault_code_o
);

  // Core coverage counters
  int unsigned cov_insn_alu_reg, cov_insn_alu_imm, cov_insn_branch, cov_insn_jal, cov_insn_jalr;
  int unsigned cov_insn_lui, cov_insn_auipc, cov_insn_load, cov_insn_store, cov_insn_fence;
  int unsigned cov_x0_dest;
  int unsigned cov_irom_rodata_rd, cov_dram_rd, cov_dram_wr;
  int unsigned cov_dram_be_0001, cov_dram_be_0010, cov_dram_be_0100, cov_dram_be_1000;
  int unsigned cov_dram_be_0011, cov_dram_be_1100, cov_dram_be_1111;
  int unsigned cov_apb_uart, cov_apb_gpio, cov_apb_timer;
  int unsigned cov_apb_wait0, cov_apb_wait1, cov_apb_wait2plus, cov_apb_slverr;
  int unsigned cov_fault_bins [0:15];
  int unsigned cov_rst_during_stall, cov_rst_from_fault;

  // Peripheral register coverage counters (SOC_VB_002)
  int unsigned cov_uart_reg_acc [0:4];
  int unsigned cov_gpio_reg_acc [0:2];
  int unsigned cov_timer_reg_acc [0:3];

  int unsigned apb_wait_cycles;
  logic        fault_q;
  logic        stall_q;

  always_ff @(posedge clk) begin
    if (!sys_rst_n) begin
      if (stall_q) cov_rst_during_stall <= cov_rst_during_stall + 1;
      if (fault_q) cov_rst_from_fault   <= cov_rst_from_fault + 1;
      apb_wait_cycles <= 0;
      fault_q <= 1'b0;
      stall_q <= 1'b0;
    end else begin
      fault_q <= fault_o;
      stall_q <= dmem_stall;

      // Fault code bins on rising edge of fault_o
      if (fault_o && !fault_q) begin
        cov_fault_bins[fault_code_o] <= cov_fault_bins[fault_code_o] + 1;
      end

      // Instruction class coverage on retirement
      if (retire_valid && !fault_o) begin
        logic [6:0] opc;
        logic [2:0] f3;
        logic [4:0] rd;
        opc = retire_insn[6:0];
        f3  = retire_insn[14:12];
        rd  = retire_insn[11:7];
        if (rd == 5'd0) cov_x0_dest <= cov_x0_dest + 1;
        unique case (opc)
          7'b0110111: cov_insn_lui     <= cov_insn_lui + 1;
          7'b0010111: cov_insn_auipc   <= cov_insn_auipc + 1;
          7'b1101111: cov_insn_jal     <= cov_insn_jal + 1;
          7'b1100111: cov_insn_jalr    <= cov_insn_jalr + 1;
          7'b1100011: cov_insn_branch  <= cov_insn_branch + 1;
          7'b0000011: cov_insn_load    <= cov_insn_load + 1;
          7'b0100011: cov_insn_store   <= cov_insn_store + 1;
          7'b0010011: cov_insn_alu_imm <= cov_insn_alu_imm + 1;
          7'b0110011: cov_insn_alu_reg <= cov_insn_alu_reg + 1;
          7'b0001111: if (f3 == 3'b000) cov_insn_fence <= cov_insn_fence + 1;
          default: ;
        endcase

        // Local memory region / byte-enable coverage
        if (dmem_req) begin
          if (!dmem_we && is_in_irom(dmem_addr)) cov_irom_rodata_rd <= cov_irom_rodata_rd + 1;
          if (!dmem_we && is_in_dram(dmem_addr)) cov_dram_rd        <= cov_dram_rd + 1;
          if (dmem_we && is_in_dram(dmem_addr)) begin
            cov_dram_wr <= cov_dram_wr + 1;
            case (dram_be)
              4'b0001: cov_dram_be_0001 <= cov_dram_be_0001 + 1;
              4'b0010: cov_dram_be_0010 <= cov_dram_be_0010 + 1;
              4'b0100: cov_dram_be_0100 <= cov_dram_be_0100 + 1;
              4'b1000: cov_dram_be_1000 <= cov_dram_be_1000 + 1;
              4'b0011: cov_dram_be_0011 <= cov_dram_be_0011 + 1;
              4'b1100: cov_dram_be_1100 <= cov_dram_be_1100 + 1;
              4'b1111: cov_dram_be_1111 <= cov_dram_be_1111 + 1;
              default: ;
            endcase
          end
        end
      end

      // APB3 wait states & peripheral register coverage
      if ((psel_uart || psel_gpio || psel_timer) && penable) begin
        if (!pready) begin
          apb_wait_cycles <= apb_wait_cycles + 1;
        end else begin
          if (apb_wait_cycles == 0) cov_apb_wait0 <= cov_apb_wait0 + 1;
          else if (apb_wait_cycles == 1) cov_apb_wait1 <= cov_apb_wait1 + 1;
          else cov_apb_wait2plus <= cov_apb_wait2plus + 1;
          apb_wait_cycles <= 0;

          if (pslverr) cov_apb_slverr <= cov_apb_slverr + 1;

          if (psel_uart) begin
            cov_apb_uart <= cov_apb_uart + 1;
            if (paddr[11:0] <= 12'h010 && paddr[1:0] == 2'b00)
              cov_uart_reg_acc[paddr[4:2]] <= cov_uart_reg_acc[paddr[4:2]] + 1;
          end
          if (psel_gpio) begin
            cov_apb_gpio <= cov_apb_gpio + 1;
            if (paddr[11:0] <= 12'h008 && paddr[1:0] == 2'b00)
              cov_gpio_reg_acc[paddr[3:2]] <= cov_gpio_reg_acc[paddr[3:2]] + 1;
          end
          if (psel_timer) begin
            cov_apb_timer <= cov_apb_timer + 1;
            if (paddr[11:0] <= 12'h00C && paddr[1:0] == 2'b00)
              cov_timer_reg_acc[paddr[3:2]] <= cov_timer_reg_acc[paddr[3:2]] + 1;
          end
        end
      end else begin
        apb_wait_cycles <= 0;
      end
    end
  end

  function automatic void print_summary();
    $display("=== COVERAGE SUMMARY (SOC_VB_002) ===");
    $display("RV32I: LUI=%0d AUIPC=%0d JAL=%0d JALR=%0d BR=%0d LD=%0d ST=%0d ALUI=%0d ALUR=%0d FENCE=%0d X0_DST=%0d",
             cov_insn_lui, cov_insn_auipc, cov_insn_jal, cov_insn_jalr, cov_insn_branch,
             cov_insn_load, cov_insn_store, cov_insn_alu_imm, cov_insn_alu_reg, cov_insn_fence, cov_x0_dest);
    $display("MEM: IROM_RD=%0d DRAM_RD=%0d DRAM_WR=%0d BE={0001:%0d,0010:%0d,0100:%0d,1000:%0d,0011:%0d,1100:%0d,1111:%0d}",
             cov_irom_rodata_rd, cov_dram_rd, cov_dram_wr,
             cov_dram_be_0001, cov_dram_be_0010, cov_dram_be_0100, cov_dram_be_1000,
             cov_dram_be_0011, cov_dram_be_1100, cov_dram_be_1111);
    $display("APB3: UART=%0d GPIO=%0d TIMER=%0d WAITS={0:%0d,1:%0d,2+:%0d} SLVERR=%0d",
             cov_apb_uart, cov_apb_gpio, cov_apb_timer,
             cov_apb_wait0, cov_apb_wait1, cov_apb_wait2plus, cov_apb_slverr);
    $display("FAULTS: 1=%0d 2=%0d 3=%0d 4=%0d 5=%0d 6=%0d 7=%0d 8=%0d 9=%0d A=%0d",
             cov_fault_bins[1], cov_fault_bins[2], cov_fault_bins[3], cov_fault_bins[4],
             cov_fault_bins[5], cov_fault_bins[6], cov_fault_bins[7], cov_fault_bins[8],
             cov_fault_bins[9], cov_fault_bins[10]);
    $display("RESET: DURING_STALL=%0d FROM_FAULT=%0d", cov_rst_during_stall, cov_rst_from_fault);
    $display("PERIPH_REGS: UART={%0d,%0d,%0d,%0d,%0d} GPIO={%0d,%0d,%0d} TIMER={%0d,%0d,%0d,%0d}",
             cov_uart_reg_acc[0], cov_uart_reg_acc[1], cov_uart_reg_acc[2], cov_uart_reg_acc[3], cov_uart_reg_acc[4],
             cov_gpio_reg_acc[0], cov_gpio_reg_acc[1], cov_gpio_reg_acc[2],
             cov_timer_reg_acc[0], cov_timer_reg_acc[1], cov_timer_reg_acc[2], cov_timer_reg_acc[3]);
  endfunction

endmodule
