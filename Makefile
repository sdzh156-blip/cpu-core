SIMULATOR ?= vcs
SEED ?= 1
ITERATIONS ?= 1
COV ?= 1
TEST ?= ibex_trap_smoke

.PHONY: bootstrap env run smoke p0 p1 p2 regression clean

env:
	python3 scripts/check_env.py

bootstrap:
	python3 scripts/bootstrap_ibex.py

run: bootstrap
	python3 scripts/run.py --test $(TEST) --simulator $(SIMULATOR) --seed $(SEED) --iterations $(ITERATIONS) --cov $(COV)

smoke: bootstrap
	python3 scripts/run.py --test ibex_trap_smoke --simulator $(SIMULATOR) --seed $(SEED) --iterations 1 --cov $(COV)

p0: bootstrap
	python3 scripts/regress.py p0 --simulator $(SIMULATOR) --seed $(SEED) --iterations $(ITERATIONS) --cov $(COV)

p1: bootstrap
	python3 scripts/regress.py p1 --simulator $(SIMULATOR) --seed $(SEED) --iterations $(ITERATIONS) --cov $(COV)

p2: bootstrap
	python3 scripts/regress.py p2 --simulator $(SIMULATOR) --seed $(SEED) --iterations $(ITERATIONS) --cov $(COV)

regression: bootstrap
	python3 scripts/regress.py all --simulator $(SIMULATOR) --seed $(SEED) --iterations $(ITERATIONS) --cov $(COV)

clean:
	rm -rf third_party/ibex/dv/uvm/core_ibex/out
