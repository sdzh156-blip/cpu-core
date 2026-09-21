`define IBEX_TRAP_ENV_OVERRIDE \
  virtual function void build_phase(uvm_phase phase); \
    core_ibex_env::type_id::set_type_override(ibex_trap_env::get_type()); \
    super.build_phase(phase); \
  endfunction

class ibex_trap_smoke_test extends core_ibex_debug_intr_basic_test;
  `uvm_component_utils(ibex_trap_smoke_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_exception_test extends core_ibex_base_test;
  `uvm_component_utils(ibex_trap_exception_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_mem_fault_test extends core_ibex_mem_error_test;
  `uvm_component_utils(ibex_trap_mem_fault_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_irq_single_test extends core_ibex_debug_intr_basic_test;
  `uvm_component_utils(ibex_trap_irq_single_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_irq_multiple_test extends core_ibex_debug_intr_basic_test;
  `uvm_component_utils(ibex_trap_irq_multiple_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_irq_nested_test extends core_ibex_nested_irq_test;
  `uvm_component_utils(ibex_trap_irq_nested_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_irq_wfi_test extends core_ibex_irq_wfi_test;
  `uvm_component_utils(ibex_trap_irq_wfi_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_irq_instr_test extends core_ibex_interrupt_instr_test;
  `uvm_component_utils(ibex_trap_irq_instr_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_irq_csr_test extends core_ibex_irq_csr_test;
  `uvm_component_utils(ibex_trap_irq_csr_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

`undef IBEX_TRAP_ENV_OVERRIDE
