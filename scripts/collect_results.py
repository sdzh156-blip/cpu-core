#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, re
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser()
 p.add_argument("--out",type=pathlib.Path,default=ROOT/"third_party/ibex/dv/uvm/core_ibex/out")
 p.add_argument("--report",type=pathlib.Path,default=ROOT/"results/latest.md")
 a=p.parse_args(); logs=sorted(a.out.rglob("*.log")) if a.out.exists() else []
 summaries=[]; failures=[]
 for log in logs:
  t=log.read_text(errors="ignore")
  summaries += [(log,l.strip()) for l in t.splitlines() if "TRAP_SUMMARY" in l]
  if re.search(r"UVM_(FATAL|ERROR)\s*:\s*[1-9]",t) or "TEST TIMEOUT" in t or "Cosim mismatch" in t:
   failures.append(log)
 a.report.parent.mkdir(parents=True,exist_ok=True)
 with a.report.open("w") as f:
  f.write("# Latest Ibex Trap DV evidence\n\n")
  f.write(f"Scanned logs: **{len(logs)}**  \nFailure-marker logs: **{len(set(failures))}**\n\n")
  f.write("## Trap summaries\n")
  for log,line in summaries: f.write(f"- {log.relative_to(a.out)}: {line}\n")
  if not summaries: f.write("- No TRAP_SUMMARY records found yet.\n")
  f.write("\n## Failure-marker logs\n")
  for log in sorted(set(failures)): f.write(f"- {log.relative_to(a.out)}\n")
  if not failures: f.write("- None detected by lightweight scan.\n")
 print(a.report); return 0
if __name__=="__main__": raise SystemExit(main())
