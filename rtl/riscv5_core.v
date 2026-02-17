module riscv5_core #(
    parameter RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst,

    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    output wire        dmem_we,
    output wire [3:0]  dmem_wstrb,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata
);

    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OPIMM  = 7'b0010011;
    localparam OP_OP     = 7'b0110011;

    // ---------------------- IF ----------------------
    reg [31:0] pc;
    assign imem_addr = pc;

    wire [31:0] if_instr = imem_rdata;

    // ---------------------- ID ----------------------
    reg [31:0] id_pc;
    reg [31:0] id_instr;

    wire [6:0] id_opcode = id_instr[6:0];
    wire [4:0] id_rd     = id_instr[11:7];
    wire [2:0] id_funct3 = id_instr[14:12];
    wire [4:0] id_rs1    = id_instr[19:15];
    wire [4:0] id_rs2    = id_instr[24:20];
    wire [6:0] id_funct7 = id_instr[31:25];

    wire [31:0] imm_i = {{20{id_instr[31]}}, id_instr[31:20]};
    wire [31:0] imm_s = {{20{id_instr[31]}}, id_instr[31:25], id_instr[11:7]};
    wire [31:0] imm_b = {{19{id_instr[31]}}, id_instr[31], id_instr[7], id_instr[30:25], id_instr[11:8], 1'b0};
    wire [31:0] imm_u = {id_instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{id_instr[31]}}, id_instr[31], id_instr[19:12], id_instr[20], id_instr[30:21], 1'b0};

    reg [31:0] regs [0:31];
    integer i;

    wire [31:0] rs1_val = (id_rs1 == 0) ? 32'b0 : regs[id_rs1];
    wire [31:0] rs2_val = (id_rs2 == 0) ? 32'b0 : regs[id_rs2];

    // ---------------------- EX ----------------------
    reg [31:0] ex_pc;
    reg [6:0]  ex_opcode;
    reg [2:0]  ex_funct3;
    reg [6:0]  ex_funct7;
    reg [4:0]  ex_rd;
    reg [31:0] ex_rs1;
    reg [31:0] ex_rs2;
    reg [31:0] ex_imm;

    reg        ex_regwrite;
    reg        ex_memread;
    reg        ex_memwrite;
    reg        ex_memtoreg;
    reg        ex_alusrc;
    reg [2:0]  ex_aluop;
    reg        ex_branch;
    reg        ex_jump;

    reg [31:0] ex_alu_result;
    reg [31:0] ex_store_data;
    reg        ex_take_branch;
    reg [31:0] ex_next_pc;

    // ---------------------- MEM ----------------------
    reg [4:0]  mem_rd;
    reg [31:0] mem_alu_result;
    reg [31:0] mem_store_data;
    reg        mem_regwrite;
    reg        mem_memread;
    reg        mem_memwrite;
    reg        mem_memtoreg;

    // ---------------------- WB ----------------------
    reg [4:0]  wb_rd;
    reg [31:0] wb_result;
    reg        wb_regwrite;

    assign dmem_we    = mem_memwrite;
    assign dmem_wstrb = mem_memwrite ? 4'b1111 : 4'b0000;
    assign dmem_addr  = mem_alu_result;
    assign dmem_wdata = mem_store_data;

    wire stall = 1'b0; // Hook for future hazard unit.

    always @(*) begin
        ex_alu_result = 32'b0;
        ex_take_branch = 1'b0;
        ex_next_pc = ex_pc + 4;
        ex_store_data = ex_rs2;

        case (ex_opcode)
            OP_LUI:   ex_alu_result = ex_imm;
            OP_AUIPC: ex_alu_result = ex_pc + ex_imm;
            OP_OPIMM: begin
                case (ex_funct3)
                    3'b000: ex_alu_result = ex_rs1 + ex_imm; // ADDI
                    3'b010: ex_alu_result = ($signed(ex_rs1) < $signed(ex_imm)) ? 32'd1 : 32'd0; // SLTI
                    3'b011: ex_alu_result = (ex_rs1 < ex_imm) ? 32'd1 : 32'd0; // SLTIU
                    3'b100: ex_alu_result = ex_rs1 ^ ex_imm; // XORI
                    3'b110: ex_alu_result = ex_rs1 | ex_imm; // ORI
                    3'b111: ex_alu_result = ex_rs1 & ex_imm; // ANDI
                    3'b001: ex_alu_result = ex_rs1 << ex_imm[4:0]; // SLLI
                    3'b101: ex_alu_result = ex_funct7[5] ? ($signed(ex_rs1) >>> ex_imm[4:0]) : (ex_rs1 >> ex_imm[4:0]);
                endcase
            end
            OP_OP: begin
                case ({ex_funct7, ex_funct3})
                    {7'b0000000,3'b000}: ex_alu_result = ex_rs1 + ex_rs2;
                    {7'b0100000,3'b000}: ex_alu_result = ex_rs1 - ex_rs2;
                    {7'b0000000,3'b111}: ex_alu_result = ex_rs1 & ex_rs2;
                    {7'b0000000,3'b110}: ex_alu_result = ex_rs1 | ex_rs2;
                    {7'b0000000,3'b100}: ex_alu_result = ex_rs1 ^ ex_rs2;
                    {7'b0000000,3'b001}: ex_alu_result = ex_rs1 << ex_rs2[4:0];
                    {7'b0000000,3'b101}: ex_alu_result = ex_rs1 >> ex_rs2[4:0];
                    {7'b0100000,3'b101}: ex_alu_result = $signed(ex_rs1) >>> ex_rs2[4:0];
                    {7'b0000000,3'b010}: ex_alu_result = ($signed(ex_rs1) < $signed(ex_rs2)) ? 32'd1 : 32'd0;
                    {7'b0000000,3'b011}: ex_alu_result = (ex_rs1 < ex_rs2) ? 32'd1 : 32'd0;
                    default: ex_alu_result = 32'b0;
                endcase
            end
            OP_LOAD,
            OP_STORE,
            OP_JALR: ex_alu_result = ex_rs1 + ex_imm;
            OP_JAL: begin
                ex_alu_result = ex_pc + 4;
                ex_take_branch = 1'b1;
                ex_next_pc = ex_pc + ex_imm;
            end
            OP_BRANCH: begin
                case (ex_funct3)
                    3'b000: ex_take_branch = (ex_rs1 == ex_rs2);
                    3'b001: ex_take_branch = (ex_rs1 != ex_rs2);
                    3'b100: ex_take_branch = ($signed(ex_rs1) < $signed(ex_rs2));
                    3'b101: ex_take_branch = ($signed(ex_rs1) >= $signed(ex_rs2));
                    3'b110: ex_take_branch = (ex_rs1 < ex_rs2);
                    3'b111: ex_take_branch = (ex_rs1 >= ex_rs2);
                    default: ex_take_branch = 1'b0;
                endcase
                ex_next_pc = ex_pc + ex_imm;
            end
            default: ex_alu_result = 32'b0;
        endcase

        if (ex_opcode == OP_JALR) begin
            ex_take_branch = 1'b1;
            ex_next_pc = (ex_rs1 + ex_imm) & ~32'b1;
            ex_alu_result = ex_pc + 4;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= RESET_PC;
            id_pc <= 0;
            id_instr <= 32'h0000_0013; // NOP
            ex_pc <= 0;
            ex_opcode <= OP_OPIMM;
            ex_funct3 <= 3'b000;
            ex_funct7 <= 7'b0000000;
            ex_rd <= 0;
            ex_rs1 <= 0;
            ex_rs2 <= 0;
            ex_imm <= 0;
            ex_regwrite <= 0;
            ex_memread <= 0;
            ex_memwrite <= 0;
            ex_memtoreg <= 0;
            ex_alusrc <= 0;
            ex_aluop <= 0;
            ex_branch <= 0;
            ex_jump <= 0;

            mem_rd <= 0;
            mem_alu_result <= 0;
            mem_store_data <= 0;
            mem_regwrite <= 0;
            mem_memread <= 0;
            mem_memwrite <= 0;
            mem_memtoreg <= 0;

            wb_rd <= 0;
            wb_result <= 0;
            wb_regwrite <= 0;

            for (i = 0; i < 32; i = i + 1) regs[i] <= 32'b0;
        end else begin
            // WB
            if (wb_regwrite && wb_rd != 0) begin
                regs[wb_rd] <= wb_result;
            end

            // MEM -> WB
            wb_rd <= mem_rd;
            wb_regwrite <= mem_regwrite;
            wb_result <= mem_memtoreg ? dmem_rdata : mem_alu_result;

            // EX -> MEM
            mem_rd <= ex_rd;
            mem_alu_result <= ex_alu_result;
            mem_store_data <= ex_store_data;
            mem_regwrite <= ex_regwrite;
            mem_memread <= ex_memread;
            mem_memwrite <= ex_memwrite;
            mem_memtoreg <= ex_memtoreg;

            // ID -> EX
            ex_pc <= id_pc;
            ex_opcode <= id_opcode;
            ex_funct3 <= id_funct3;
            ex_funct7 <= id_funct7;
            ex_rd <= id_rd;
            ex_rs1 <= rs1_val;
            ex_rs2 <= rs2_val;
            ex_imm <= (id_opcode == OP_STORE)  ? imm_s :
                      (id_opcode == OP_BRANCH) ? imm_b :
                      (id_opcode == OP_LUI || id_opcode == OP_AUIPC) ? imm_u :
                      (id_opcode == OP_JAL) ? imm_j : imm_i;

            ex_regwrite <= (id_opcode == OP_OPIMM) || (id_opcode == OP_OP) ||
                           (id_opcode == OP_LUI) || (id_opcode == OP_AUIPC) ||
                           (id_opcode == OP_JAL) || (id_opcode == OP_JALR) ||
                           (id_opcode == OP_LOAD);
            ex_memread  <= (id_opcode == OP_LOAD);
            ex_memwrite <= (id_opcode == OP_STORE);
            ex_memtoreg <= (id_opcode == OP_LOAD);
            ex_alusrc   <= (id_opcode == OP_OPIMM) || (id_opcode == OP_LOAD) ||
                           (id_opcode == OP_STORE) || (id_opcode == OP_JALR);
            ex_aluop    <= 3'b000;
            ex_branch   <= (id_opcode == OP_BRANCH);
            ex_jump     <= (id_opcode == OP_JAL) || (id_opcode == OP_JALR);

            // IF -> ID and PC update
            if (!stall) begin
                id_pc <= pc;
                id_instr <= if_instr;
                if (ex_take_branch)
                    pc <= ex_next_pc;
                else
                    pc <= pc + 4;
            end

            regs[0] <= 32'b0;
        end
    end
endmodule
