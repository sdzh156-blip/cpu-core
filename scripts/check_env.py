#!/usr/bin/env python3
from __future__ import annotations

import os
import shutil
import sys


REQUIRED = {
    "git": "git",
    "make": "make",
    "python3": "python3",
}

OPTIONAL_SIM = ["vcs", "xrun", "vsim", "dsim"]


def main() -> int:
    failed = False
    for label, exe in REQUIRED.items():
        path = shutil.which(exe)
        print(f"{label:14}: {path or 'MISSING'}")
        failed |= path is None

    print("simulators     :", ", ".join(
        f"{x}={shutil.which(x) or 'missing'}" for x in OPTIONAL_SIM
    ))

    print("RISCV_GCC     :", os.environ.get("RISCV_GCC", "unset"))
    print("RISCV_OBJCOPY :", os.environ.get("RISCV_OBJCOPY", "unset"))
    print("SPIKE_PATH    :", os.environ.get("SPIKE_PATH", "unset"))
    print("PKG_CONFIG_PATH:", os.environ.get("PKG_CONFIG_PATH", "unset"))

    if failed:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
