# Formal / SVA strategy

The project-owned properties live in `dv/sva/ibex_trap_assertions.sv`.

They are compiled into the dynamic simulation through the overlay filelist and are intentionally bound at `ibex_core`, so the same file can be used by a commercial formal tool without the UVM environment.

Initial formal targets:

1. `mtvec[7:0] == 8'h01`
2. `mepc[0] == 0`
3. privilege is M or U
4. trap entry clears MIE
5. trap entry saves old MIE into MPIE
6. trap entry saves previous privilege into MPP
7. trap entry moves current privilege to M
8. MRET restores MIE from MPIE
9. MRET restores privilege from MPP

For a VC Formal/Jasper/Questa Formal run, compile the pinned Ibex RTL plus this SVA file and constrain clocks/reset and legal top-level inputs. Do not claim formal proof completion until the tool produces a clean proof report. The simulation regression still compiles and checks these properties as assertions.
