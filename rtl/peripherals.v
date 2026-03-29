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

module message_display_mmio #(
    parameter MSG_BYTES = 16
) (
    input  wire         clk,
    input  wire         rst,
    input  wire         we,
    input  wire [3:0]   wstrb,
    input  wire [3:0]   addr_word,
    input  wire [31:0]  wdata,
    output wire [127:0] msg_ascii
);
    reg [7:0] message [0:MSG_BYTES-1];
    integer j;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j = 0; j < MSG_BYTES; j = j + 1)
                message[j] <= 8'h20; // space
        end else if (we) begin
            if (wstrb[0]) message[{addr_word, 2'b00}] <= wdata[7:0];
            if (wstrb[1]) message[{addr_word, 2'b01}] <= wdata[15:8];
            if (wstrb[2]) message[{addr_word, 2'b10}] <= wdata[23:16];
            if (wstrb[3]) message[{addr_word, 2'b11}] <= wdata[31:24];
        end
    end

    genvar k;
    generate
        for (k = 0; k < MSG_BYTES; k = k + 1) begin : g_msg_out
            assign msg_ascii[(8*k)+:8] = message[k];
        end
    endgenerate
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
