class ibex_trap_scoreboard extends uvm_scoreboard;

  uvm_tlm_analysis_fifo #(ibex_rvfi_seq_item) rvfi_fifo;

  virtual clk_rst_if             clk_vif;
  virtual core_ibex_dut_probe_if dut_vif;
  virtual irq_if                 irq_vif;

  int unsigned trap_count;
  int unsigned irq_trap_count;
  int unsigned exception_count;
  int unsigned mret_count;
  int unsigned rvfi_trap_count;
  int unsigned nesting_depth;
  int unsigned vector_check_count;
  int unsigned mtval_check_count;
  int unsigned mepc_check_count;

  bit          cov_is_irq;
  int unsigned cov_cause;
  bit [1:0]    cov_priv;
  bit          cov_old_mie;
  int unsigned cov_depth;
  int unsigned cov_pending_count;
  bit          cov_mtval_zero;
  bit          cov_nmi_mode;

  covergroup trap_cg;
    option.per_instance = 1;

    cp_kind: coverpoint cov_is_irq {
      bins exception = {0};
      bins interrupt = {1};
    }

    cp_exception_cause: coverpoint cov_cause iff (!cov_is_irq) {
      bins instr_access = {1};
      bins illegal      = {2};
      bins breakpoint   = {3};
      bins load_access  = {5};
      bins store_access = {7};
      bins ecall_u      = {8};
      bins ecall_m      = {11};
    }

    cp_irq_id: coverpoint cov_cause iff (cov_is_irq) {
      bins software = {3};
      bins timer    = {7};
      bins external = {11};
      bins fast[]   = {[16:30]};
      bins nmi      = {31};
    }

    cp_priv: coverpoint cov_priv {
      bins user    = {2'b00};
      bins machine = {2'b11};
    }

    cp_old_mie: coverpoint cov_old_mie {
      bins disabled = {0};
      bins enabled  = {1};
    }

    cp_depth: coverpoint cov_depth {
      bins first  = {1};
      bins nested = {[2:4]};
      bins deep   = {[5:255]};
    }

    cp_pending_count: coverpoint cov_pending_count {
      bins none  = {0};
      bins one   = {1};
      bins multi = {[2:19]};
    }

    cp_mtval_zero: coverpoint cov_mtval_zero {
      bins zero    = {1};
      bins nonzero = {0};
    }

    cp_nmi_mode: coverpoint cov_nmi_mode {
      bins normal = {0};
      bins nmi    = {1};
    }

    kind_priv_cross: cross cp_kind, cp_priv;
    irq_mie_cross: cross cp_irq_id, cp_old_mie;
  endgroup

  `uvm_component_utils(ibex_trap_scoreboard)

  function new(string name = "ibex_trap_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    rvfi_fifo = new("rvfi_fifo", this);
    trap_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_if", clk_vif))
      `uvm_fatal(get_type_name(), "Cannot get clk_if")
    if (!uvm_config_db#(virtual core_ibex_dut_probe_if)::get(this, "", "dut_if", dut_vif))
      `uvm_fatal(get_type_name(), "Cannot get dut_if")
    if (!uvm_config_db#(virtual irq_if)::get(this, "", "vif", irq_vif))
      `uvm_fatal(get_type_name(), "Cannot get irq vif")
  endfunction

  function automatic bit [31:0] encode_cause(ibex_pkg::exc_cause_t cause);
    bit [31:0] value = '0;
    value[31] = cause.irq_ext | cause.irq_int;
    if (cause.irq_int) value[30:5] = '1;
    value[4:0] = cause.lower_cause;
    return value;
  endfunction

  function automatic int unsigned enabled_pending_count(bit [31:0] mie);
    int unsigned n = 0;
    n += irq_vif.irq_nm;
    n += irq_vif.irq_software & mie[3];
    n += irq_vif.irq_timer & mie[7];
    n += irq_vif.irq_external & mie[11];
    for (int i = 0; i < 15; i++) n += irq_vif.irq_fast[i] & mie[16+i];
    return n;
  endfunction

  function automatic int expected_irq_id(bit [31:0] mie);
    if (irq_vif.irq_nm) return 31;
    for (int i = 0; i < 15; i++)
      if (irq_vif.irq_fast[i] && mie[16+i]) return 16+i;
    if (irq_vif.irq_external && mie[11]) return 11;
    if (irq_vif.irq_software && mie[3]) return 3;
    if (irq_vif.irq_timer && mie[7]) return 7;
    return -1;
  endfunction

  function automatic bit [31:0] expected_trap_pc(ibex_pkg::exc_cause_t cause,
                                                bit [31:0] mtvec);
    bit [31:0] base;
    bit [4:0]  id;
    base = {mtvec[31:8], 8'h00};
    if (!(cause.irq_ext || cause.irq_int)) return base;
    id = cause.irq_int ? 5'd31 : cause.lower_cause;
    return base + ({27'b0, id} << 2);
  endfunction

  function automatic bit [31:0] expected_mepc();
    if (dut_vif.dut_cb.csr_save_if) return dut_vif.dut_cb.pc_if;
    if (dut_vif.dut_cb.csr_save_id) return dut_vif.dut_cb.pc_id;
    if (dut_vif.dut_cb.csr_save_wb) return dut_vif.dut_cb.pc_wb;
    return 32'hx;
  endfunction

  task automatic consume_rvfi();
    ibex_rvfi_seq_item item;
    forever begin
      rvfi_fifo.get(item);
      if (item.trap) rvfi_trap_count++;
    end
  endtask

  task automatic check_mip();
    bit [31:0] expected;
    expected = '0;
    expected[3]  = irq_vif.irq_software;
    expected[7]  = irq_vif.irq_timer;
    expected[11] = irq_vif.irq_external;
    expected[30:16] = irq_vif.irq_fast;

    if ((dut_vif.mip & 32'h7fff_0888) !== (expected & 32'h7fff_0888)) begin
      `uvm_error("TRAP_MIP",
        $sformatf("mip raw-pending mismatch exp=%08x act=%08x mie=%08x",
                  expected, dut_vif.mip, dut_vif.mie))
    end
  endtask

  task automatic monitor_trap_state();
    bit prev_mie;
    bit prev_mpie;
    bit [1:0] prev_mpp;
    bit [1:0] prev_priv;
    bit [31:0] prev_mie_csr;
    bit prev_nmi_mode;

    wait (dut_vif.reset === 1'b0);
    #1step;

    prev_mie      = dut_vif.mstatus_mie;
    prev_mpie     = dut_vif.mstatus_mpie;
    prev_mpp      = dut_vif.mstatus_mpp;
    prev_priv     = dut_vif.priv_mode;
    prev_mie_csr  = dut_vif.mie;
    prev_nmi_mode = dut_vif.nmi_mode;

    forever begin
      bit save_evt;
      bit mret_evt;
      bit debug_mode_evt;
      bit debug_csr_save_evt;
      ibex_pkg::exc_cause_t cause_evt;
      bit [31:0] mtvec_evt;
      bit [31:0] target_evt;
      bit [31:0] mtval_in_evt;
      bit [31:0] mepc_exp;
      bit post_mie;
      bit post_mpie;
      bit [1:0] post_mpp;
      bit [1:0] post_priv;
      int expected_id;

      clk_vif.wait_n_clks(1);

      save_evt           = dut_vif.dut_cb.csr_save_cause;
      mret_evt           = dut_vif.dut_cb.csr_restore_mret;
      debug_mode_evt     = dut_vif.dut_cb.debug_mode;
      debug_csr_save_evt = dut_vif.dut_cb.debug_csr_save;
      cause_evt          = dut_vif.dut_cb.exc_cause;
      mtvec_evt          = dut_vif.dut_cb.mtvec;
      target_evt         = dut_vif.dut_cb.exc_pc;
      mtval_in_evt       = dut_vif.dut_cb.csr_mtval;
      mepc_exp           = expected_mepc();

      #1step;

      if (dut_vif.reset) begin
        prev_mie      = dut_vif.mstatus_mie;
        prev_mpie     = dut_vif.mstatus_mpie;
        prev_mpp      = dut_vif.mstatus_mpp;
        prev_priv     = dut_vif.priv_mode;
        prev_mie_csr  = dut_vif.mie;
        prev_nmi_mode = dut_vif.nmi_mode;
        nesting_depth = 0;
        continue;
      end

      check_mip();

      post_mie  = dut_vif.mstatus_mie;
      post_mpie = dut_vif.mstatus_mpie;
      post_mpp  = dut_vif.mstatus_mpp;
      post_priv = dut_vif.priv_mode;

      if (save_evt && !debug_csr_save_evt && !debug_mode_evt) begin
        bit is_irq;
        bit is_nmi;

        trap_count++;
        nesting_depth++;
        is_irq = cause_evt.irq_ext | cause_evt.irq_int;
        is_nmi = is_irq && ((cause_evt.lower_cause == 5'd31) || cause_evt.irq_int);

        if (post_mie !== 1'b0)
          `uvm_error("TRAP_MSTATUS", "Trap entry did not clear MIE")
        if (post_mpie !== prev_mie)
          `uvm_error("TRAP_MSTATUS",
            $sformatf("MPIE mismatch exp=%0b act=%0b", prev_mie, post_mpie))
        if (post_mpp !== prev_priv)
          `uvm_error("TRAP_MSTATUS",
            $sformatf("MPP mismatch exp=%0h act=%0h", prev_priv, post_mpp))
        if (post_priv !== ibex_pkg::PRIV_LVL_M)
          `uvm_error("TRAP_PRIV",
            $sformatf("Trap did not enter M-mode, priv=%0h", post_priv))

        if (dut_vif.mcause !== encode_cause(cause_evt))
          `uvm_error("TRAP_MCAUSE",
            $sformatf("mcause mismatch exp=%08x act=%08x",
                      encode_cause(cause_evt), dut_vif.mcause))

        if (dut_vif.mepc !== mepc_exp)
          `uvm_error("TRAP_MEPC",
            $sformatf("mepc mismatch exp=%08x act=%08x save_if/id/wb=%0b%0b%0b",
                      mepc_exp, dut_vif.mepc,
                      dut_vif.dut_cb.csr_save_if,
                      dut_vif.dut_cb.csr_save_id,
                      dut_vif.dut_cb.csr_save_wb))
        else
          mepc_check_count++;

        if (dut_vif.mtval !== mtval_in_evt)
          `uvm_error("TRAP_MTVAL",
            $sformatf("mtval capture mismatch exp=%08x act=%08x cause=%0d",
                      mtval_in_evt, dut_vif.mtval, cause_evt.lower_cause))
        else
          mtval_check_count++;

        if ((is_irq || cause_evt.lower_cause inside {5'd3, 5'd8, 5'd11}) &&
            dut_vif.mtval !== 32'h0)
          `uvm_error("TRAP_MTVAL",
            $sformatf("mtval must be zero for cause %0d, got %08x",
                      cause_evt.lower_cause, dut_vif.mtval))

        if (target_evt !== expected_trap_pc(cause_evt, mtvec_evt))
          `uvm_error("TRAP_VECTOR",
            $sformatf("trap target mismatch exp=%08x act=%08x mtvec=%08x cause=%0d irq=%0b",
                      expected_trap_pc(cause_evt, mtvec_evt), target_evt,
                      mtvec_evt, cause_evt.lower_cause, is_irq))
        else
          vector_check_count++;

        if (dut_vif.mtvec[7:0] !== 8'h01)
          `uvm_error("TRAP_MTVEC",
            $sformatf("Ibex mtvec low byte must be 01, got %08x", dut_vif.mtvec))

        if (dut_vif.mepc[0] !== 1'b0)
          `uvm_error("TRAP_MEPC",
            $sformatf("mepc[0] must be zero, got %08x", dut_vif.mepc))

        cov_is_irq        = is_irq;
        cov_cause         = is_nmi ? 31 : cause_evt.lower_cause;
        cov_priv          = prev_priv;
        cov_old_mie       = prev_mie;
        cov_depth         = nesting_depth;
        cov_pending_count = enabled_pending_count(prev_mie_csr);
        cov_mtval_zero    = (dut_vif.mtval == 32'h0);
        cov_nmi_mode      = prev_nmi_mode;
        trap_cg.sample();

        if (is_irq) begin
          irq_trap_count++;

          if (!is_nmi) begin
            if (!prev_mie_csr[cause_evt.lower_cause])
              `uvm_error("TRAP_IRQ_MASK",
                $sformatf("Maskable IRQ %0d taken with mie bit clear",
                          cause_evt.lower_cause))

            if (!(prev_mie || prev_priv == ibex_pkg::PRIV_LVL_U))
              `uvm_error("TRAP_IRQ_MASK",
                $sformatf("Maskable IRQ %0d taken with global interrupt disabled in M-mode",
                          cause_evt.lower_cause))
          end

          if (is_nmi && prev_nmi_mode)
            `uvm_error("TRAP_NMI_NEST", "Nested NMI was accepted while already in NMI mode")

          expected_id = expected_irq_id(prev_mie_csr);
          if ((expected_id >= 0) &&
              ((is_nmi ? 31 : cause_evt.lower_cause) != expected_id[4:0])) begin
            `uvm_error("TRAP_IRQ_PRIORITY",
              $sformatf("IRQ selected id=%0d expected=%0d fast=%04x ext=%0b sw=%0b timer=%0b nmi=%0b mie=%08x",
                        is_nmi ? 31 : cause_evt.lower_cause, expected_id,
                        irq_vif.irq_fast, irq_vif.irq_external,
                        irq_vif.irq_software, irq_vif.irq_timer,
                        irq_vif.irq_nm, prev_mie_csr))
          end
        end else begin
          exception_count++;
        end
      end

      if (mret_evt && !debug_mode_evt) begin
        mret_count++;
        if (post_mie !== prev_mpie)
          `uvm_error("TRAP_MRET",
            $sformatf("MRET MIE restore mismatch exp=%0b act=%0b", prev_mpie, post_mie))
        if (post_priv !== prev_mpp)
          `uvm_error("TRAP_MRET",
            $sformatf("MRET privilege restore mismatch exp=%0h act=%0h", prev_mpp, post_priv))
        if (nesting_depth > 0) nesting_depth--;
      end

      prev_mie      = post_mie;
      prev_mpie     = post_mpie;
      prev_mpp      = post_mpp;
      prev_priv     = post_priv;
      prev_mie_csr  = dut_vif.mie;
      prev_nmi_mode = dut_vif.nmi_mode;
    end
  endtask

  task run_phase(uvm_phase phase);
    fork
      consume_rvfi();
      monitor_trap_state();
    join
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("TRAP_SUMMARY",
      $sformatf("traps=%0d irq=%0d exception=%0d mret=%0d rvfi_traps=%0d mepc_checks=%0d mtval_checks=%0d vector_checks=%0d coverage=%0.2f%%",
                trap_count, irq_trap_count, exception_count, mret_count,
                rvfi_trap_count, mepc_check_count, mtval_check_count,
                vector_check_count, trap_cg.get_inst_coverage()),
      UVM_LOW)
  endfunction

endclass : ibex_trap_scoreboard
