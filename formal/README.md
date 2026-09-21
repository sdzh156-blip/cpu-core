# Formal / SVA status

The reusable properties are in `dv/sva/ibex_trap_assertions.sv` and are compiled into the dynamic DV overlay.

Implemented properties include:

- mtvec vectored/alignment invariant
- mepc bit-0 invariant
- legal M/U privilege states
- trap entry clears MIE
- trap entry copies MIE to MPIE
- trap entry saves previous privilege in MPP
- trap entry moves to M-mode
- MRET restores MIE
- MRET restores privilege
- mip mirrors raw level-sensitive maskable IRQ inputs
- NMI is not re-issued while NMI mode is already active

These properties are written as bindable SVA so the same source can be used in simulation and a commercial Formal flow. A real Formal result is intentionally not claimed until JasperGold / VC Formal / equivalent is run on the target server and produces proof reports.

The first execution milestone is therefore:

1. VCS compiles the SVA with the UVM environment.
2. Smoke/P0 run with zero assertion failures.
3. If a Formal tool is available, reuse the same property file for proof and record proved/inconclusive properties.
