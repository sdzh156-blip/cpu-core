#!/usr/bin/env python3
"""Run project regression groups without depending on PyYAML."""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
GROUPS = {
    "p0": [
        "ibex_trap_smoke",
        "ibex_trap_illegal",
        "ibex_trap_mem_fault",
        "ibex_trap_irq_single",
        "ibex_trap_nmi",
    ],
    "p1": [
        "ibex_trap_irq_multiple",
        "ibex_trap_irq_nested",
        "ibex_trap_irq_csr",
    ],
    "p2": [
        "ibex_trap_irq_wfi",
        "ibex_trap_irq_instr",
    ],
}


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("group", choices=["p0", "p1", "p2", "all"])
    p.add_argument("--simulator", default="vcs")
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--iterations", type=int, default=1)
    p.add_argument("--cov", type=int, choices=[0, 1], default=1)
    args = p.parse_args()

    groups = ["p0", "p1", "p2"] if args.group == "all" else [args.group]
    tests = [t for g in groups for t in GROUPS[g]]

    failures: list[str] = []
    for idx, test in enumerate(tests):
        seed = args.seed + idx
        cmd = [
            sys.executable, str(ROOT / "scripts" / "run.py"),
            "--test", test,
            "--simulator", args.simulator,
            "--seed", str(seed),
            "--iterations", str(args.iterations),
            "--cov", str(args.cov),
        ]
        print("\n==>", test, "seed", seed)
        rc = subprocess.run(cmd).returncode
        if rc:
            failures.append(f"{test}@{seed}")

    if failures:
        print("\nFAILED:", ", ".join(failures), file=sys.stderr)
        return 1

    print("\nRegression group passed:", args.group)
    return 0


if __name__ == "__main__":
    sys.exit(main())
