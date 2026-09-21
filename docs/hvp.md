# HVP / TP-to-Case Matrix

The detailed spreadsheet is maintained separately; this repository keeps the executable mapping used by code and regression.

| TP range | Topic | Priority | Primary case |
|---|---|---|---|
| TP_TRAP_001..010 | reset, mtvec, mepc, mcause, mtval, mstatus, MRET | P0/P1 | ibex_trap_smoke |
| TP_EXC_011..015 | illegal, illegal CSR, EBREAK, ECALL M/U | P0/P1 | ibex_trap_illegal |
| TP_EXC_016..018 | instruction/load/store access fault | P0 | ibex_trap_mem_fault |
| TP_IRQ_019..022 | software/timer/external/fast IRQ | P0/P1 | ibex_trap_irq_single |
| TP_IRQ_023..025 | global/local mask, mip, vectored dispatch | P0 | ibex_trap_irq_single |
| TP_IRQ_026..027 | standard + fast priority | P1 | ibex_trap_irq_multiple |
| TP_IRQ_028 | NMI | P0 | ibex_trap_nmi |
| TP_IRQ_029 | nested interrupt | P1 | ibex_trap_irq_nested |
| TP_EXT_030..033 | mtval zero rules, U-mode IRQ, nested-NMI guard, level sensitivity | P2 | smoke/nmi/nested |
| TP_EXT_034 | IRQ/CSR race | P2 | ibex_trap_irq_csr |
| TP_EXT_035 | IRQ versus instruction timing | P2 | ibex_trap_irq_instr |
| TP_EXT_036..037 | WFI / privilege interaction | P2 | ibex_trap_irq_wfi |

## Priority definition

- **P0**: required to establish a credible project baseline.
- **P1**: closes the central interrupt/trap feature set.
- **P2**: stress, timing interactions and coverage closure.

The project should be described as feature-complete only after P0+P1 are executed and clean. P2 is the closure layer.
