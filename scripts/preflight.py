#!/usr/bin/env python3
"""Static project/pre-integration checks that do not require a simulator."""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
IBEX = ROOT / "third_party" / "ibex"

REQUIRED_PROJECT_FILES = [
    "cfg/ibex.lock",
    "cfg/trap_testlist.yaml",
    "dv/ibex_trap_pkg.sv",
    "dv/env/ibex_trap_env.sv",
    "dv/scoreboard/ibex_trap_scoreboard.sv",
    "dv/tests/ibex_trap_tests.sv",
    "dv/sva/ibex_trap_assertions.sv",
    "scripts/bootstrap_ibex.py",
    "scripts/run.py",
    "scripts/regress.py",
]

EXPECTED_TESTS = {
    "ibex_trap_smoke",
    "ibex_trap_illegal",
    "ibex_trap_mem_fault",
    "ibex_trap_irq_single",
    "ibex_trap_irq_multiple",
    "ibex_trap_nmi",
    "ibex_trap_irq_nested",
    "ibex_trap_irq_wfi",
    "ibex_trap_irq_instr",
    "ibex_trap_irq_csr",
}


def fail(msg: str) -> None:
    print(f"[FAIL] {msg}")
    raise SystemExit(2)


def ok(msg: str) -> None:
    print(f"[ OK ] {msg}")


def read_lock() -> dict[str, str]:
    data: dict[str, str] = {}
    for line in (ROOT / "cfg" / "ibex.lock").read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            k, v = line.split("=", 1)
            data[k] = v
    return data


def main() -> int:
    for rel in REQUIRED_PROJECT_FILES:
        path = ROOT / rel
        if not path.is_file():
            fail(f"missing project file: {rel}")
    ok("project file set")

    testlist = (ROOT / "cfg" / "trap_testlist.yaml").read_text()
    found = set(re.findall(r"^- test:\s+([A-Za-z0-9_]+)\s*$", testlist, re.M))
    missing = EXPECTED_TESTS - found
    if missing:
        fail(f"testlist missing: {sorted(missing)}")
    ok(f"testlist contains {len(EXPECTED_TESTS)} planned cases")

    tests_sv = (ROOT / "dv" / "tests" / "ibex_trap_tests.sv").read_text()
    rtl_tests = set(re.findall(r"^\s*rtl_test:\s+([A-Za-z0-9_]+)", testlist, re.M))
    for cls in rtl_tests:
        if f"class {cls} " not in tests_sv:
            fail(f"rtl_test class not declared: {cls}")
    ok("YAML rtl_test names map to project UVM classes")

    lock = read_lock()
    if lock.get("IBEX_CONFIG") != "small":
        fail("IBEX_CONFIG must remain frozen to small")
    ok(f"pinned config={lock['IBEX_CONFIG']} commit={lock['IBEX_COMMIT']}")

    if IBEX.exists():
        head = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=IBEX, text=True
        ).strip()
        if head != lock["IBEX_COMMIT"]:
            fail(f"upstream HEAD {head} != pinned {lock['IBEX_COMMIT']}")

        core = IBEX / "dv" / "uvm" / "core_ibex"
        filelist = (core / "ibex_dv.f").read_text()
        top = (core / "tb" / "core_ibex_tb_top.sv").read_text()
        upstream_testlist = (core / "riscv_dv_extension" / "testlist.yaml").read_text()

        if "trap_ext/ibex_trap_pkg.sv" not in filelist:
            fail("bootstrap overlay not present in ibex_dv.f")
        if "import ibex_trap_pkg::*;" not in top:
            fail("bootstrap package import not present in tb top")
        if "# BEGIN cpu-core trap verification overlay" not in upstream_testlist:
            fail("bootstrap tests not present in upstream testlist")
        ok("pinned upstream checkout and overlay")
    else:
        print("[INFO] third_party/ibex not present; run scripts/bootstrap_ibex.py for integration checks")

    print("Preflight complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
