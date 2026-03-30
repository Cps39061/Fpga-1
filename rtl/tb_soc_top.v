`timescale 1ns/1ps

module tb_soc_top;
    reg clk_cpu = 1'b0;
    reg clk_vga = 1'b0;
    reg rst     = 1'b1;

    wire [7:0] led;
    wire       vga_hsync;
    wire       vga_vsync;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;

    soc_top dut (
        .clk_cpu(clk_cpu),
        .clk_vga(clk_vga),
        .rst(rst),
        .led(led),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b)
    );

    always #5  clk_cpu = ~clk_cpu; // 100 MHz
    always #20 clk_vga = ~clk_vga; // 25 MHz

    initial begin
        $display("Starting simple RISC-V SoC simulation...");
        #100;
        rst = 1'b0;

        repeat (80) begin
            @(posedge clk_cpu);
            $display("t=%0t ns : LED=%02h", $time, led);
        end

        if (led != 8'h00) begin
            $display("PASS: LED updated by CPU program. Final LED=%02h", led);
        end else begin
            $display("FAIL: LED stayed 0. Check MMIO address/program.");
        end

        $finish;
    end
endmodule
