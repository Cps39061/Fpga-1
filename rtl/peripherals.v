module led_mmio (
    input  wire       clk,
    input  wire       rst,
    input  wire       we,
    input  wire [3:0] wstrb,
    input  wire [31:0] wdata,
    output reg  [7:0] leds
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            leds <= 8'h00;
        else if (we && |wstrb)
            leds <= wdata[7:0];
    end
endmodule

module vga_controller (
    input  wire        clk_25mhz,
    input  wire        rst,
    input  wire [7:0]  pixel_data,
    output wire [9:0]  x,
    output wire [9:0]  y,
    output reg         hsync,
    output reg         vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b
);
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    assign x = h_cnt;
    assign y = v_cnt;

    wire visible = (h_cnt < 640) && (v_cnt < 480);

    assign vga_r = visible ? {4{pixel_data[7]}} : 4'b0000;
    assign vga_g = visible ? {4{pixel_data[4]}} : 4'b0000;
    assign vga_b = visible ? {4{pixel_data[0]}} : 4'b0000;

    always @(posedge clk_25mhz or posedge rst) begin
        if (rst) begin
            h_cnt <= 0;
            v_cnt <= 0;
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            if (h_cnt == 799) begin
                h_cnt <= 0;
                if (v_cnt == 524)
                    v_cnt <= 0;
                else
                    v_cnt <= v_cnt + 1;
            end else begin
                h_cnt <= h_cnt + 1;
            end

            hsync <= ~((h_cnt >= 656) && (h_cnt < 752));
            vsync <= ~((v_cnt >= 490) && (v_cnt < 492));
        end
    end
endmodule
