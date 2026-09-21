# Verification Plan

## Goal

Verify the Ibex CPU Exception / Interrupt / Trap control subsystem without expanding the scope to full-core feature signoff.

## DUT configuration

The project freezes the official `small` configuration: RV32I base, compressed instructions enabled by Ibex, fast M extension, PMP disabled, ICache disabled, branch predictor disabled, SecureIbex disabled and debug trigger disabled.

## Reuse versus project-owned content

Reused from official Ibex:

- `core_ibex` UVM testbench
- instruction and data memory agents
- IRQ agent
- memory model
- RISCV-DV generator integration
- RVFI monitor
- Spike co-simulation
- upstream test runtime and result handling

Project-owned:

- `ibex_trap_env`
- `ibex_trap_scoreboard`
- trap functional coverage
- trap-focused UVM test classes
- trap testlist
- SVA properties
- regression grouping and wrapper scripts
- HVP / TP-to-case mapping

## Checker strategy

### Layer 1: Spike

Spike remains the golden architectural model. It catches wrong retired instructions, register results and architectural control flow.

### Layer 2: trap scoreboard

The trap scoreboard samples the same internal trap state that the official DV environment exposes or probes. It checks local invariants at trap entry and MRET. This gives focused debug when a co-simulation mismatch is too broad.

### Layer 3: SVA

Assertions cover state-transition invariants such as mtvec alignment, MIE/MPIE/MPP transitions and legal privilege values. They are compiled in simulation and are intentionally written so the same properties can be reused in a formal harness.

## Coverage model

Coverpoints:

- exception versus interrupt
- exception causes 1/2/3/5/7/8/11
- interrupt IDs 3/7/11/16..30/31
- source privilege M/U
- old MIE 0/1
- nesting depth
- simultaneous enabled-pending interrupt count
- raw `mip` pending state (independent of `mie`)

Crosses:

- trap kind x privilege
- interrupt ID x old MIE
- nesting depth x trap kind

The trap checker follows the current Ibex RTL semantics where `mip` is a purely combinational mirror of the maskable interrupt inputs; it is not gated by `mie`. The official Ibex functional coverage remains enabled as a second source of coverage, especially `interrupt_taken_instr_cross` and `irq_wfi_cross`.

## Signoff intent

P0/P1 signoff requires:

1. all planned core TP exercised,
2. zero Spike architectural mismatch,
3. zero project trap-checker mismatch,
4. zero project SVA failures,
5. planned functional bins hit or explicitly waived,
6. repeatable multi-seed regression.

P2 adds WFI, CSR races, instruction timing and stress/coverage closure.

Actual PASS and coverage percentages are only recorded after execution on a machine with the required simulator, RISC-V toolchain and Spike.
