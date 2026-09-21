#!/usr/bin/env python3
"""Prepare the pinned Ibex checkout and inject the cpu-core trap-DV overlay."""

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

def replace_marked_block(path: pathlib.Path, payload: str) -> None:
    text = path.read_text()
    block = f"{MARK_BEGIN}\n{payload.rstrip()}\n{MARK_END}\n"
    if MARK_BEGIN in text:
        prefix = text.split(MARK_BEGIN, 1)[0]
        suffix = text.split(MARK_END, 1)[1]
        text = prefix + block + suffix
    else:
        if not text.endswith("\n"):
            text += "\n"
        text += "\n" + block
    path.write_text(text)

def copy_overlay(core_dir: pathlib.Path) -> None:
    dst = core_dir / "trap_ext"
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)
    for src_rel in ["dv/ibex_trap_pkg.sv", "dv/env", "dv/seq", "dv/scoreboard", "dv/tests", "dv/sva"]:
        src = ROOT / src_rel
        target = dst / src.name
        if src.is_dir():
            shutil.copytree(src, target)
        else:
            shutil.copy2(src, target)

def copy_directed_sw(core_dir: pathlib.Path) -> None:
    dst = core_dir / "directed_tests" / "trap_ext_sw"
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(ROOT / "sw", dst)

def patch_filelist(core_dir: pathlib.Path) -> None:
    path = core_dir / "ibex_dv.f"
    text = path.read_text()
    anchor = "$"+"{PRJ_DIR}/dv/uvm/core_ibex/tests/core_ibex_test_pkg.sv"
    text = "\n".join(
        line for line in text.splitlines()
        if "trap_ext/" not in line and "+incdir+$"+"{PRJ_DIR}/dv/uvm/core_ibex/trap_ext" not in line
    ) + "\n"
    prefix = "$"+"{PRJ_DIR}"
    overlay = "\n".join([
        "+incdir+"+prefix+"/dv/uvm/core_ibex/trap_ext",
        "+incdir+"+prefix+"/dv/uvm/core_ibex/trap_ext/env",
        "+incdir+"+prefix+"/dv/uvm/core_ibex/trap_ext/seq",
        "+incdir+"+prefix+"/dv/uvm/core_ibex/trap_ext/scoreboard",
        "+incdir+"+prefix+"/dv/uvm/core_ibex/trap_ext/tests",
        "+incdir+"+prefix+"/dv/uvm/core_ibex/trap_ext/sva",
        prefix+"/dv/uvm/core_ibex/trap_ext/ibex_trap_pkg.sv",
        prefix+"/dv/uvm/core_ibex/trap_ext/sva/ibex_trap_assertions.sv",
    ])
    if anchor not in text:
        raise RuntimeError(f"Cannot find filelist anchor in {path}")
    path.write_text(text.replace(anchor, anchor + "\n" + overlay, 1))

def patch_probe_interface(core_dir: pathlib.Path) -> None:
    path = core_dir / "env" / "core_ibex_dut_probe_if.sv"
    text = path.read_text()
    if "CPU_CORE_TRAP_PROBE_BEGIN" not in text:
        anchor = "  logic                              wb_exception;\n"
        addition = """  // CPU_CORE_TRAP_PROBE_BEGIN
  logic                              csr_save_if;
  logic                              csr_save_id;
  logic                              csr_save_wb;
  logic                              csr_restore_mret;
  logic                              debug_csr_save;
  logic                              mstatus_mie;
  logic                              mstatus_mpie;
  logic [1:0]                        mstatus_mpp;
  logic [31:0]                       mie;
  logic [31:0]                       mip;
  logic [31:0]                       mtvec;
  logic [31:0]                       mepc;
  logic [31:0]                       mcause;
  logic [31:0]                       mtval;
  logic [31:0]                       csr_mtval;
  logic [31:0]                       pc_if;
  logic [31:0]                       pc_id;
  logic [31:0]                       pc_wb;
  logic [31:0]                       exc_pc;
  logic                              nmi_mode;
  logic                              new_nmi;
  // CPU_CORE_TRAP_PROBE_END
"""
        if anchor not in text:
            raise RuntimeError(f"Cannot find probe declaration anchor in {path}")
        text = text.replace(anchor, anchor + addition, 1)
    if "CPU_CORE_TRAP_CB_BEGIN" not in text:
        anchor = "    input wb_exception;\n"
        addition = """    // CPU_CORE_TRAP_CB_BEGIN
    input csr_save_cause;
    input exc_cause;
    input csr_save_if;
    input csr_save_id;
    input csr_save_wb;
    input csr_restore_mret;
    input debug_csr_save;
    input mstatus_mie;
    input mstatus_mpie;
    input mstatus_mpp;
    input mie;
    input mip;
    input mtvec;
    input mepc;
    input mcause;
    input mtval;
    input csr_mtval;
    input pc_if;
    input pc_id;
    input pc_wb;
    input exc_pc;
    input nmi_mode;
    input new_nmi;
    // CPU_CORE_TRAP_CB_END
"""
        if anchor not in text:
            raise RuntimeError(f"Cannot find probe clocking anchor in {path}")
        text = text.replace(anchor, anchor + addition, 1)
    path.write_text(text)

def patch_top(core_dir: pathlib.Path) -> None:
    path = core_dir / "tb" / "core_ibex_tb_top.sv"
    text = path.read_text()
    if "  import ibex_trap_pkg::*;" not in text:
        anchor = "  import core_ibex_test_pkg::*;"
        if anchor not in text:
            raise RuntimeError(f"Cannot find package import anchor in {path}")
        text = text.replace(anchor, anchor + "\n  import ibex_trap_pkg::*;", 1)
    if "CPU_CORE_TRAP_ASSIGN_BEGIN" not in text:
        anchor = "  assign dut_if.wb_exception     = dut.u_ibex_top.u_ibex_core.id_stage_i.wb_exception;\n"
        addition = """  // CPU_CORE_TRAP_ASSIGN_BEGIN
  assign dut_if.csr_save_if      = dut.u_ibex_top.u_ibex_core.csr_save_if;
  assign dut_if.csr_save_id      = dut.u_ibex_top.u_ibex_core.csr_save_id;
  assign dut_if.csr_save_wb      = dut.u_ibex_top.u_ibex_core.csr_save_wb;
  assign dut_if.csr_restore_mret = dut.u_ibex_top.u_ibex_core.csr_restore_mret_id;
  assign dut_if.debug_csr_save   = dut.u_ibex_top.u_ibex_core.debug_csr_save;
  assign dut_if.mstatus_mie      = dut.u_ibex_top.u_ibex_core.cs_registers_i.mstatus_q.mie;
  assign dut_if.mstatus_mpie     = dut.u_ibex_top.u_ibex_core.cs_registers_i.mstatus_q.mpie;
  assign dut_if.mstatus_mpp      = dut.u_ibex_top.u_ibex_core.cs_registers_i.mstatus_q.mpp;
  assign dut_if.mie = {
    1'b0, dut.u_ibex_top.u_ibex_core.cs_registers_i.mie_q.irq_fast, 4'b0,
    dut.u_ibex_top.u_ibex_core.cs_registers_i.mie_q.irq_external, 3'b0,
    dut.u_ibex_top.u_ibex_core.cs_registers_i.mie_q.irq_timer, 3'b0,
    dut.u_ibex_top.u_ibex_core.cs_registers_i.mie_q.irq_software, 3'b0
  };
  assign dut_if.mip = {
    1'b0, dut.u_ibex_top.u_ibex_core.cs_registers_i.mip.irq_fast, 4'b0,
    dut.u_ibex_top.u_ibex_core.cs_registers_i.mip.irq_external, 3'b0,
    dut.u_ibex_top.u_ibex_core.cs_registers_i.mip.irq_timer, 3'b0,
    dut.u_ibex_top.u_ibex_core.cs_registers_i.mip.irq_software, 3'b0
  };
  assign dut_if.mtvec     = dut.u_ibex_top.u_ibex_core.cs_registers_i.mtvec_q;
  assign dut_if.mepc      = dut.u_ibex_top.u_ibex_core.cs_registers_i.mepc_q;
  assign dut_if.mcause = {
    dut.u_ibex_top.u_ibex_core.cs_registers_i.mcause_q.irq_ext |
      dut.u_ibex_top.u_ibex_core.cs_registers_i.mcause_q.irq_int,
    {26{dut.u_ibex_top.u_ibex_core.cs_registers_i.mcause_q.irq_int}},
    dut.u_ibex_top.u_ibex_core.cs_registers_i.mcause_q.lower_cause
  };
  assign dut_if.mtval     = dut.u_ibex_top.u_ibex_core.cs_registers_i.mtval_q;
  assign dut_if.csr_mtval = dut.u_ibex_top.u_ibex_core.csr_mtval;
  assign dut_if.pc_if     = dut.u_ibex_top.u_ibex_core.pc_if;
  assign dut_if.pc_id     = dut.u_ibex_top.u_ibex_core.pc_id;
  assign dut_if.pc_wb     = dut.u_ibex_top.u_ibex_core.pc_wb;
  assign dut_if.exc_pc    = dut.u_ibex_top.u_ibex_core.if_stage_i.exc_pc;
  assign dut_if.nmi_mode  = dut.u_ibex_top.u_ibex_core.nmi_mode;
  assign dut_if.new_nmi   = dut.u_ibex_top.u_ibex_core.new_nmi;
  // CPU_CORE_TRAP_ASSIGN_END
"""
        if anchor not in text:
            raise RuntimeError(f"Cannot find DUT assignment anchor in {path}")
        text = text.replace(anchor, anchor + addition, 1)
    path.write_text(text)

def patch_testlists(core_dir: pathlib.Path) -> None:
    replace_marked_block(core_dir / "riscv_dv_extension" / "testlist.yaml",
                         (ROOT / "cfg" / "trap_testlist.yaml").read_text())
    replace_marked_block(core_dir / "directed_tests" / "directed_testlist.yaml",
                         (ROOT / "cfg" / "trap_directed_testlist.yaml").read_text())

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()
    lock = load_lock()
    repo = lock["IBEX_REPO"]
    commit = lock["IBEX_COMMIT"]
    if args.refresh and UPSTREAM.exists():
        shutil.rmtree(UPSTREAM)
    if not UPSTREAM.exists():
        UPSTREAM.parent.mkdir(parents=True, exist_ok=True)
        run("git", "clone", "--recursive", repo, str(UPSTREAM))
    else:
        run("git", "reset", "--hard", cwd=UPSTREAM)
        run("git", "clean", "-fd", cwd=UPSTREAM)
    run("git", "fetch", "origin", commit, cwd=UPSTREAM)
    run("git", "checkout", "--detach", commit, cwd=UPSTREAM)
    run("git", "submodule", "update", "--init", "--recursive", cwd=UPSTREAM)
    core_dir = UPSTREAM / "dv" / "uvm" / "core_ibex"
    copy_overlay(core_dir)
    copy_directed_sw(core_dir)
    patch_filelist(core_dir)
    patch_probe_interface(core_dir)
    patch_top(core_dir)
    patch_testlists(core_dir)
    print(f"Prepared pinned Ibex checkout: {UPSTREAM}")
    print(f"Commit: {commit}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
