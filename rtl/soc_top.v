module soc_top (
    input  wire        clk_cpu,
    input  wire        clk_vga,
    input  wire        rst,
    output wire [7:0]  led,
    output wire [127:0] msg_ascii,
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b
);
    localparam LED_ADDR  = 32'h4000_0000;
    localparam VGA_ADDR  = 32'h5000_0000;
    localparam MSG_ADDR  = 32'h6000_0000;

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
    wire msg_sel = (dmem_addr[31:20] == MSG_ADDR[31:20]);

    integer idx;
    initial begin
        for (idx = 0; idx < 1024; idx = idx + 1) begin
            imem[idx] = 32'h0000_0013; // NOP
            dmem[idx] = 32'h0000_0000;
        end
        for (idx = 0; idx < 4096; idx = idx + 1) begin
            vram[idx] = 8'h00;
        end

        // Demo software:
        // 1) Calculator: 7 + 5 -> LED.
        // 2) Message display: "CALC OK" into message MMIO.
        imem[0]  = 32'h00700093; // addi x1, x0, 7
        imem[1]  = 32'h00500113; // addi x2, x0, 5
        imem[2]  = 32'h002081b3; // add  x3, x1, x2
        imem[3]  = 32'h40000237; // lui  x4, 0x40000 (LED base)
        imem[4]  = 32'h00322023; // sw   x3, 0(x4)
        imem[5]  = 32'h600002b7; // lui  x5, 0x60000 (message base)
        imem[6]  = 32'h434c4337; // lui  x6, 0x434c4
        imem[7]  = 32'h14330313; // addi x6, x6, 0x143 => "CALC"
        imem[8]  = 32'h0062a023; // sw   x6, 0(x5)
        imem[9]  = 32'h204b53b7; // lui  x7, 0x204b5
        imem[10] = 32'hf2038393; // addi x7, x7, -224 => " OK "
        imem[11] = 32'h0072a223; // sw   x7, 4(x5)
        imem[12] = 32'h0000006f; // jal  x0, 0
    end

    assign imem_rdata = imem[imem_addr[11:2]];

    always @(*) begin
        if (led_sel)
            dmem_rdata = {24'h0, led};
        else if (vga_sel)
            dmem_rdata = {24'h0, vram[dmem_addr[13:2]]};
        else if (msg_sel)
            dmem_rdata = 32'h0;
        else
            dmem_rdata = dmem[dmem_addr[11:2]];
    end

    always @(posedge clk_cpu) begin
        if (dmem_we) begin
            if (vga_sel)
                vram[dmem_addr[13:2]] <= dmem_wdata[7:0];
            else if (!led_sel && !msg_sel)
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

    message_display_mmio u_msg (
        .clk(clk_cpu),
        .rst(rst),
        .we(dmem_we && msg_sel),
        .wstrb(dmem_wstrb),
        .addr_word(dmem_addr[5:2]),
        .wdata(dmem_wdata),
        .msg_ascii(msg_ascii)
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
