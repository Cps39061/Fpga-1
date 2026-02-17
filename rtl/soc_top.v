module soc_top (
    input  wire        clk_cpu,
    input  wire        clk_vga,
    input  wire        rst,
    output wire [7:0]  led,
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b
);
    localparam LED_ADDR  = 32'h4000_0000;
    localparam VGA_ADDR  = 32'h5000_0000;

    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;

    wire        dmem_we;
    wire [3:0]  dmem_wstrb;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;

    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];
    reg [7:0]  vram [0:4095];

    wire [7:0] vga_pixel;
    wire [9:0] vga_x;
    wire [9:0] vga_y;

    wire led_sel = (dmem_addr == LED_ADDR);
    wire vga_sel = (dmem_addr[31:20] == VGA_ADDR[31:20]);

    integer idx;
    initial begin
        for (idx = 0; idx < 1024; idx = idx + 1) begin
            imem[idx] = 32'h0000_0013; // NOP
            dmem[idx] = 32'h0000_0000;
        end
        for (idx = 0; idx < 4096; idx = idx + 1) begin
            vram[idx] = 8'h00;
        end

        // Demo software: increment LED and write color stripes to VRAM.
        imem[0]  = 32'h00000093; // addi x1, x0, 0
        imem[1]  = 32'h00108093; // addi x1, x1, 1
        imem[2]  = 32'h40100137; // lui  x2, 0x40100 -> 0x4010_0000 (near LED map)
        imem[3]  = 32'h00112023; // sw   x1, 0(x2)
        imem[4]  = 32'h500001b7; // lui  x3, 0x50000 (VRAM base)
        imem[5]  = 32'h0ff00213; // addi x4, x0, 255
        imem[6]  = 32'h0041a023; // sw   x4, 0(x3)
        imem[7]  = 32'hff9ff06f; // jal  x0, -8
    end

    assign imem_rdata = imem[imem_addr[11:2]];

    always @(*) begin
        if (led_sel)
            dmem_rdata = {24'h0, led};
        else if (vga_sel)
            dmem_rdata = {24'h0, vram[dmem_addr[13:2]]};
        else
            dmem_rdata = dmem[dmem_addr[11:2]];
    end

    always @(posedge clk_cpu) begin
        if (dmem_we) begin
            if (vga_sel)
                vram[dmem_addr[13:2]] <= dmem_wdata[7:0];
            else if (!led_sel)
                dmem[dmem_addr[11:2]] <= dmem_wdata;
        end
    end

    led_mmio u_led (
        .clk(clk_cpu),
        .rst(rst),
        .we(dmem_we && led_sel),
        .wstrb(dmem_wstrb),
        .wdata(dmem_wdata),
        .leds(led)
    );

    assign vga_pixel = vram[{vga_y[8:4], vga_x[8:4]}];

    vga_controller u_vga (
        .clk_25mhz(clk_vga),
        .rst(rst),
        .pixel_data(vga_pixel),
        .x(vga_x),
        .y(vga_y),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b)
    );

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
