# 5-Stage RISC-V Processor (Core + Basic SoC Wrapper)

This repo contains a compact **5-stage (IF/ID/EX/MEM/WB) RV32I-style processor** and a small SoC wrapper with instruction/data memory.

## Files

- `rtl/riscv5_core.v` - 5-stage pipelined CPU core (basic RV32I subset)
- `rtl/soc_top.v` - top-level SoC integrating CPU, instruction memory, and data memory
- `rtl/peripherals.v` - optional LED/VGA peripheral modules (not used by current `soc_top`)

## Notes

- Core pipeline is educational and intentionally compact.
- The top module includes a tiny demo program preloaded into instruction memory:
  - increments a register
  - stores it to RAM address `0x0000_0000`

## Simulate (example with Icarus Verilog)

```bash
iverilog -g2012 -o simv rtl/riscv5_core.v rtl/soc_top.v
vvp simv
```

You can adapt this for your FPGA board by:
1. replacing/demo-loading instruction memory from a HEX file,
2. connecting board-specific clocks/resets/pins in constraints,
3. optionally adding your own peripherals if needed.
