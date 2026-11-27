// 32 KB Dual-Port Modified Harvard Instruction ROM
// Port A: 0-cycle combinational instruction fetch
// Port B: 1-cycle synchronous read-only data port (.rodata)
// Contract: CON-MEM-001 v1.1 Section 1

module irom_local #(
    parameter     INIT_FILE  = "",
    parameter int DEPTH      = 8192,
    parameter int ADDR_WIDTH = 15,
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  sys_rst_n,
    // Port A: Instruction Fetch (combinational)
    input  logic                  irom_en,
    input  logic [ADDR_WIDTH-1:0] irom_addr,
    output logic [DATA_WIDTH-1:0] irom_rdata,
    // Port B: Read-Only Data (1-cycle synchronous)
    input  logic                  irom_dreq,
    input  logic [ADDR_WIDTH-1:0] irom_daddr,
    output logic [DATA_WIDTH-1:0] irom_drdata
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Word index uses [14:2]; byte sub-address [1:0] handled by CPU/decoder
    /* verilator lint_off UNUSEDSIGNAL */
    logic [1:0] unused_irom_addr_lsb;
    logic [1:0] unused_irom_daddr_lsb;
    /* verilator lint_on UNUSEDSIGNAL */
    assign unused_irom_addr_lsb  = irom_addr[1:0];
    assign unused_irom_daddr_lsb = irom_daddr[1:0];

    initial begin
`ifndef SYNTHESIS
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
`endif
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Port A: 0-cycle combinational read
    always_comb begin
        if (irom_en) begin
            irom_rdata = mem[irom_addr[ADDR_WIDTH-1:2]];
        end else begin
            irom_rdata = {DATA_WIDTH{1'b0}};
        end
    end

    // Port B: 1-cycle synchronous read
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            irom_drdata <= {DATA_WIDTH{1'b0}};
        end else if (irom_dreq) begin
            irom_drdata <= mem[irom_daddr[ADDR_WIDTH-1:2]];
        end
    end

endmodule
