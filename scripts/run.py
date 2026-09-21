#!/usr/bin/env python3
"""Thin reproducible wrapper around the official core_ibex Makefile."""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
IBEX = ROOT / "third_party" / "ibex"
CORE_DV = IBEX / "dv" / "uvm" / "core_ibex"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--test", required=True)
    p.add_argument("--simulator", default="vcs")
    p.add_argument("--iss", default="spike")
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--iterations", type=int, default=1)
    p.add_argument("--waves", type=int, choices=[0, 1], default=0)
    p.add_argument("--cov", type=int, choices=[0, 1], default=1)
    p.add_argument("--ibex-config", default="small")
    args = p.parse_args()

    if not CORE_DV.exists():
        print("Pinned Ibex checkout is missing. Run scripts/bootstrap_ibex.py first.",
              file=sys.stderr)
        return 2

    cmd = [
        "make", "--keep-going",
        f"IBEX_CONFIG={args.ibex_config}",
        f"SIMULATOR={args.simulator}",
        f"ISS={args.iss}",
        f"ITERATIONS={args.iterations}",
        f"SEED={args.seed}",
        f"TEST={args.test}",
        f"WAVES={args.waves}",
        f"COV={args.cov}",
    ]

    print("+", " ".join(cmd))
    return subprocess.run(cmd, cwd=CORE_DV).returncode


if __name__ == "__main__":
    sys.exit(main())
