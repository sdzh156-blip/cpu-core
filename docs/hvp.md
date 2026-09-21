# HVP / TP-to-Case Matrix

| TP | Verification target | Primary executable evidence |
|---|---|---|
| TP_TRAP_001 | reset / initial privilege | smoke + official DV |
| TP_TRAP_002 | mtvec vectored + 256B BASE WARL | `ibex_trap_directed_exception` + SVA |
| TP_TRAP_003 | exception vs interrupt target | scoreboard vector calculation |
| TP_TRAP_004 | synchronous mepc | exact IF/ID/WB checker |
| TP_TRAP_005 | interrupt resume flow | Spike + MRET checker |
| TP_TRAP_006 | mcause interrupt/cause encoding | Trap checker |
| TP_TRAP_007 | illegal mtval | directed exception |
| TP_TRAP_008 | LSU/access fault mtval capture | mem_fault + checker |
| TP_TRAP_009 | trap mstatus save | checker + SVA |
| TP_TRAP_010 | MRET restore | checker + SVA |
| TP_EXC_011 | illegal instruction | directed + random illegal |
| TP_EXC_012 | illegal/privileged CSR | `ibex_trap_invalid_csr` |
| TP_EXC_013 | EBREAK | directed exception |
| TP_EXC_014 | M ECALL | directed exception |
| TP_EXC_015 | U ECALL | directed exception |
| TP_EXC_016..018 | instruction/load/store access faults | `ibex_trap_mem_fault` |
| TP_IRQ_019..021 | SW/timer/external IRQ | directed IRQ sweep |
| TP_IRQ_022 | fast IRQ 16–30 | directed IRQ sweep |
| TP_IRQ_023 | global MIE masking | directed masking |
| TP_IRQ_024 | local mie + raw mip | directed masking + checker/SVA |
| TP_IRQ_025 | vectored IRQ/NMI dispatch | directed sweep + vector checker |
| TP_IRQ_026..027 | standard/fast priority | multiple IRQ random + checker |
| TP_IRQ_028 | NMI | directed NMI guard + random NMI |
| TP_IRQ_029 | nested IRQ | nested IRQ test |
| TP_EXT_030 | mtval zero rules | directed exception + checker |
| TP_EXT_031 | U-mode machine IRQ | `ibex_trap_irq_umode` |
| TP_EXT_032 | nested NMI guard | directed NMI guard + SVA |
| TP_EXT_033 | level-sensitive IRQ | directed masking |
| TP_EXT_034 | IRQ vs CSR write | IRQ CSR test |
| TP_EXT_035 | IRQ instruction timing | IRQ instruction test |
| TP_EXT_036 | WFI + IRQ | IRQ WFI test |
| TP_EXT_037 | U-mode WFI + TW=1 | U-mode TW test |

P0/P1 is the functional-completion milestone. P2 is timing/stress and coverage closure.
