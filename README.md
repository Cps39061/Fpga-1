# Simple 5-Stage RISC-V Processor (Xilinx ISE Friendly)

This repository contains a compact **5-stage RV32I-style processor** and a small SoC wrapper that drives:

- **LED output** through memory-mapped I/O
- **VGA output** (640x480 @ 60 Hz timing)

The RTL is plain Verilog and can be used in **Xilinx ISE Design Suite** projects.

## Project Files

- `rtl/riscv5_core.v` - 5-stage pipelined RISC-V core (educational subset)
- `rtl/peripherals.v` - LED MMIO block + VGA timing/controller
- `rtl/soc_top.v` - top-level SoC (CPU + memories + LED + VGA)
- `rtl/tb_soc_top.v` - simulation testbench that prints LED output changes

## Memory Map

- `0x4000_0000` : LED register (`[7:0]` -> board LEDs)
- `0x5000_0000` - `0x5000_3FFF` : VGA VRAM (8-bit pixel entries)

## What the Demo Program Does

The built-in ROM program in `soc_top.v`:
1. increments a register,
2. writes it to LED MMIO (`0x4000_0000`),
3. writes a color byte into VGA VRAM,
4. loops forever.

So in hardware/simulation you should see LED activity and a non-black VGA tile value.

---

## Quick Simulation (Icarus Verilog)

```bash
iverilog -g2012 -o simv rtl/riscv5_core.v rtl/peripherals.v rtl/soc_top.v rtl/tb_soc_top.v
vvp simv
```

Expected console behavior: repeated `LED=xx` prints and final `PASS` message.

---

## Using This Design in Xilinx ISE Design Suite

### 1) Create Project

1. Open **ISE Project Navigator**.
2. Create a new project (select your FPGA device/package/speed).
3. Add these RTL sources:
   - `rtl/riscv5_core.v`
   - `rtl/peripherals.v`
   - `rtl/soc_top.v`

### 2) Set Top Module

- Set `soc_top` as the **Top Module**.

### 3) Add UCF Constraints

Create a `.ucf` file for your board pins, for example:
- `clk_cpu`
- `clk_vga` (or derive 25 MHz clock with DCM/PLL)
- `rst`
- `led[7:0]`
- `vga_hsync`, `vga_vsync`, `vga_r[3:0]`, `vga_g[3:0]`, `vga_b[3:0]`

### 4) Run ISE Flow

- Synthesize → Implement Design → Generate Programming File (`.bit`).

### 5) Program FPGA

Use iMPACT / board programmer to load the bitstream.

---

## Notes

- This is an educational baseline (minimal hazard handling).
- For production use, add forwarding/stall logic and proper memory initialization from external HEX/COE files.
- If your board has only one oscillator, generate a 25 MHz pixel clock for VGA.
