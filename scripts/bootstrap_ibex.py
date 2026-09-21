#!/usr/bin/env python3
"""Clone the pinned Ibex revision and apply the trap-DV overlay idempotently."""

from __future__ import annotations

import argparse
import pathlib
import shutil
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCK = ROOT / "cfg" / "ibex.lock"
UPSTREAM = ROOT / "third_party" / "ibex"
MARK_BEGIN = "# BEGIN cpu-core trap verification overlay"
MARK_END = "# END cpu-core trap verification overlay"


def run(*args: str, cwd: pathlib.Path | None = None) -> None:
    print("+", " ".join(args))
    subprocess.run(args, cwd=cwd, check=True)


def load_lock() -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in LOCK.read_text().splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("#"):
            continue
        key, value = raw.split("=", 1)
        out[key] = value
    return out


def replace_marked_block(path: pathlib.Path, block: str) -> None:
    text = path.read_text()
    if MARK_BEGIN in text:
        prefix = text.split(MARK_BEGIN, 1)[0]
        suffix = text.split(MARK_END, 1)[1]
        text = prefix + block + suffix
    else:
        if not text.endswith("\n"):
            text += "\n"
        text += "\n" + block
    path.write_text(text)


def patch_filelist(core_dir: pathlib.Path) -> None:
    path = core_dir / "ibex_dv.f"
    text = path.read_text()
    anchor = "${PRJ_DIR}/dv/uvm/core_ibex/tests/core_ibex_test_pkg.sv"

    overlay_lines = [
        "+incdir+${PRJ_DIR}/dv/uvm/core_ibex/trap_ext",
        "+incdir+${PRJ_DIR}/dv/uvm/core_ibex/trap_ext/env",
        "+incdir+${PRJ_DIR}/dv/uvm/core_ibex/trap_ext/scoreboard",
        "+incdir+${PRJ_DIR}/dv/uvm/core_ibex/trap_ext/tests",
        "+incdir+${PRJ_DIR}/dv/uvm/core_ibex/trap_ext/sva",
        "${PRJ_DIR}/dv/uvm/core_ibex/trap_ext/ibex_trap_pkg.sv",
        "${PRJ_DIR}/dv/uvm/core_ibex/trap_ext/sva/ibex_trap_assertions.sv",
    ]

    text = "\n".join(
        line for line in text.splitlines()
        if "trap_ext/" not in line
        and "+incdir+${PRJ_DIR}/dv/uvm/core_ibex/trap_ext" not in line
    ) + "\n"

    if anchor not in text:
        raise RuntimeError(f"Cannot find filelist anchor in {path}")

    overlay = "\n".join(overlay_lines)
    text = text.replace(anchor, anchor + "\n" + overlay, 1)
    path.write_text(text)


def patch_top(core_dir: pathlib.Path) -> None:
    path = core_dir / "tb" / "core_ibex_tb_top.sv"
    text = path.read_text()
    import_line = "  import ibex_trap_pkg::*;"
    if import_line not in text:
        anchor = "  import core_ibex_test_pkg::*;"
        if anchor not in text:
            raise RuntimeError(f"Cannot find package import anchor in {path}")
        text = text.replace(anchor, anchor + "\n" + import_line, 1)
        path.write_text(text)


def copy_overlay(core_dir: pathlib.Path) -> None:
    dst = core_dir / "trap_ext"
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)

    for src_rel in [
        "dv/ibex_trap_pkg.sv",
        "dv/env",
        "dv/scoreboard",
        "dv/tests",
        "dv/sva",
    ]:
        src = ROOT / src_rel
        target = dst / src.name
        if src.is_dir():
            shutil.copytree(src, target)
        else:
            shutil.copy2(src, target)


def patch_testlist(core_dir: pathlib.Path) -> None:
    target = core_dir / "riscv_dv_extension" / "testlist.yaml"
    payload = (ROOT / "cfg" / "trap_testlist.yaml").read_text().rstrip()
    block = f"{MARK_BEGIN}\n{payload}\n{MARK_END}\n"
    replace_marked_block(target, block)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true",
                        help="delete and reclone the pinned upstream checkout")
    args = parser.parse_args()

    lock = load_lock()
    repo = lock["IBEX_REPO"]
    commit = lock["IBEX_COMMIT"]

    if args.refresh and UPSTREAM.exists():
        shutil.rmtree(UPSTREAM)

    if not UPSTREAM.exists():
        UPSTREAM.parent.mkdir(parents=True, exist_ok=True)
        run("git", "clone", "--recursive", repo, str(UPSTREAM))

    run("git", "fetch", "origin", commit, cwd=UPSTREAM)
    run("git", "checkout", "--detach", commit, cwd=UPSTREAM)
    run("git", "submodule", "update", "--init", "--recursive", cwd=UPSTREAM)

    core_dir = UPSTREAM / "dv" / "uvm" / "core_ibex"
    copy_overlay(core_dir)
    patch_filelist(core_dir)
    patch_top(core_dir)
    patch_testlist(core_dir)

    print(f"Prepared pinned Ibex checkout: {UPSTREAM}")
    print(f"Commit: {commit}")
    print("Overlay: dv/uvm/core_ibex/trap_ext")
    return 0


if __name__ == "__main__":
    sys.exit(main())
