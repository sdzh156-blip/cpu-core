class ibex_trap_env extends core_ibex_env;

  ibex_trap_scoreboard trap_scoreboard;

  `uvm_component_utils(ibex_trap_env)
  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    trap_scoreboard = ibex_trap_scoreboard::type_id::create("trap_scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Reuse the official RVFI monitor. Spike still receives the same stream through
    // the official cosim agent; this is an additional subscriber.
    cosim_agent.rvfi_monitor.item_collected_port.connect(
      trap_scoreboard.rvfi_fifo.analysis_export
    );
  endfunction

endclass : ibex_trap_env
