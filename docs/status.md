# Project Status

## Code-complete candidate

As of the current main branch, implementation exists for:

- official Ibex pinned bootstrap/overlay
- extended typed DUT probes
- Trap/IRQ scoreboard
- exact mepc/mtval/vector checks
- functional coverage
- deterministic IRQ driver
- deterministic exception/IRQ/masking/NMI assembly tests
- randomized P0/P1/P2 testlist
- SVA property set
- regression runner
- preflight checker
- lightweight result collector

## Not yet claimed

The following require execution on the target EDA server:

- VCS compile PASS
- Smoke PASS
- P0/P1/P2 regression PASS
- Spike zero-mismatch evidence
- actual functional/code coverage percentages
- Formal proof results

Any compile/runtime issue found during bring-up should be fixed before resume metrics are written.
