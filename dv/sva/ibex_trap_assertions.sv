module ibex_trap_assertions import ibex_pkg::*; (
  input logic        clk_i,
  input logic        rst_ni,
  input logic        csr_save_cause,
  input logic        csr_restore_mret_id,
  input logic        debug_csr_save,
  input logic        debug_mode,
  input logic        mstatus_mie,
  input logic        mstatus_mpie,
  input logic [1:0]  mstatus_mpp,
  input logic [1:0]  priv_lvl,
  input logic [31:0] mtvec,
  input logic [31:0] mepc,
  input logic        irq_software,
  input logic        irq_timer,
  input logic        irq_external,
  input logic [14:0] irq_fast,
  input logic        irq_nm,
  input logic        mip_software,
  input logic        mip_timer,
  input logic        mip_external,
  input logic [14:0] mip_fast,
  input logic        nmi_mode,
  input logic        new_nmi
);

  default clocking cb @(posedge clk_i); endclocking
  default disable iff (!rst_ni);

  a_mtvec_vectored_aligned:
    assert property (mtvec[7:0] == 8'h01);

  a_mepc_bit0_zero:
    assert property (mepc[0] == 1'b0);

  a_priv_legal:
    assert property (priv_lvl inside {PRIV_LVL_U, PRIV_LVL_M});

  a_trap_clears_mie:
    assert property ((csr_save_cause && !debug_csr_save && !debug_mode) |=> !mstatus_mie);

  a_trap_saves_mie_to_mpie:
    assert property ((csr_save_cause && !debug_csr_save && !debug_mode) |=>
                     mstatus_mpie == $past(mstatus_mie));

  a_trap_saves_priv_to_mpp:
    assert property ((csr_save_cause && !debug_csr_save && !debug_mode) |=>
                     mstatus_mpp == $past(priv_lvl));

  a_trap_enters_machine:
    assert property ((csr_save_cause && !debug_csr_save && !debug_mode) |=>
                     priv_lvl == PRIV_LVL_M);

  a_mret_restores_mie:
    assert property (csr_restore_mret_id |=> mstatus_mie == $past(mstatus_mpie));

  a_mret_restores_priv:
    assert property (csr_restore_mret_id |=> priv_lvl == $past(mstatus_mpp));

  // mip is raw level-sensitive pending state. It is not gated by mie.
  a_mip_software_raw: assert property (mip_software == irq_software);
  a_mip_timer_raw:    assert property (mip_timer    == irq_timer);
  a_mip_external_raw: assert property (mip_external == irq_external);
  a_mip_fast_raw:     assert property (mip_fast     == irq_fast);

  // Once NMI mode is active, a still-asserted external NMI level must not create a new NMI.
  a_no_nested_nmi:
    assert property ((nmi_mode && irq_nm) |-> !new_nmi);

endmodule

bind ibex_core ibex_trap_assertions u_ibex_trap_assertions (
  .clk_i               (clk_i),
  .rst_ni              (rst_ni),
  .csr_save_cause      (csr_save_cause),
  .csr_restore_mret_id (csr_restore_mret_id),
  .debug_csr_save      (debug_csr_save),
  .debug_mode          (id_stage_i.controller_i.debug_mode_q),
  .mstatus_mie         (cs_registers_i.mstatus_q.mie),
  .mstatus_mpie        (cs_registers_i.mstatus_q.mpie),
  .mstatus_mpp         (cs_registers_i.mstatus_q.mpp),
  .priv_lvl            (cs_registers_i.priv_lvl_q),
  .mtvec               (cs_registers_i.mtvec_q),
  .mepc                (cs_registers_i.mepc_q),
  .irq_software        (irq_software_i),
  .irq_timer           (irq_timer_i),
  .irq_external        (irq_external_i),
  .irq_fast            (irq_fast_i),
  .irq_nm              (irq_nm_i),
  .mip_software        (cs_registers_i.mip.irq_software),
  .mip_timer           (cs_registers_i.mip.irq_timer),
  .mip_external        (cs_registers_i.mip.irq_external),
  .mip_fast            (cs_registers_i.mip.irq_fast),
  .nmi_mode            (nmi_mode),
  .new_nmi             (new_nmi)
);
