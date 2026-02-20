# 5-Stage RISC-V Processor with LED + VGA Text Output

This repository contains a compact **5-stage (IF/ID/EX/MEM/WB) RV32I-style processor** and a simple SoC that can drive:

- **LED output** through MMIO
- **VGA text output** (640x480@60Hz timing with an 80x30 text grid)

It is suitable as a starting point for a VSD Squadron FPGA Mini board demo project.

## Files

- `rtl/riscv5_core.v` - 5-stage pipelined CPU core (basic RV32I subset)
- `rtl/peripherals.v` - LED MMIO and VGA timing/pixel generator blocks
- `rtl/soc_top.v` - top-level SoC integrating CPU, RAM/ROM, LED, and text VRAM

## Memory Map

- `0x4000_0000` : LED output register (`[7:0]` drives LEDs)
- `0x5000_0000` - `0x5000_257F` : text VRAM (one ASCII byte per text cell, 80x30)

## VGA Text Mode

- Resolution timing: **640x480@60Hz**
- Character grid: **80 columns x 30 rows**
- Character cell size: **8x16 pixels** (8x8 glyph rows stretched by 2 in Y)
- The demo initializes the screen with:
  - `VSD SQUADRON FPGA MINI`

## Demo Program (preloaded in instruction memory)

The built-in program:

1. increments a register in a loop,
2. writes it to LED MMIO (`0x4000_0000`),
3. writes ASCII `'V'` to text VRAM base (`0x5000_0000`).

## Simulate (Icarus Verilog)

```bash
iverilog -g2012 -o simv rtl/riscv5_core.v rtl/peripherals.v rtl/soc_top.v
vvp simv
```

## Porting to VSD Squadron FPGA Mini

1. Keep CPU and VGA clocks stable (use a PLL if needed for a clean 25 MHz VGA clock).
2. Map `led[7:0]`, `vga_hsync`, `vga_vsync`, `vga_r/g/b` to board pins in your constraints file.
3. Replace the ROM `initial` demo program with your firmware loading flow (HEX/MEM file).
4. From software, write ASCII bytes to `0x5000_0000 + cell_index*4` to update characters.

Example (conceptual C-style MMIO):

```c
volatile unsigned int *led  = (unsigned int*)0x40000000;
volatile unsigned int *text = (unsigned int*)0x50000000;

*led = 0x5A;               // LEDs
text[0] = 'H';
text[1] = 'I';
```
