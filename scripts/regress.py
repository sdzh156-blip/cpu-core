#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
GROUPS = {
 "p0": ["ibex_trap_smoke","ibex_trap_directed_exception","ibex_trap_illegal",
        "ibex_trap_mem_fault","ibex_trap_irq_single","ibex_trap_irq_masking_directed",
        "ibex_trap_nmi_guard_directed"],
 "p1": ["ibex_trap_irq_sweep_directed","ibex_trap_irq_multiple","ibex_trap_nmi",
        "ibex_trap_irq_nested","ibex_trap_invalid_csr","ibex_trap_irq_umode"],
 "p2": ["ibex_trap_irq_csr","ibex_trap_irq_wfi","ibex_trap_umode_tw","ibex_trap_irq_instr"],
}
def main() -> int:
 p=argparse.ArgumentParser()
 p.add_argument("group",choices=["p0","p1","p2","all"])
 p.add_argument("--simulator",default="vcs")
 p.add_argument("--seed",type=int,default=1)
 p.add_argument("--iterations",type=int,default=1)
 p.add_argument("--cov",type=int,choices=[0,1],default=1)
 a=p.parse_args()
 groups=["p0","p1","p2"] if a.group=="all" else [a.group]
 failures=[]
 for idx,test in enumerate(t for g in groups for t in GROUPS[g]):
  seed=a.seed+idx
  cmd=[sys.executable,str(ROOT/"scripts"/"run.py"),"--test",test,"--simulator",a.simulator,
       "--seed",str(seed),"--iterations",str(a.iterations),"--cov",str(a.cov)]
  print("\n==>",test,"seed",seed)
  if subprocess.run(cmd).returncode: failures.append(f"{test}@{seed}")
 if failures:
  print("\nFAILED:",", ".join(failures),file=sys.stderr); return 1
 print("\nRegression group passed:",a.group); return 0
if __name__=="__main__": raise SystemExit(main())
