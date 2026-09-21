class ibex_trap_scoreboard extends uvm_scoreboard;

  localparam string CORE_PATH =
      "core_ibex_tb_top.dut.u_ibex_top.u_ibex_core";

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

  bit          cov_is_irq;
  int unsigned cov_cause;
  bit [1:0]    cov_priv;
  bit          cov_old_mie;
  int unsigned cov_depth;
  int unsigned cov_pending_count;

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
      bins one   = {1};
      bins multi = {[2:19]};
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

    if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_if", clk_vif)) begin
      `uvm_fatal(get_type_name(), "Cannot get clk_if")
    end

    if (!uvm_config_db#(virtual core_ibex_dut_probe_if)::get(
          this, "", "dut_if", dut_vif)) begin
      `uvm_fatal(get_type_name(), "Cannot get dut_if")
    end

    if (!uvm_config_db#(virtual irq_if)::get(this, "", "vif", irq_vif)) begin
      `uvm_fatal(get_type_name(), "Cannot get irq vif")
    end
  endfunction

  function automatic bit read_hdl(string relative_path,
                                  output uvm_hdl_data_t value);
    string path = {CORE_PATH, ".", relative_path};
    if (!uvm_hdl_read(path, value)) begin
      `uvm_error(get_type_name(), $sformatf("uvm_hdl_read failed: %s", path))
      value = 'x;
      return 1'b0;
    end
    return 1'b1;
  endfunction

  function automatic bit read_bit(string relative_path);
    uvm_hdl_data_t v;
    void'(read_hdl(relative_path, v));
    return v[0];
  endfunction

  function automatic bit [1:0] read_priv(string relative_path);
    uvm_hdl_data_t v;
    void'(read_hdl(relative_path, v));
    return v[1:0];
  endfunction

  function automatic bit [31:0] read_word(string relative_path);
    uvm_hdl_data_t v;
    void'(read_hdl(relative_path, v));
    return v[31:0];
  endfunction

  function automatic bit [31:0] read_irq_csr(string csr_name);
    bit [31:0] value;
    value = '0;

    value[3] = read_bit({csr_name, ".irq_software"});
    value[7] = read_bit({csr_name, ".irq_timer"});
    value[11] = read_bit({csr_name, ".irq_external"});

    for (int i = 0; i < 15; i++) begin
      uvm_hdl_data_t fast_v;
      string path = $sformatf("%s.irq_fast[%0d]", csr_name, i);
      void'(read_hdl(path, fast_v));
      value[16+i] = fast_v[0];
    end

    return value;
  endfunction

  function automatic bit [31:0] read_mcause();
    bit [31:0] cause;
    bit irq_ext, irq_int;
    uvm_hdl_data_t lower;

    irq_ext = read_bit("cs_registers_i.mcause_q.irq_ext");
    irq_int = read_bit("cs_registers_i.mcause_q.irq_int");
    void'(read_hdl("cs_registers_i.mcause_q.lower_cause", lower));

    cause = '0;
    cause[31] = irq_ext | irq_int;
    if (irq_int) cause[30:5] = '1;
    cause[4:0] = lower[4:0];
    return cause;
  endfunction

  function automatic bit [31:0] encode_cause(ibex_pkg::exc_cause_t cause);
    bit [31:0] value = '0;
    value[31] = cause.irq_ext | cause.irq_int;
    if (cause.irq_int) value[30:5] = '1;
    value[4:0] = cause.lower_cause;
    return value;
  endfunction

  function automatic int unsigned pending_count(bit [31:0] mie);
    int unsigned n = 0;
    n += irq_vif.irq_nm;
    n += irq_vif.irq_software & mie[3];
    n += irq_vif.irq_timer & mie[7];
    n += irq_vif.irq_external & mie[11];
    for (int i = 0; i < 15; i++) n += irq_vif.irq_fast[i] & mie[16+i];
    return n;
  endfunction

  function automatic int expected_irq_id(bit [31:0] mie);
    // Ibex documented priority: NMI > fast IRQs > external > software > timer.
    // Fast IRQ priority is lowest interrupt ID first.
    if (irq_vif.irq_nm) return 31;

    for (int i = 0; i < 15; i++) begin
      if (irq_vif.irq_fast[i] && mie[16+i]) return 16+i;
    end

    if (irq_vif.irq_external && mie[11]) return 11;
    if (irq_vif.irq_software && mie[3]) return 3;
    if (irq_vif.irq_timer && mie[7]) return 7;

    return -1;
  endfunction

  task automatic consume_rvfi();
    ibex_rvfi_seq_item item;
    forever begin
      rvfi_fifo.get(item);
      if (item.trap) rvfi_trap_count++;
    end
  endtask

  task automatic check_mip(bit [31:0] mie, bit [31:0] mip);
    bit [31:0] expected;
    expected = '0;
    // Ibex mip is a purely combinational pending mirror.  It is intentionally
    // independent of mie; mie is applied later by interrupt enable/arbitration.
    expected[3]  = irq_vif.irq_software;
    expected[7]  = irq_vif.irq_timer;
    expected[11] = irq_vif.irq_external;

    for (int i = 0; i < 15; i++) begin
      expected[16+i] = irq_vif.irq_fast[i];
    end

    if ((mip & 32'h7fff_0888) !== (expected & 32'h7fff_0888)) begin
      `uvm_error("TRAP_MIP",
        $sformatf("mip mismatch exp=%08x act=%08x mie=%08x",
                  expected, mip, mie))
    end
  endtask

  task automatic monitor_trap_state();
    bit prev_mie;
    bit prev_mpie;
    bit [1:0] prev_mpp;
    bit [1:0] prev_priv;
    bit [31:0] prev_mie_csr;

    wait (dut_vif.reset === 1'b0);
    #1step;

    prev_mie     = read_bit("cs_registers_i.mstatus_q.mie");
    prev_mpie    = read_bit("cs_registers_i.mstatus_q.mpie");
    prev_mpp     = read_priv("cs_registers_i.mstatus_q.mpp");
    prev_priv    = read_priv("cs_registers_i.priv_lvl_q");
    prev_mie_csr = read_irq_csr("cs_registers_i.mie_q");

    forever begin
      bit save_evt;
      bit mret_evt;
      bit debug_mode_evt;
      bit debug_csr_save_evt;
      ibex_pkg::exc_cause_t cause_evt;

      bit post_mie;
      bit post_mpie;
      bit [1:0] post_mpp;
      bit [1:0] post_priv;
      bit [31:0] post_mie_csr;
      bit [31:0] post_mip;
      bit [31:0] post_mcause;
      bit [31:0] post_mepc;
      bit [31:0] post_mtvec;
      int expected_id;

      clk_vif.wait_n_clks(1);

      save_evt           = dut_vif.csr_save_cause;
      mret_evt           = read_bit("csr_restore_mret_id");
      debug_mode_evt     = dut_vif.debug_mode;
      debug_csr_save_evt = read_bit("debug_csr_save");
      cause_evt          = dut_vif.exc_cause;

      #1step;

      if (dut_vif.reset) begin
        prev_mie     = read_bit("cs_registers_i.mstatus_q.mie");
        prev_mpie    = read_bit("cs_registers_i.mstatus_q.mpie");
        prev_mpp     = read_priv("cs_registers_i.mstatus_q.mpp");
        prev_priv    = read_priv("cs_registers_i.priv_lvl_q");
        prev_mie_csr = read_irq_csr("cs_registers_i.mie_q");
        nesting_depth = 0;
        continue;
      end

      post_mie     = read_bit("cs_registers_i.mstatus_q.mie");
      post_mpie    = read_bit("cs_registers_i.mstatus_q.mpie");
      post_mpp     = read_priv("cs_registers_i.mstatus_q.mpp");
      post_priv    = read_priv("cs_registers_i.priv_lvl_q");
      post_mie_csr = read_irq_csr("cs_registers_i.mie_q");
      post_mip     = read_irq_csr("cs_registers_i.mip");

      check_mip(post_mie_csr, post_mip);

      if (save_evt && !debug_csr_save_evt && !debug_mode_evt) begin
        trap_count++;
        nesting_depth++;

        post_mcause = read_mcause();
        post_mepc   = read_word("cs_registers_i.mepc_q");
        post_mtvec  = read_word("cs_registers_i.mtvec_q");

        if (post_mie !== 1'b0) begin
          `uvm_error("TRAP_MSTATUS",
            $sformatf("Trap entry did not clear MIE: %0b", post_mie))
        end

        if (post_mpie !== prev_mie) begin
          `uvm_error("TRAP_MSTATUS",
            $sformatf("MPIE mismatch exp(old MIE)=%0b act=%0b",
                      prev_mie, post_mpie))
        end

        if (post_mpp !== prev_priv) begin
          `uvm_error("TRAP_MSTATUS",
            $sformatf("MPP mismatch exp(old priv)=%0h act=%0h",
                      prev_priv, post_mpp))
        end

        if (post_priv !== ibex_pkg::PRIV_LVL_M) begin
          `uvm_error("TRAP_PRIV",
            $sformatf("Trap did not enter M-mode: priv=%0h", post_priv))
        end

        if (post_mcause !== encode_cause(cause_evt)) begin
          `uvm_error("TRAP_MCAUSE",
            $sformatf("mcause mismatch exp=%08x act=%08x",
                      encode_cause(cause_evt), post_mcause))
        end

        if (post_mtvec[7:0] !== 8'h01) begin
          `uvm_error("TRAP_MTVEC",
            $sformatf("Ibex mtvec low byte must be 0x01, got %08x",
                      post_mtvec))
        end

        if (post_mepc[0] !== 1'b0) begin
          `uvm_error("TRAP_MEPC",
            $sformatf("mepc[0] must be zero, got %08x", post_mepc))
        end

        cov_is_irq        = cause_evt.irq_ext | cause_evt.irq_int;
        cov_cause         = cause_evt.lower_cause;
        cov_priv          = prev_priv;
        cov_old_mie       = prev_mie;
        cov_depth         = nesting_depth;
        cov_pending_count = pending_count(prev_mie_csr);
        trap_cg.sample();

        if (cov_is_irq) begin
          irq_trap_count++;
          expected_id = expected_irq_id(prev_mie_csr);

          // If the pins still represent the accepted request, cross-check priority.
          // For a level-sensitive source that software already cleared, expected_id can be -1.
          if ((expected_id >= 0) &&
              (cause_evt.lower_cause != expected_id[4:0])) begin
            `uvm_error("TRAP_IRQ_PRIORITY",
              $sformatf("IRQ selected id=%0d expected=%0d raw fast=%04x ext=%0b sw=%0b timer=%0b nmi=%0b mie=%08x",
                        cause_evt.lower_cause, expected_id,
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

        if (post_mie !== prev_mpie) begin
          `uvm_error("TRAP_MRET",
            $sformatf("MRET MIE restore mismatch exp=%0b act=%0b",
                      prev_mpie, post_mie))
        end

        if (post_priv !== prev_mpp) begin
          `uvm_error("TRAP_MRET",
            $sformatf("MRET privilege restore mismatch exp=%0h act=%0h",
                      prev_mpp, post_priv))
        end

        if (nesting_depth > 0) nesting_depth--;
      end

      prev_mie     = post_mie;
      prev_mpie    = post_mpie;
      prev_mpp     = post_mpp;
      prev_priv    = post_priv;
      prev_mie_csr = post_mie_csr;
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
      $sformatf("traps=%0d irq=%0d exception=%0d mret=%0d rvfi_traps=%0d coverage=%0.2f%%",
                trap_count, irq_trap_count, exception_count, mret_count,
                rvfi_trap_count, trap_cg.get_inst_coverage()),
      UVM_LOW)
  endfunction

endclass : ibex_trap_scoreboard
