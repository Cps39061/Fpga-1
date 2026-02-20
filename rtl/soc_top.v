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
    localparam LED_ADDR   = 32'h4000_0000;
    localparam VGA_ADDR   = 32'h5000_0000;
    localparam TEXT_COLS  = 80;
    localparam TEXT_ROWS  = 30;
    localparam TEXT_CELLS = TEXT_COLS * TEXT_ROWS;

    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;

    wire        dmem_we;
    wire [3:0]  dmem_wstrb;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;

    reg [31:0] imem [0:1023];
    reg [31:0] dmem [0:1023];
    reg [7:0]  vram [0:TEXT_CELLS-1];

    wire [7:0] vga_pixel;
    wire [9:0] vga_x;
    wire [9:0] vga_y;

    wire led_sel = (dmem_addr == LED_ADDR);
    wire vga_sel = (dmem_addr[31:20] == VGA_ADDR[31:20]);

    integer idx;
    integer msg_base;
    initial begin
        for (idx = 0; idx < 1024; idx = idx + 1) begin
            imem[idx] = 32'h0000_0013; // NOP
            dmem[idx] = 32'h0000_0000;
        end
        for (idx = 0; idx < TEXT_CELLS; idx = idx + 1) begin
            vram[idx] = 8'h20;
        end

        msg_base = (14 * TEXT_COLS) + 24;
        vram[msg_base + 0]  = "V";
        vram[msg_base + 1]  = "S";
        vram[msg_base + 2]  = "D";
        vram[msg_base + 3]  = " ";
        vram[msg_base + 4]  = "S";
        vram[msg_base + 5]  = "Q";
        vram[msg_base + 6]  = "U";
        vram[msg_base + 7]  = "A";
        vram[msg_base + 8]  = "D";
        vram[msg_base + 9]  = "R";
        vram[msg_base + 10] = "O";
        vram[msg_base + 11] = "N";
        vram[msg_base + 12] = " ";
        vram[msg_base + 13] = "F";
        vram[msg_base + 14] = "P";
        vram[msg_base + 15] = "G";
        vram[msg_base + 16] = "A";
        vram[msg_base + 17] = " ";
        vram[msg_base + 18] = "M";
        vram[msg_base + 19] = "I";
        vram[msg_base + 20] = "N";
        vram[msg_base + 21] = "I";

        // Demo software: increment LED and write 'V' to text VRAM cell 0.
        imem[0]  = 32'h00000093; // addi x1, x0, 0
        imem[1]  = 32'h00108093; // addi x1, x1, 1
        imem[2]  = 32'h40000137; // lui  x2, 0x40000 -> 0x4000_0000 LED MMIO
        imem[3]  = 32'h00112023; // sw   x1, 0(x2)
        imem[4]  = 32'h500001b7; // lui  x3, 0x50000 (VRAM base)
        imem[5]  = 32'h05600213; // addi x4, x0, 86 ('V')
        imem[6]  = 32'h0041a023; // sw   x4, 0(x3)
        imem[7]  = 32'hff9ff06f; // jal  x0, -8
    end

    assign imem_rdata = imem[imem_addr[11:2]];

    always @(*) begin
        if (led_sel)
            dmem_rdata = {24'h0, led};
        else if (vga_sel && (dmem_addr[13:2] < TEXT_CELLS))
            dmem_rdata = {24'h0, vram[dmem_addr[13:2]]};
        else
            dmem_rdata = dmem[dmem_addr[11:2]];
    end

    always @(posedge clk_cpu) begin
        if (dmem_we) begin
            if (vga_sel && (dmem_addr[13:2] < TEXT_CELLS))
                vram[dmem_addr[13:2]] <= dmem_wdata[7:0];
            else if (!led_sel)
                dmem[dmem_addr[11:2]] <= dmem_wdata;
        end
    end

    function [7:0] font_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            case (ch)
                "A": case (row) 0:font_row=8'b00011000;1:font_row=8'b00100100;2:font_row=8'b01000010;3:font_row=8'b01111110;4:font_row=8'b01000010;5:font_row=8'b01000010;6:font_row=8'b01000010;default:font_row=0; endcase
                "D": case (row) 0:font_row=8'b01111100;1:font_row=8'b01000010;2:font_row=8'b01000010;3:font_row=8'b01000010;4:font_row=8'b01000010;5:font_row=8'b01000010;6:font_row=8'b01111100;default:font_row=0; endcase
                "F": case (row) 0:font_row=8'b01111110;1:font_row=8'b01000000;2:font_row=8'b01000000;3:font_row=8'b01111100;4:font_row=8'b01000000;5:font_row=8'b01000000;6:font_row=8'b01000000;default:font_row=0; endcase
                "G": case (row) 0:font_row=8'b00111100;1:font_row=8'b01000010;2:font_row=8'b01000000;3:font_row=8'b01001110;4:font_row=8'b01000010;5:font_row=8'b01000010;6:font_row=8'b00111100;default:font_row=0; endcase
                "I": case (row) 0:font_row=8'b00111100;1:font_row=8'b00010000;2:font_row=8'b00010000;3:font_row=8'b00010000;4:font_row=8'b00010000;5:font_row=8'b00010000;6:font_row=8'b00111100;default:font_row=0; endcase
                "M": case (row) 0:font_row=8'b01000010;1:font_row=8'b01100110;2:font_row=8'b01011010;3:font_row=8'b01000010;4:font_row=8'b01000010;5:font_row=8'b01000010;6:font_row=8'b01000010;default:font_row=0; endcase
                "N": case (row) 0:font_row=8'b01000010;1:font_row=8'b01100010;2:font_row=8'b01010010;3:font_row=8'b01001010;4:font_row=8'b01000110;5:font_row=8'b01000010;6:font_row=8'b01000010;default:font_row=0; endcase
                "O": case (row) 0:font_row=8'b00111100;1:font_row=8'b01000010;2:font_row=8'b01000010;3:font_row=8'b01000010;4:font_row=8'b01000010;5:font_row=8'b01000010;6:font_row=8'b00111100;default:font_row=0; endcase
                "P": case (row) 0:font_row=8'b01111100;1:font_row=8'b01000010;2:font_row=8'b01000010;3:font_row=8'b01111100;4:font_row=8'b01000000;5:font_row=8'b01000000;6:font_row=8'b01000000;default:font_row=0; endcase
                "Q": case (row) 0:font_row=8'b00111100;1:font_row=8'b01000010;2:font_row=8'b01000010;3:font_row=8'b01000010;4:font_row=8'b01001010;5:font_row=8'b01000100;6:font_row=8'b00111010;default:font_row=0; endcase
                "R": case (row) 0:font_row=8'b01111100;1:font_row=8'b01000010;2:font_row=8'b01000010;3:font_row=8'b01111100;4:font_row=8'b01001000;5:font_row=8'b01000100;6:font_row=8'b01000010;default:font_row=0; endcase
                "S": case (row) 0:font_row=8'b00111100;1:font_row=8'b01000010;2:font_row=8'b01000000;3:font_row=8'b00111100;4:font_row=8'b00000010;5:font_row=8'b01000010;6:font_row=8'b00111100;default:font_row=0; endcase
                "U": case (row) 0:font_row=8'b01000010;1:font_row=8'b01000010;2:font_row=8'b01000010;3:font_row=8'b01000010;4:font_row=8'b01000010;5:font_row=8'b01000010;6:font_row=8'b00111100;default:font_row=0; endcase
                "V": case (row) 0:font_row=8'b01000010;1:font_row=8'b01000010;2:font_row=8'b01000010;3:font_row=8'b00100100;4:font_row=8'b00100100;5:font_row=8'b00011000;6:font_row=8'b00011000;default:font_row=0; endcase
                default: font_row = 8'b00000000;
            endcase
        end
    endfunction

    wire [6:0]  text_col = vga_x[9:3];
    wire [4:0]  text_row = vga_y[8:4];
    wire [11:0] text_idx = (text_row * TEXT_COLS) + text_col;
    wire [7:0]  text_char = (text_idx < TEXT_CELLS) ? vram[text_idx] : 8'h20;
    wire [7:0]  glyph_bits = font_row(text_char, vga_y[3:1]);
    wire        glyph_on = glyph_bits[7 - vga_x[2:0]];

    assign vga_pixel = ((vga_x < 640) && (vga_y < 480)) ? (glyph_on ? 8'hFF : 8'h01) : 8'h00;

    led_mmio u_led (
        .clk(clk_cpu),
        .rst(rst),
        .we(dmem_we && led_sel),
        .wstrb(dmem_wstrb),
        .wdata(dmem_wdata),
        .leds(led)
    );

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
