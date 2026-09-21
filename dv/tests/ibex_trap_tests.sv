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

class ibex_trap_umode_tw_test extends core_ibex_umode_tw_test;
  `uvm_component_utils(ibex_trap_umode_tw_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_invalid_csr_test extends core_ibex_invalid_csr_test;
  `uvm_component_utils(ibex_trap_invalid_csr_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_irq_umode_test extends core_ibex_debug_intr_basic_test;
  `uvm_component_utils(ibex_trap_irq_umode_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE
endclass

class ibex_trap_irq_directed_base_test extends core_ibex_base_test;

  `uvm_component_utils(ibex_trap_irq_directed_base_test)
  `uvm_component_new
  `IBEX_TRAP_ENV_OVERRIDE

  task automatic drive_irq(int id);
    ibex_trap_fixed_irq_seq seq;
    seq = ibex_trap_fixed_irq_seq::type_id::create($sformatf("irq_%0d", id));
    seq.set_irq_id(id);
    seq.start(env.vseqr.irq_seqr);
  endtask

  task automatic drop_irq();
    ibex_trap_fixed_irq_seq seq;
    seq = ibex_trap_fixed_irq_seq::type_id::create("irq_drop");
    seq.start(env.vseqr.irq_seqr);
  endtask

  task automatic wait_for_trap_id(int id, int unsigned timeout_cycles = 5000);
    bit seen;
    seen = 1'b0;
    fork
      begin
        forever begin
          clk_vif.wait_clks(1);
          if (dut_vif.csr_save_cause &&
              (dut_vif.exc_cause.irq_ext || dut_vif.exc_cause.irq_int) &&
              dut_vif.exc_cause.lower_cause == id[4:0]) begin
            seen = 1'b1;
            break;
          end
        end
      end
      begin
        clk_vif.wait_clks(timeout_cycles);
      end
    join_any
    disable fork;
    if (!seen)
      `uvm_fatal("TRAP_IRQ_TIMEOUT", $sformatf("IRQ %0d was not taken", id))
  endtask

  task automatic wait_for_mret(int unsigned timeout_cycles = 5000);
    bit seen;
    seen = 1'b0;
    fork
      begin
        forever begin
          clk_vif.wait_clks(1);
          if (dut_vif.mret) begin
            seen = 1'b1;
            break;
          end
        end
      end
      begin
        clk_vif.wait_clks(timeout_cycles);
      end
    join_any
    disable fork;
    if (!seen) `uvm_fatal("TRAP_MRET_TIMEOUT", "MRET was not observed")
  endtask

  task automatic assert_no_trap_id(int id, int unsigned cycles);
    repeat (cycles) begin
      clk_vif.wait_clks(1);
      if (dut_vif.csr_save_cause &&
          (dut_vif.exc_cause.irq_ext || dut_vif.exc_cause.irq_int) &&
          dut_vif.exc_cause.lower_cause == id[4:0]) begin
        `uvm_fatal("TRAP_MASKING",
          $sformatf("IRQ %0d taken while it should be masked", id))
      end
    end
  endtask

endclass

class ibex_trap_irq_sweep_test extends ibex_trap_irq_directed_base_test;
  `uvm_component_utils(ibex_trap_irq_sweep_test)
  `uvm_component_new

  virtual task send_stimulus();
    int ids[$] = '{3, 7, 11, 16, 17, 18, 19, 20, 21, 22, 23,
                   24, 25, 26, 27, 28, 29, 30, 31};

    vseq.start(env.vseqr);

    // Directed SW enables every maskable Ibex interrupt before entering its WFI loop.
    wait ((dut_vif.mie & 32'h7fff_0888) == 32'h7fff_0888);
    wait (dut_vif.mstatus_mie == 1'b1);

    foreach (ids[i]) begin
      `uvm_info("TRAP_IRQ_SWEEP", $sformatf("Driving IRQ id %0d", ids[i]), UVM_LOW)
      drive_irq(ids[i]);
      wait_for_trap_id(ids[i]);
      drop_irq();
      wait_for_mret();
      clk_vif.wait_clks(5);
    end
  endtask
endclass

class ibex_trap_irq_masking_test extends ibex_trap_irq_directed_base_test;
  `uvm_component_utils(ibex_trap_irq_masking_test)
  `uvm_component_new

  virtual task send_stimulus();
    vseq.start(env.vseqr);

    // Phase A: source is locally enabled, global MIE is disabled.
    wait (dut_vif.mie[11] == 1'b1 && dut_vif.mstatus_mie == 1'b0);
    drive_irq(11);
    assert_no_trap_id(11, 100);
    wait (dut_vif.mstatus_mie == 1'b1);
    wait_for_trap_id(11);
    drop_irq();
    wait_for_mret();

    // Phase B: global MIE is enabled, source is locally disabled.
    wait (dut_vif.mstatus_mie == 1'b1 && dut_vif.mie[11] == 1'b0);
    drive_irq(11);
    assert_no_trap_id(11, 100);
    wait (dut_vif.mie[11] == 1'b1);
    wait_for_trap_id(11);
    drop_irq();
    wait_for_mret();
  endtask
endclass

class ibex_trap_nmi_guard_test extends ibex_trap_irq_directed_base_test;
  `uvm_component_utils(ibex_trap_nmi_guard_test)
  `uvm_component_new

  virtual task send_stimulus();
    vseq.start(env.vseqr);

    // NMI must be accepted even with MIE=0 and mie=0.
    wait (dut_vif.mstatus_mie == 1'b0 && dut_vif.mie == '0);
    drive_irq(31);
    wait_for_trap_id(31);

    // Keep the NMI level asserted while already in the NMI handler.
    // A second NMI must not be accepted.
    assert_no_trap_id(31, 100);
    drop_irq();
    wait_for_mret();
  endtask
endclass

`undef IBEX_TRAP_ENV_OVERRIDE
