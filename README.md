# 5-Stage RISC-V Processor with LED + VGA Peripherals

This repo now contains a compact **5-stage (IF/ID/EX/MEM/WB) RV32I-style processor** and a small SoC wrapper that connects memory-mapped peripherals:

- **LED register** (8-bit output)
- **VGA controller** (640x480@60Hz timing, simple tile-based framebuffer)

## Files

- `rtl/riscv5_core.v` - 5-stage pipelined CPU core (basic RV32I subset)
- `rtl/peripherals.v` - LED MMIO and VGA timing/pixel generator blocks
- `rtl/soc_top.v` - top-level SoC integrating CPU, RAM/ROM, LED, and VGA VRAM

## Memory Map

- `0x4000_0000` : LED output register (`[7:0]` drives LEDs)
- `0x5000_0000` - `0x5000_3FFF` : VGA VRAM region (8-bit color entries)

## Notes

- Core pipeline is educational and intentionally compact.
- The top module includes a tiny demo program preloaded into instruction memory:
  - increments a register
  - writes it to LED MMIO
  - writes a color value to VGA memory
- VGA output uses a coarse tile lookup from VRAM:
  - address index = `{y[8:4], x[8:4]}`

## Simulate (example with Icarus Verilog)

```bash
iverilog -g2012 -o simv rtl/riscv5_core.v rtl/peripherals.v rtl/soc_top.v
vvp simv
```

You can adapt this for your FPGA board by:
1. replacing/demo-loading instruction memory from a HEX file,
2. connecting board-specific clocks/resets/pins in constraints,
3. optionally adding a PLL for 25 MHz VGA clock.
