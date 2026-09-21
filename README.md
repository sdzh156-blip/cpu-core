# Ibex CPU Trap Subsystem Verification

A focused verification project for the **lowRISC Ibex Exception / Interrupt / Trap control subsystem**.

The project deliberately reuses the official `core_ibex` UVM environment, memory agents, IRQ agent, RISCV-DV program generation and Spike co-simulation, then adds a project-owned verification layer for:

- Exception and interrupt trap entry
- `mstatus / mie / mip / mtvec / mepc / mcause / mtval`
- MRET and privilege restoration
- Software / timer / external / 15 fast interrupts / NMI
- Interrupt masking and priority
- Nested interrupts
- WFI / interrupt timing / CSR-interrupt races
- Trap-specific functional coverage
- SVA properties reusable in simulation or formal

## Pinned upstream

This repository is developed against:

- lowRISC/ibex commit: `e9f55342edbd27e9e17a0e41b1c95a81abb5eac8`
- Ibex configuration: `small`
- Preferred simulator for this project: `vcs`
- Golden model: lowRISC Spike / Ibex co-simulation

The pin is intentional: internal CSR probe paths and official DV class names are part of the integration contract.

## Architecture

```
RISCV-DV program
      |
      v
official core_ibex memory model / agents
      |
      v
    Ibex DUT <------ official IRQ agent
      |
      +---- RVFI ----> Spike co-sim
      |
      +---- trap CSR/state probes ----> ibex_trap_scoreboard
      |
      +---- SVA ----------------------> trap assertions
                                  |
                                  v
                       coverage + PASS/FAIL
```

The project extension is injected into a pinned upstream checkout by `scripts/bootstrap_ibex.py`. Upstream source is not copied into this repository.

## Quick start

Prerequisites follow the official Ibex core DV environment: RISC-V GCC, lowRISC Spike and a supported RTL simulator.

```bash
python3 scripts/check_env.py
python3 scripts/bootstrap_ibex.py
make smoke SIMULATOR=vcs
```

Useful targets:

```bash
make p0 SIMULATOR=vcs
make p1 SIMULATOR=vcs
make p2 SIMULATOR=vcs
make regression SIMULATOR=vcs
make clean
```

You can override seed and iterations:

```bash
make run TEST=ibex_trap_irq_single SEED=20260921 ITERATIONS=3 SIMULATOR=vcs
```

## Verification cases

| Case | Primary purpose |
|---|---|
| `ibex_trap_smoke` | trap entry / CSR state / MRET baseline |
| `ibex_trap_illegal` | illegal instruction exception |
| `ibex_trap_mem_fault` | instruction/data access errors |
| `ibex_trap_irq_single` | single maskable interrupt |
| `ibex_trap_irq_multiple` | simultaneous interrupt priority |
| `ibex_trap_nmi` | NMI unmaskable path |
| `ibex_trap_irq_nested` | nested interrupt handling |
| `ibex_trap_irq_wfi` | WFI + interrupt interaction |
| `ibex_trap_irq_instr` | IRQ timing across instruction classes |
| `ibex_trap_irq_csr` | IRQ / CSR-write race |

## Project-owned verification IP

`ibex_trap_scoreboard` checks architectural trap-state invariants independently of Spike:

- trap entry saves `MIE -> MPIE`
- trap entry clears `MIE`
- `MPP` records previous privilege mode
- `mcause` matches the RTL exception cause presented at save time
- `mtvec[7:0] == 8'h01` for Ibex vectored mode / 256-byte alignment
- `mepc[0] == 0`
- `mip` reflects enabled level-sensitive maskable interrupt inputs
- selected interrupt follows NMI > fast(lowest ID first) > external > software > timer
- MRET restores `MIE` and privilege mode
- trap functional coverage records cause, privilege, interrupt ID, MIE state and nesting depth

Spike remains the golden architectural execution model. This checker is complementary, not a replacement ISS.

## Status meaning

The repository contains the implementation baseline and reproducible integration scripts. A simulator/Spike toolchain is still required to produce real regression and coverage results; no unexecuted result is claimed as PASS.

See `docs/verification_plan.md` and `docs/hvp.md`.
