module soc_top (
    input  wire        clk_cpu,
    input  wire        rst
);
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;

    wire        dmem_we;
    wire [3:0]  dmem_wstrb;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;

    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];

    integer idx;
    initial begin
        for (idx = 0; idx < 1024; idx = idx + 1) begin
            imem[idx] = 32'h0000_0013; // NOP
            dmem[idx] = 32'h0000_0000;
        end

        // Demo software: increment x1 forever and store it to RAM[0].
        imem[0] = 32'h00000093; // addi x1, x0, 0
        imem[1] = 32'h00108093; // addi x1, x1, 1
        imem[2] = 32'h00000137; // lui  x2, 0x00000
        imem[3] = 32'h00112023; // sw   x1, 0(x2)
        imem[4] = 32'hff9ff06f; // jal  x0, -8
    end

    assign imem_rdata = imem[imem_addr[11:2]];

    always @(*) begin
        dmem_rdata = dmem[dmem_addr[11:2]];
    end

    always @(posedge clk_cpu) begin
        if (dmem_we && |dmem_wstrb)
            dmem[dmem_addr[11:2]] <= dmem_wdata;
    end

    riscv5_core u_cpu (
        .clk(clk_cpu),
        .rst(rst),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_we(dmem_we),
        .dmem_wstrb(dmem_wstrb),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata)
    );
endmodule
