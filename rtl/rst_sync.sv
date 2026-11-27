// 2-Stage Asynchronous-Assert, Synchronous-Deassert Reset Synchronizer
// Contract: CON-FLT-RST-001 v1.1 Section 2.1 (Option RST-A)

module rst_sync (
    input  logic clk,
    input  logic rst_n,
    output logic sys_rst_n
);

    logic sync_ff1;
    // Waive SYNCASYNCNET: sys_rst_n drives async-reset FFs across CPU/peripherals,
    // while dram_local's 32 KB storage array intentionally omits an async reset tree
    // (CON-MEM-001 Section 2.6) and gates writes synchronously with sys_rst_n.
    /* verilator lint_off SYNCASYNCNET */
    logic sync_ff2;
    /* verilator lint_on SYNCASYNCNET */

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= 1'b1;
            sync_ff2 <= sync_ff1;
        end
    end

    assign sys_rst_n = sync_ff2;

endmodule
