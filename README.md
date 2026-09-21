# Ibex CPU Trap Subsystem Verification

Focused verification of the **lowRISC Ibex Exception / Interrupt / Trap control subsystem**.

## Frozen baseline

- Upstream: lowRISC/ibex @ `e9f55342edbd27e9e17a0e41b1c95a81abb5eac8`
- DUT configuration: `small`
- Dynamic DV: official `core_ibex` UVM + RISCV-DV + RVFI/Spike
- Project-owned DV: Trap checker, deterministic IRQ sequences, directed assembly, coverage, SVA
- Preferred simulator: VCS

## Implemented verification content

The project now checks trap entry and return state, exact `mepc` source selection, `mcause`, `mtval` capture/zero rules, `mtvec` WARL/vectored behavior, exact exception/IRQ vector target, raw level-sensitive `mip` behavior, global/local IRQ masking, Ibex IRQ priority, all fast IRQ IDs 16–30, NMI behavior, nested-NMI suppression, privilege transition and MRET restoration.

Spike remains the architecture-level golden model. The project scoreboard is complementary and gives localized Trap/CSR debug.

## Deterministic closure suite

| Case | Purpose |
|---|---|
| `ibex_trap_directed_exception` | M-ECALL, U-ECALL, EBREAK, illegal instruction, mtvec WARL |
| `ibex_trap_irq_sweep_directed` | software, timer, external, all fast IRQs 16–30, NMI |
| `ibex_trap_irq_masking_directed` | global MIE mask, local mie mask, level-sensitive pending |
| `ibex_trap_nmi_guard_directed` | NMI with MIE/mie disabled and no nested NMI |

Randomized regressions additionally cover memory faults, multiple IRQ priority, nested IRQ, invalid CSR, U-mode IRQ, WFI, CSR races and interrupt timing across instruction classes.

## Run

```bash
python3 scripts/check_env.py
python3 scripts/bootstrap_ibex.py
python3 scripts/preflight.py

make smoke SIMULATOR=vcs COV=1
make p0 SIMULATOR=vcs COV=1
make p1 SIMULATOR=vcs COV=1
make p2 SIMULATOR=vcs COV=1
make regression SIMULATOR=vcs COV=1
make report
```

The repository intentionally does not claim PASS rate, coverage percentage or Formal proof status before a real tool run.
