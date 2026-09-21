# Official Ibex basis

This project is intentionally tied to the pinned upstream revision in `cfg/ibex.lock`.

The implementation was checked against these upstream areas:

- `doc/03_reference/exception_interrupts.rst`: trap entry, vectoring, interrupt IDs, NMI and priority.
- `doc/03_reference/cs_registers.rst`: mstatus/mie/mip/mtvec/mepc/mcause/mtval semantics.
- `dv/uvm/core_ibex/env/core_ibex_env.sv`: official environment composition.
- `dv/uvm/core_ibex/env/core_ibex_dut_probe_if.sv`: project-observable trap state.
- `dv/uvm/core_ibex/common/irq_agent/irq_if.sv`: IRQ stimulus pins.
- `dv/uvm/core_ibex/common/ibex_cosim_agent/ibex_rvfi_monitor.sv`: RVFI publication.
- `dv/uvm/core_ibex/tests/core_ibex_test_lib.sv`: official exception/interrupt directed tests.
- `dv/uvm/core_ibex/riscv_dv_extension/testlist.yaml`: official regression scenarios and iteration counts.
- `rtl/ibex_cs_registers.sv`: definitive CSR state update logic.

Important semantic note: in the pinned RTL, `mip` is a purely combinational mirror of the maskable IRQ inputs. It is **not** gated by `mie`. The project checker mirrors this RTL/documented behavior, while `mie` is used for enable/priority decisions.
