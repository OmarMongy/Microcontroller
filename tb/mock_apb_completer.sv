// Parameterized APB3 Mock Completer (ARM IHI 0024E Issue B / CON-APB3-001 v1.1)
// Used by tb_core_bus to verify APB3 wait states, PSLVERR, and single-commit
// behavior at the APB3 bridge boundary independently of peripheral RTL.

module mock_apb_completer #(
  parameter logic [19:0] SLOT_PREFIX = 20'h4000_0
) (
  input  logic        PCLK,
  input  logic        PRESETn,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [31:0] PADDR,
  input  logic [31:0] PWDATA,
  output logic        PREADY,
  output logic [31:0] PRDATA,
  output logic        PSLVERR,

  // Testbench Control & Monitoring
  input  int unsigned cfg_wait_cycles,
  input  logic        cfg_slverr_en,
  input  logic [11:0] cfg_slverr_off,
  input  logic        cfg_glitch_slverr_on_wait,
  output int unsigned mon_xfer_count,
  output logic [31:0] mon_last_addr,
  output logic [31:0] mon_last_wdata,
  output logic        mon_last_write,
  output logic        mon_proto_err
);

  logic [31:0] mem [0:1023];
  int unsigned wait_cnt;
  logic        in_access_q;
  logic [31:0] latched_addr;
  logic        latched_write;
  logic [31:0] latched_wdata;

  // Combinational APB3 response driven during ACCESS
  logic ready_now;
  assign ready_now = (wait_cnt >= cfg_wait_cycles);

  always_comb begin
    PREADY  = 1'b1;
    PRDATA  = 32'h0000_0000;
    PSLVERR = 1'b0;

    if (PSEL && PENABLE) begin
      PREADY = ready_now;
      if (!ready_now) begin
        PSLVERR = cfg_glitch_slverr_on_wait;
      end else begin
        PSLVERR = cfg_slverr_en && (PADDR[11:0] == cfg_slverr_off);
        if (!PWRITE && !PSLVERR) begin
          PRDATA = mem[PADDR[11:2]];
        end
      end
    end
  end

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      wait_cnt       <= 0;
      in_access_q    <= 1'b0;
      latched_addr   <= 32'h0;
      latched_write  <= 1'b0;
      latched_wdata  <= 32'h0;
      mon_xfer_count <= 0;
      mon_last_addr  <= 32'h0;
      mon_last_wdata <= 32'h0;
      mon_last_write <= 1'b0;
      mon_proto_err  <= 1'b0;
      for (int i = 0; i < 1024; i++) begin
        mem[i] <= 32'h0000_0000;
      end
    end else begin
      if (PSEL && !PENABLE) begin
        // SETUP phase: capture controls to check stability across ACCESS
        wait_cnt      <= 0;
        in_access_q   <= 1'b1;
        latched_addr  <= PADDR;
        latched_write <= PWRITE;
        latched_wdata <= PWDATA;
        if (PADDR[31:12] != SLOT_PREFIX || PADDR[1:0] != 2'b00) begin
          mon_proto_err <= 1'b1;
          $display("[MOCK_APB %h] ERROR: Bad PADDR=%h in SETUP at %0t", SLOT_PREFIX, PADDR, $time);
        end
      end else if (PSEL && PENABLE) begin
        if (!in_access_q) begin
          mon_proto_err <= 1'b1;
          $display("[MOCK_APB %h] ERROR: PENABLE without SETUP at %0t", SLOT_PREFIX, $time);
        end
        if (PADDR != latched_addr || PWRITE != latched_write || (PWRITE && PWDATA != latched_wdata)) begin
          mon_proto_err <= 1'b1;
          $display("[MOCK_APB %h] ERROR: Unstable APB signals during ACCESS at %0t", SLOT_PREFIX, $time);
        end

        if (!ready_now) begin
          wait_cnt <= wait_cnt + 1;
        end else begin
          in_access_q    <= 1'b0;
          wait_cnt       <= 0;
          mon_xfer_count <= mon_xfer_count + 1;
          mon_last_addr  <= PADDR;
          mon_last_wdata <= PWDATA;
          mon_last_write <= PWRITE;
          if (PWRITE && !(cfg_slverr_en && PADDR[11:0] == cfg_slverr_off)) begin
            mem[PADDR[11:2]] <= PWDATA;
          end
        end
      end else begin
        if (in_access_q) begin
          mon_proto_err <= 1'b1;
          $display("[MOCK_APB %h] ERROR: PSEL dropped before PREADY completion at %0t", SLOT_PREFIX, $time);
        end
        in_access_q <= 1'b0;
        wait_cnt    <= 0;
      end
    end
  end

endmodule
