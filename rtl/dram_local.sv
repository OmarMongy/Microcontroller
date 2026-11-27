// 32 KB Local Data RAM (Option RAM-B)
// 1-cycle synchronous read, 1-cycle synchronous byte-enabled write
// No hardware reset tree on storage array (CON-MEM-001 Section 2.6)
// Contract: CON-MEM-001 v1.1 Section 2

module dram_local #(
    parameter int DEPTH      = 8192,
    parameter int ADDR_WIDTH = 15,
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  sys_rst_n,
    input  logic                  dram_req,
    input  logic                  dram_we,
    input  logic [3:0]            dram_be,
    input  logic [ADDR_WIDTH-1:0] dram_addr,
    input  logic [DATA_WIDTH-1:0] dram_wdata,
    output logic [DATA_WIDTH-1:0] dram_rdata
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    /* verilator lint_off UNUSEDSIGNAL */
    logic [1:0] unused_dram_addr_lsb;
    /* verilator lint_on UNUSEDSIGNAL */
    assign unused_dram_addr_lsb = dram_addr[1:0];

`ifndef SYNTHESIS
    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
`endif

    // Synchronous byte-enabled write (no hardware reset on 32 KB array)
    always_ff @(posedge clk) begin
        if (sys_rst_n && dram_req && dram_we) begin
            for (int b = 0; b < 4; b++) begin
                if (dram_be[b]) begin
                    mem[dram_addr[ADDR_WIDTH-1:2]][8*b +: 8] <= dram_wdata[8*b +: 8];
                end
            end
        end
    end

    // 1-cycle synchronous read (resets output register to 0)
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            dram_rdata <= {DATA_WIDTH{1'b0}};
        end else if (dram_req && !dram_we) begin
            dram_rdata <= mem[dram_addr[ADDR_WIDTH-1:2]];
        end
    end

endmodule
