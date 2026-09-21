#!/usr/bin/env python3
from __future__ import annotations
import pathlib, re, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
IBEX=ROOT/"third_party"/"ibex"
REQ=["cfg/ibex.lock","cfg/trap_testlist.yaml","cfg/trap_directed_testlist.yaml",
"dv/ibex_trap_pkg.sv","dv/env/ibex_trap_env.sv","dv/seq/ibex_trap_irq_seq.sv",
"dv/scoreboard/ibex_trap_scoreboard.sv","dv/tests/ibex_trap_tests.sv",
"dv/sva/ibex_trap_assertions.sv","sw/trap_exception_directed.S",
"sw/trap_irq_sweep.S","sw/trap_irq_masking.S","sw/trap_nmi_guard.S",
"scripts/bootstrap_ibex.py","scripts/run.py","scripts/regress.py"]
def fail(s): print("[FAIL]",s); raise SystemExit(2)
def tests(s): return set(re.findall(r"^- test:\s+([A-Za-z0-9_]+)\s*$",s,re.M))
def rtls(s): return set(re.findall(r"^\s*rtl_test:\s+([A-Za-z0-9_]+)",s,re.M))
def main():
 for x in REQ:
  if not (ROOT/x).is_file(): fail("missing "+x)
 random=(ROOT/"cfg/trap_testlist.yaml").read_text()
 direct=(ROOT/"cfg/trap_directed_testlist.yaml").read_text()
 if len(tests(random))<13: fail("random testlist incomplete")
 if len(tests(direct))<4: fail("directed testlist incomplete")
 sv=(ROOT/"dv/tests/ibex_trap_tests.sv").read_text()
 for cls in rtls(random)|rtls(direct):
  if f"class {cls} " not in sv: fail("missing UVM class "+cls)
 lock={}
 for line in (ROOT/"cfg/ibex.lock").read_text().splitlines():
  if line and not line.startswith("#"):
   k,v=line.split("=",1); lock[k]=v
 if lock.get("IBEX_CONFIG")!="small": fail("IBEX_CONFIG not small")
 print("[ OK ] project files/test mappings")
 if IBEX.exists():
  head=subprocess.check_output(["git","rev-parse","HEAD"],cwd=IBEX,text=True).strip()
  if head!=lock["IBEX_COMMIT"]: fail("upstream commit mismatch")
  core=IBEX/"dv/uvm/core_ibex"
  checks=[
   "trap_ext/ibex_trap_pkg.sv" in (core/"ibex_dv.f").read_text(),
   "CPU_CORE_TRAP_ASSIGN_BEGIN" in (core/"tb/core_ibex_tb_top.sv").read_text(),
   "CPU_CORE_TRAP_PROBE_BEGIN" in (core/"env/core_ibex_dut_probe_if.sv").read_text(),
   "# BEGIN cpu-core trap verification overlay" in (core/"riscv_dv_extension/testlist.yaml").read_text(),
   "# BEGIN cpu-core trap verification overlay" in (core/"directed_tests/directed_testlist.yaml").read_text(),
   (core/"directed_tests/trap_ext_sw/trap_irq_sweep.S").is_file()]
  if not all(checks): fail("bootstrap integration incomplete")
  print("[ OK ] pinned upstream overlay")
 else: print("[INFO] run scripts/bootstrap_ibex.py for integration checks")
 return 0
if __name__=="__main__": raise SystemExit(main())
