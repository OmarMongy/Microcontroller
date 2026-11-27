// Single-Cycle RV32I CPU Core with Stall/Hold and Sticky Fault-and-Halt
// Contracts: CON-ADDR-001 v1.1, CON-MEM-001 v1.1, CON-APB3-001 v1.1,
//            CON-FLT-RST-001 v1.1, CON-TOP-001 v1.1

module rv32i_cpu (
    input  logic        clk,
    input  logic        sys_rst_n,

    // Instruction ROM Port A (0-cycle combinational IF)
    output logic        irom_en,
    output logic [14:0] irom_addr,
    input  logic [31:0] irom_rdata,

    // Data Bus Interface (via data_bus_decode)
    output logic        dmem_req,
    output logic        dmem_we,
    output logic [1:0]  dmem_size,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_stall,
    input  logic        dmem_fault_valid,
    input  logic [3:0]  dmem_fault_code,

    // Sticky Fault & Halt Observability Outputs (CON-FLT-RST-001 Section 1.3)
    output logic        fault_valid,
    output logic [3:0]  fault_code,
    output logic [31:0] fault_pc,
    output logic [31:0] fault_addr,
    output logic [31:0] fault_insn
);

    // Opcodes (RV32I base integer ISA)
    localparam logic [6:0] OPC_LUI      = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC    = 7'b0010111;
    localparam logic [6:0] OPC_JAL      = 7'b1101111;
    localparam logic [6:0] OPC_JALR     = 7'b1100111;
    localparam logic [6:0] OPC_BRANCH   = 7'b1100011;
    localparam logic [6:0] OPC_LOAD     = 7'b0000011;
    localparam logic [6:0] OPC_STORE    = 7'b0100011;
    localparam logic [6:0] OPC_OP_IMM   = 7'b0010011;
    localparam logic [6:0] OPC_OP       = 7'b0110011;
    localparam logic [6:0] OPC_MISC_MEM = 7'b0001111;
    localparam logic [6:0] OPC_SYSTEM   = 7'b1110011;

    // Architectural state
    logic [31:0] pc;
    logic [31:0] regfile [1:31];

    // Fetch stage
    logic        if_in_irom;
    logic        if_misaligned;
    logic        if_fault;
    logic [31:0] insn;

    // Instruction fields & immediates
    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [2:0]  funct3;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [6:0]  funct7;

    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;

    // Register file read values
    logic [31:0] rs1_val;
    logic [31:0] rs2_val;

    // Decode & execution signals
    logic        is_ecall;
    logic        is_ebreak;
    logic        illegal_insn;
    logic        is_load;
    logic        is_store;
    logic        branch_taken;
    logic        rf_we_dec;
    logic [31:0] alu_result;
    logic [31:0] load_rdata;
    logic [31:0] rf_wdata;
    logic [31:0] pc_plus_4;
    logic [31:0] next_pc;

    logic [7:0]  load_byte;
    logic [15:0] load_half;

    // Fault evaluation
    logic        fault_detect;
    logic [3:0]  fault_code_nxt;
    logic [31:0] fault_addr_nxt;
    logic [31:0] fault_insn_nxt;

    // -------------------------------------------------------------------------
    // Instruction Fetch (IF)
    // -------------------------------------------------------------------------
    assign if_in_irom    = (pc[31:15] == soc_pkg::IROM_BASE_PREFIX);
    assign if_misaligned = (pc[1:0] != 2'b00);
    assign if_fault      = !if_in_irom || if_misaligned;

    assign irom_en   = sys_rst_n && !fault_valid && !if_fault;
    assign irom_addr = pc[14:0];
    assign insn      = irom_rdata;

    // -------------------------------------------------------------------------
    // Decode & Register File Read
    // -------------------------------------------------------------------------
    assign opcode = insn[6:0];
    assign rd     = insn[11:7];
    assign funct3 = insn[14:12];
    assign rs1    = insn[19:15];
    assign rs2    = insn[24:20];
    assign funct7 = insn[31:25];

    assign imm_i = {{20{insn[31]}}, insn[31:20]};
    assign imm_s = {{20{insn[31]}}, insn[31:25], insn[11:7]};
    assign imm_b = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
    assign imm_u = {insn[31:12], 12'h000};
    assign imm_j = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};

    assign rs1_val = (rs1 == 5'd0) ? 32'h0000_0000 : regfile[rs1];
    assign rs2_val = (rs2 == 5'd0) ? 32'h0000_0000 : regfile[rs2];

    assign pc_plus_4 = pc + 32'd4;

    // Load byte/halfword extraction (little-endian)
    always_comb begin
        case (dmem_addr[1:0])
            2'b00: load_byte = dmem_rdata[7:0];
            2'b01: load_byte = dmem_rdata[15:8];
            2'b10: load_byte = dmem_rdata[23:16];
            2'b11: load_byte = dmem_rdata[31:24];
        endcase
        load_half = dmem_addr[1] ? dmem_rdata[31:16] : dmem_rdata[15:0];
    end

    // Main RV32I Decode, ALU, Branch, Load/Store Control
    always_comb begin
        is_ecall     = 1'b0;
        is_ebreak    = 1'b0;
        illegal_insn = 1'b0;
        is_load      = 1'b0;
        is_store     = 1'b0;
        dmem_size    = soc_pkg::DMEM_SIZE_WORD;
        dmem_addr    = 32'h0000_0000;
        branch_taken = 1'b0;
        rf_we_dec    = 1'b0;
        alu_result   = 32'h0000_0000;
        load_rdata   = dmem_rdata;
        rf_wdata     = 32'h0000_0000;
        next_pc      = pc_plus_4;

        case (opcode)
            OPC_LUI: begin
                rf_we_dec = 1'b1;
                rf_wdata  = imm_u;
            end

            OPC_AUIPC: begin
                rf_we_dec = 1'b1;
                rf_wdata  = pc + imm_u;
            end

            OPC_JAL: begin
                rf_we_dec = 1'b1;
                rf_wdata  = pc_plus_4;
                next_pc   = pc + imm_j;
            end

            OPC_JALR: begin
                if (funct3 == 3'b000) begin
                    rf_we_dec = 1'b1;
                    rf_wdata  = pc_plus_4;
                    next_pc   = (rs1_val + imm_i) & 32'hFFFF_FFFE;
                end else begin
                    illegal_insn = 1'b1;
                end
            end

            OPC_BRANCH: begin
                case (funct3)
                    3'b000: branch_taken = (rs1_val == rs2_val);                          // BEQ
                    3'b001: branch_taken = (rs1_val != rs2_val);                          // BNE
                    3'b100: branch_taken = ($signed(rs1_val) < $signed(rs2_val));         // BLT
                    3'b101: branch_taken = ($signed(rs1_val) >= $signed(rs2_val));        // BGE
                    3'b110: branch_taken = (rs1_val < rs2_val);                           // BLTU
                    3'b111: branch_taken = (rs1_val >= rs2_val);                          // BGEU
                    default: illegal_insn = 1'b1;
                endcase
                if (!illegal_insn && branch_taken) begin
                    next_pc = pc + imm_b;
                end
            end

            OPC_LOAD: begin
                is_load   = 1'b1;
                dmem_addr = rs1_val + imm_i;
                rf_we_dec = 1'b1;
                case (funct3)
                    3'b000: begin // LB
                        dmem_size  = soc_pkg::DMEM_SIZE_BYTE;
                        load_rdata = {{24{load_byte[7]}}, load_byte};
                    end
                    3'b001: begin // LH
                        dmem_size  = soc_pkg::DMEM_SIZE_HALF;
                        load_rdata = {{16{load_half[15]}}, load_half};
                    end
                    3'b010: begin // LW
                        dmem_size  = soc_pkg::DMEM_SIZE_WORD;
                        load_rdata = dmem_rdata;
                    end
                    3'b100: begin // LBU
                        dmem_size  = soc_pkg::DMEM_SIZE_BYTE;
                        load_rdata = {24'h0, load_byte};
                    end
                    3'b101: begin // LHU
                        dmem_size  = soc_pkg::DMEM_SIZE_HALF;
                        load_rdata = {16'h0, load_half};
                    end
                    default: begin
                        illegal_insn = 1'b1;
                        is_load      = 1'b0;
                        rf_we_dec    = 1'b0;
                    end
                endcase
                rf_wdata = load_rdata;
            end

            OPC_STORE: begin
                is_store  = 1'b1;
                dmem_addr = rs1_val + imm_s;
                case (funct3)
                    3'b000: dmem_size = soc_pkg::DMEM_SIZE_BYTE; // SB
                    3'b001: dmem_size = soc_pkg::DMEM_SIZE_HALF; // SH
                    3'b010: dmem_size = soc_pkg::DMEM_SIZE_WORD; // SW
                    default: begin
                        illegal_insn = 1'b1;
                        is_store     = 1'b0;
                    end
                endcase
            end

            OPC_OP_IMM: begin
                rf_we_dec = 1'b1;
                case (funct3)
                    3'b000: alu_result = rs1_val + imm_i;                                          // ADDI
                    3'b010: alu_result = ($signed(rs1_val) < $signed(imm_i)) ? 32'd1 : 32'd0;      // SLTI
                    3'b011: alu_result = (rs1_val < imm_i) ? 32'd1 : 32'd0;                        // SLTIU
                    3'b100: alu_result = rs1_val ^ imm_i;                                          // XORI
                    3'b110: alu_result = rs1_val | imm_i;                                          // ORI
                    3'b111: alu_result = rs1_val & imm_i;                                          // ANDI
                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            alu_result = rs1_val << rs2;                                           // SLLI
                        end else begin
                            illegal_insn = 1'b1;
                            rf_we_dec    = 1'b0;
                        end
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            alu_result = rs1_val >> rs2;                                           // SRLI
                        end else if (funct7 == 7'b0100000) begin
                            alu_result = $unsigned($signed(rs1_val) >>> rs2);                      // SRAI
                        end else begin
                            illegal_insn = 1'b1;
                            rf_we_dec    = 1'b0;
                        end
                    end
                    default: begin
                        illegal_insn = 1'b1;
                        rf_we_dec    = 1'b0;
                    end
                endcase
                rf_wdata = alu_result;
            end

            OPC_OP: begin
                rf_we_dec = 1'b1;
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: alu_result = rs1_val + rs2_val;                                    // ADD
                    {7'b0100000, 3'b000}: alu_result = rs1_val - rs2_val;                                    // SUB
                    {7'b0000000, 3'b001}: alu_result = rs1_val << rs2_val[4:0];                              // SLL
                    {7'b0000000, 3'b010}: alu_result = ($signed(rs1_val) < $signed(rs2_val)) ? 32'd1 : 32'd0;// SLT
                    {7'b0000000, 3'b011}: alu_result = (rs1_val < rs2_val) ? 32'd1 : 32'd0;                  // SLTU
                    {7'b0000000, 3'b100}: alu_result = rs1_val ^ rs2_val;                                    // XOR
                    {7'b0000000, 3'b101}: alu_result = rs1_val >> rs2_val[4:0];                              // SRL
                    {7'b0100000, 3'b101}: alu_result = $unsigned($signed(rs1_val) >>> rs2_val[4:0]);         // SRA
                    {7'b0000000, 3'b110}: alu_result = rs1_val | rs2_val;                                    // OR
                    {7'b0000000, 3'b111}: alu_result = rs1_val & rs2_val;                                    // AND
                    default: begin
                        illegal_insn = 1'b1;
                        rf_we_dec    = 1'b0;
                    end
                endcase
                rf_wdata = alu_result;
            end

            OPC_MISC_MEM: begin
                if (funct3 == 3'b000) begin
                    // FENCE: single-cycle NOP (prior memory ops already retired)
                    rf_we_dec = 1'b0;
                end else begin
                    illegal_insn = 1'b1;
                end
            end

            OPC_SYSTEM: begin
                if (insn == 32'h0000_0073) begin
                    is_ecall = 1'b1;
                end else if (insn == 32'h0010_0073) begin
                    is_ebreak = 1'b1;
                end else begin
                    illegal_insn = 1'b1;
                end
            end

            default: begin
                illegal_insn = 1'b1;
            end
        endcase
    end

    // Data request outputs (gated by !if_fault, !decode_fault, !fault_valid, sys_rst_n)
    assign dmem_req   = sys_rst_n && !fault_valid && !if_fault
                      && !is_ecall && !is_ebreak && !illegal_insn
                      && (is_load || is_store);
    assign dmem_we    = is_store;
    assign dmem_wdata = rs2_val;

    // -------------------------------------------------------------------------
    // Fault Priority Evaluation (CON-FLT-RST-001 Section 1.2)
    // -------------------------------------------------------------------------
    always_comb begin
        fault_detect   = 1'b0;
        fault_code_nxt = soc_pkg::FAULT_NONE;
        fault_addr_nxt = 32'h0000_0000;
        fault_insn_nxt = 32'h0000_0000;

        if (sys_rst_n && !fault_valid) begin
            if (!if_in_irom) begin
                fault_detect   = 1'b1;
                fault_code_nxt = soc_pkg::FAULT_IF_UNMAPPED;
                fault_addr_nxt = pc;
                fault_insn_nxt = 32'h0000_0000;
            end else if (if_misaligned) begin
                fault_detect   = 1'b1;
                fault_code_nxt = soc_pkg::FAULT_IF_MISALIGNED;
                fault_addr_nxt = pc;
                fault_insn_nxt = 32'h0000_0000;
            end else if (is_ecall) begin
                fault_detect   = 1'b1;
                fault_code_nxt = soc_pkg::FAULT_ECALL;
                fault_addr_nxt = 32'h0000_0000;
                fault_insn_nxt = insn;
            end else if (is_ebreak) begin
                fault_detect   = 1'b1;
                fault_code_nxt = soc_pkg::FAULT_EBREAK;
                fault_addr_nxt = 32'h0000_0000;
                fault_insn_nxt = insn;
            end else if (illegal_insn) begin
                fault_detect   = 1'b1;
                fault_code_nxt = soc_pkg::FAULT_ILLEGAL_INSN;
                fault_addr_nxt = 32'h0000_0000;
                fault_insn_nxt = insn;
            end else if (dmem_fault_valid) begin
                fault_detect   = 1'b1;
                fault_code_nxt = dmem_fault_code;
                fault_addr_nxt = dmem_addr;
                fault_insn_nxt = insn;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Architectural State Commit & Sticky Fault Capture
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            pc          <= 32'h0000_0000;
            fault_valid <= 1'b0;
            fault_code  <= soc_pkg::FAULT_NONE;
            fault_pc    <= 32'h0000_0000;
            fault_addr  <= 32'h0000_0000;
            fault_insn  <= 32'h0000_0000;
            for (int i = 1; i < 32; i++) begin
                regfile[i] <= 32'h0000_0000;
            end
        end else if (!fault_valid) begin
            if (fault_detect) begin
                fault_valid <= 1'b1;
                fault_code  <= fault_code_nxt;
                fault_pc    <= pc;
                fault_addr  <= fault_addr_nxt;
                fault_insn  <= fault_insn_nxt;
            end else if (!dmem_stall) begin
                pc <= next_pc;
                if (rf_we_dec && (rd != 5'd0)) begin
                    regfile[rd] <= rf_wdata;
                end
            end
        end
    end

endmodule
