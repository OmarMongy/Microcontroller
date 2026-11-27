// Independent Golden RV32I Behavioral Reference Model & Scoreboard
// Derived strictly from RV32I Base ISA, CON-ADDR-001, CON-MEM-001, CON-APB3-001,
// CON-FLT-RST-001, and DEC-ARCH-CORE-002 (zero RTL inspection).

module rv32i_golden_iss #(
  parameter string INIT_FILE = ""
) (
  input  logic        clk,
  input  logic        sys_rst_n,

  // DUT Architectural Retirement / Stall / Fault Observation
  input  logic [31:0] dut_pc,
  input  logic        dut_dmem_stall,
  input  logic        dut_fault_valid,
  input  logic [3:0]  dut_fault_code,
  input  logic [31:0] dut_fault_pc,
  input  logic [31:0] dut_fault_addr,
  input  logic [31:0] dut_fault_insn,

  // APB3 Completion Snoop (provides external PRDATA/PSLVERR oracle to ISS)
  input  logic        apb_xfer_done,
  input  logic        apb_xfer_write,
  input  logic [31:0] apb_xfer_addr,
  input  logic [31:0] apb_xfer_wdata,
  input  logic [31:0] apb_xfer_rdata,
  input  logic        apb_xfer_slverr,

  // Optional Register-File Writeback Check (from tb_core_bus)
  input  logic        dut_rf_we,
  input  logic [4:0]  dut_rf_waddr,
  input  logic [31:0] dut_rf_wdata,

  output int unsigned sb_retire_count,
  output int unsigned sb_error_count
);
  import tb_pkg::*;

  logic [31:0] gold_irom [0:IROM_WORDS-1];
  logic [31:0] gold_dram [0:DRAM_WORDS-1];
  logic [31:0] gold_rf   [0:31];
  logic [31:0] gold_pc;
  logic        gold_halted;
  logic [3:0]  gold_fault_code;
  logic [31:0] gold_fault_pc;
  logic [31:0] gold_fault_addr;
  logic [31:0] gold_fault_insn;

  // Latched APB completion result for the current stalled APB instruction
  logic        apb_latched_done;
  logic [31:0] apb_latched_rdata;
  logic        apb_latched_slverr;
  int unsigned apb_xfer_cnt_this_insn;

  initial begin
    for (int i = 0; i < IROM_WORDS; i++) gold_irom[i] = 32'h0;
    for (int i = 0; i < DRAM_WORDS; i++) gold_dram[i] = 32'h0;
    if (INIT_FILE != "") begin
      $readmemh(INIT_FILE, gold_irom);
    end
  end

  task automatic load_irom(input string path);
    for (int i = 0; i < IROM_WORDS; i++) gold_irom[i] = 32'h0;
    $readmemh(path, gold_irom);
  endtask

  task automatic fail_msg(input string msg);
    sb_error_count <= sb_error_count + 1;
    $display("[GOLDEN_ISS] MISMATCH at %0t: %s", $time, msg);
  endtask

  always_ff @(posedge clk) begin
    if (!sys_rst_n) begin
      gold_pc          <= 32'h0000_0000;
      gold_halted      <= 1'b0;
      gold_fault_code  <= FAULT_NONE;
      gold_fault_pc    <= 32'h0;
      gold_fault_addr  <= 32'h0;
      gold_fault_insn  <= 32'h0;
      apb_latched_done <= 1'b0;
      apb_latched_rdata <= 32'h0;
      apb_latched_slverr <= 1'b0;
      apb_xfer_cnt_this_insn <= 0;
      for (int i = 0; i < 32; i++) gold_rf[i] <= 32'h0;
    end else begin
      // Capture APB completion event when it occurs
      if (apb_xfer_done) begin
        apb_latched_done   <= 1'b1;
        apb_latched_rdata  <= apb_xfer_rdata;
        apb_latched_slverr <= apb_xfer_slverr;
        apb_xfer_cnt_this_insn <= apb_xfer_cnt_this_insn + 1;
      end

      if (gold_halted) begin
        if (!dut_fault_valid || dut_fault_code != gold_fault_code ||
            dut_fault_pc != gold_fault_pc || dut_fault_addr != gold_fault_addr ||
            dut_fault_insn != gold_fault_insn) begin
          fail_msg($sformatf("Halted state mutated! DUT fault=%b code=%h fault_pc=%h",
                             dut_fault_valid, dut_fault_code, dut_fault_pc));
        end
      end else begin
        // Effective APB completion including current T4 edge (when apb_xfer_done && !dut_dmem_stall)
        logic        apb_done_eff;
        logic [31:0] apb_rdata_eff;
        logic        apb_slverr_eff;
        int unsigned apb_cnt_eff;
        apb_done_eff   = apb_latched_done || apb_xfer_done;
        apb_rdata_eff  = apb_xfer_done ? apb_xfer_rdata : apb_latched_rdata;
        apb_slverr_eff = apb_xfer_done ? apb_xfer_slverr : apb_latched_slverr;
        apb_cnt_eff    = apb_xfer_cnt_this_insn + (apb_xfer_done ? 1 : 0);

        // Check PC alignment to golden model (only when gold_pc is inside IROM 15-bit irom_addr window)
        if (is_in_irom(gold_pc) && (dut_pc[14:0] !== gold_pc[14:0])) begin
          fail_msg($sformatf("PC mismatch: DUT=%h GOLD=%h", dut_pc, gold_pc));
        end

        // If stalled on memory/APB, no retirement and no rf_we allowed
        if (dut_dmem_stall) begin
          if (dut_rf_we) begin
            fail_msg($sformatf("Premature rf_we while dmem_stall=1 at PC=%h", gold_pc));
          end
        end else begin
          // Evaluate architectural step at PC = gold_pc
          logic [31:0] insn;
          logic [6:0]  opc;
          logic [2:0]  f3;
          logic [6:0]  f7;
          logic [4:0]  rs1, rs2, rd;
          logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
          logic [31:0] v1, v2;
          logic [31:0] next_pc;
          logic        wb_en;
          logic [31:0] wb_val;
          logic        exp_fault;
          logic [3:0]  exp_fcode;
          logic [31:0] exp_faddr;
          logic [31:0] exp_finsn;

          next_pc   = gold_pc + 32'd4;
          wb_en     = 1'b0;
          wb_val    = 32'h0;
          exp_fault = 1'b0;
          exp_fcode = FAULT_NONE;
          exp_faddr = 32'h0;
          exp_finsn = 32'h0;
          insn      = 32'h0;

          // Priority 1 & 2: Instruction Fetch checks (CON-FLT-RST-001 §1.2)
          if (!is_in_irom(gold_pc)) begin
            exp_fault = 1'b1;
            exp_fcode = FAULT_IF_UNMAPPED;
            exp_faddr = gold_pc;
            exp_finsn = 32'h0;
          end else if (gold_pc[1:0] != 2'b00) begin
            exp_fault = 1'b1;
            exp_fcode = FAULT_IF_MISALIGNED;
            exp_faddr = gold_pc;
            exp_finsn = 32'h0;
          end else begin
            insn  = gold_irom[gold_pc[14:2]];
            exp_finsn = insn;
            opc   = insn[6:0];
            f3    = insn[14:12];
            f7    = insn[31:25];
            rd    = insn[11:7];
            rs1   = insn[19:15];
            rs2   = insn[24:20];
            v1    = (rs1 == 5'd0) ? 32'h0 : gold_rf[rs1];
            v2    = (rs2 == 5'd0) ? 32'h0 : gold_rf[rs2];

            imm_i = {{20{insn[31]}}, insn[31:20]};
            imm_s = {{20{insn[31]}}, insn[31:25], insn[11:7]};
            imm_b = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
            imm_u = {insn[31:12], 12'h0};
            imm_j = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};

            case (opc)
              7'b0110111: begin // LUI
                wb_en = 1'b1; wb_val = imm_u;
              end
              7'b0010111: begin // AUIPC
                wb_en = 1'b1; wb_val = gold_pc + imm_u;
              end
              7'b1101111: begin // JAL
                wb_en = 1'b1; wb_val = gold_pc + 32'd4;
                next_pc = gold_pc + imm_j;
              end
              7'b1100111: begin // JALR
                if (f3 != 3'b000) begin
                  exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN;
                end else begin
                  wb_en = 1'b1; wb_val = gold_pc + 32'd4;
                  next_pc = (v1 + imm_i) & ~32'h1;
                end
              end
              7'b1100011: begin // BRANCH
                logic take;
                take = 1'b0;
                case (f3)
                  3'b000: take = (v1 == v2);
                  3'b001: take = (v1 != v2);
                  3'b100: take = ($signed(v1) < $signed(v2));
                  3'b101: take = ($signed(v1) >= $signed(v2));
                  3'b110: take = (v1 < v2);
                  3'b111: take = (v1 >= v2);
                  default: begin
                    exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN;
                  end
                endcase
                if (!exp_fault && take) next_pc = gold_pc + imm_b;
              end
              7'b0010011: begin // OP-IMM
                wb_en = 1'b1;
                case (f3)
                  3'b000: wb_val = v1 + imm_i;
                  3'b010: wb_val = ($signed(v1) < $signed(imm_i)) ? 32'd1 : 32'd0;
                  3'b011: wb_val = (v1 < imm_i) ? 32'd1 : 32'd0;
                  3'b100: wb_val = v1 ^ imm_i;
                  3'b110: wb_val = v1 | imm_i;
                  3'b111: wb_val = v1 & imm_i;
                  3'b001: begin
                    if (f7 == 7'b0000000) wb_val = v1 << insn[24:20];
                    else begin wb_en = 1'b0; exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN; end
                  end
                  3'b101: begin
                    if (f7 == 7'b0000000) wb_val = v1 >> insn[24:20];
                    else if (f7 == 7'b0100000) wb_val = $unsigned($signed(v1) >>> insn[24:20]);
                    else begin wb_en = 1'b0; exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN; end
                  end
                  default: begin wb_en = 1'b0; exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN; end
                endcase
              end
              7'b0110011: begin // OP-REG
                wb_en = 1'b1;
                case ({f7, f3})
                  10'b0000000_000: wb_val = v1 + v2;
                  10'b0100000_000: wb_val = v1 - v2;
                  10'b0000000_001: wb_val = v1 << v2[4:0];
                  10'b0000000_010: wb_val = ($signed(v1) < $signed(v2)) ? 32'd1 : 32'd0;
                  10'b0000000_011: wb_val = (v1 < v2) ? 32'd1 : 32'd0;
                  10'b0000000_100: wb_val = v1 ^ v2;
                  10'b0000000_101: wb_val = v1 >> v2[4:0];
                  10'b0100000_101: wb_val = $unsigned($signed(v1) >>> v2[4:0]);
                  10'b0000000_110: wb_val = v1 | v2;
                  10'b0000000_111: wb_val = v1 & v2;
                  default: begin wb_en = 1'b0; exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN; end
                endcase
              end
              7'b0001111: begin // MISC-MEM (FENCE only)
                if (f3 != 3'b000) begin
                  exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN;
                end
              end
              7'b1110011: begin // SYSTEM (ECALL / EBREAK only)
                if (insn == 32'h0000_0073) begin
                  exp_fault = 1'b1; exp_fcode = FAULT_ECALL;
                end else if (insn == 32'h0010_0073) begin
                  exp_fault = 1'b1; exp_fcode = FAULT_EBREAK;
                end else begin
                  exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN;
                end
              end
              7'b0000011, 7'b0100011: begin // LOAD / STORE
                logic        is_store;
                logic [31:0] ea;
                logic        valid_f3;
                is_store = (opc == 7'b0100011);
                ea = v1 + (is_store ? imm_s : imm_i);
                valid_f3 = is_store ? (f3 inside {3'b000, 3'b001, 3'b010})
                                    : (f3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101});
                if (!valid_f3) begin
                  exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN;
                end else if (!is_in_irom(ea) && !is_in_dram(ea) && !is_in_apb_pop(ea)) begin
                  exp_fault = 1'b1; exp_fcode = FAULT_DATA_UNMAPPED; exp_faddr = ea;
                end else if (is_in_irom(ea) && is_store) begin
                  exp_fault = 1'b1; exp_fcode = FAULT_DATA_RO_WRITE; exp_faddr = ea;
                end else if (is_in_apb_pop(ea) && (f3[1:0] != 2'b10)) begin
                  exp_fault = 1'b1; exp_fcode = FAULT_DATA_SIZE_UNSUP; exp_faddr = ea;
                end else if ((f3[1:0] == 2'b01 && ea[0] != 1'b0) ||
                             (f3[1:0] == 2'b10 && ea[1:0] != 2'b00)) begin
                  exp_fault = 1'b1; exp_fcode = FAULT_DATA_MISALIGNED; exp_faddr = ea;
                end else if (is_in_apb_pop(ea)) begin
                  // Must have completed via APB3
                  if (!apb_done_eff || apb_cnt_eff != 1) begin
                    fail_msg($sformatf("APB transfer count=%0d (expected 1) at PC=%h",
                                       apb_cnt_eff, gold_pc));
                  end
                  if (apb_slverr_eff) begin
                    exp_fault = 1'b1; exp_fcode = FAULT_APB_SLVERR; exp_faddr = ea;
                  end else if (!is_store) begin
                    wb_en = 1'b1; wb_val = apb_rdata_eff;
                  end
                end else begin
                  // Valid IROM Port B load or DRAM load/store
                  logic [31:0] rword;
                  rword = is_in_irom(ea) ? gold_irom[ea[14:2]] : gold_dram[ea[14:2]];
                  if (!is_store) begin
                    wb_en = 1'b1;
                    case (f3)
                      3'b000: begin // LB
                        logic [7:0] b;
                        b = rword[8*ea[1:0] +: 8];
                        wb_val = {{24{b[7]}}, b};
                      end
                      3'b100: begin // LBU
                        wb_val = {24'h0, rword[8*ea[1:0] +: 8]};
                      end
                      3'b001: begin // LH
                        logic [15:0] h;
                        h = ea[1] ? rword[31:16] : rword[15:0];
                        wb_val = {{16{h[15]}}, h};
                      end
                      3'b101: begin // LHU
                        wb_val = {16'h0, ea[1] ? rword[31:16] : rword[15:0]};
                      end
                      3'b010: wb_val = rword;
                      default: wb_val = 32'h0;
                    endcase
                  end else begin
                    // DRAM store
                    logic [31:0] cur_w;
                    cur_w = gold_dram[ea[14:2]];
                    case (f3)
                      3'b000: cur_w[8*ea[1:0] +: 8] = v2[7:0];
                      3'b001: begin
                        if (ea[1]) cur_w[31:16] = v2[15:0];
                        else       cur_w[15:0]  = v2[15:0];
                      end
                      3'b010: cur_w = v2;
                      default: ;
                    endcase
                    gold_dram[ea[14:2]] <= cur_w;
                  end
                end
              end
              default: begin
                exp_fault = 1'b1; exp_fcode = FAULT_ILLEGAL_INSN;
              end
            endcase
          end

          // Compare DUT fault / writeback against Golden ISS
          if (exp_fault) begin
            if (dut_rf_we) begin
              fail_msg($sformatf("rf_we asserted on faulting instruction PC=%h", gold_pc));
            end
            // Note: fault_valid registers on this posedge clk -> check next cycle in halted branch
            gold_halted     <= 1'b1;
            gold_fault_code <= exp_fcode;
            gold_fault_pc   <= gold_pc;
            gold_fault_addr <= exp_faddr;
            gold_fault_insn <= exp_finsn;
          end else begin
            if (dut_fault_valid) begin
              fail_msg($sformatf("Unexpected DUT fault code=%h at PC=%h", dut_fault_code, gold_pc));
            end
            if (wb_en && rd != 5'd0) begin
              gold_rf[rd] <= wb_val;
              if (dut_rf_we && (dut_rf_waddr != rd || dut_rf_wdata != wb_val)) begin
                fail_msg($sformatf("RF write mismatch at PC=%h: DUT x%0d=%h GOLD x%0d=%h",
                                   gold_pc, dut_rf_waddr, dut_rf_wdata, rd, wb_val));
              end
            end else if (dut_rf_we) begin
              fail_msg($sformatf("Unexpected rf_we x%0d=%h at PC=%h", dut_rf_waddr, dut_rf_wdata, gold_pc));
            end
            gold_pc <= next_pc;
            sb_retire_count <= sb_retire_count + 1;
          end

          apb_latched_done       <= 1'b0;
          apb_xfer_cnt_this_insn <= 0;
        end
      end
    end
  end

endmodule
