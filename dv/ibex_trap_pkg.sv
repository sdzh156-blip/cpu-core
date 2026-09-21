`include "uvm_macros.svh"

package ibex_trap_pkg;

  import uvm_pkg::*;
  import ibex_pkg::*;
  import core_ibex_env_pkg::*;
  import core_ibex_test_pkg::*;
  import ibex_cosim_agent_pkg::*;
  import irq_agent_pkg::*;

  `include "seq/ibex_trap_irq_seq.sv"
  `include "scoreboard/ibex_trap_scoreboard.sv"
  `include "env/ibex_trap_env.sv"
  `include "tests/ibex_trap_tests.sv"

endpackage : ibex_trap_pkg
