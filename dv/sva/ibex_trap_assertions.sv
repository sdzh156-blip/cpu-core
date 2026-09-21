module ibex_trap_assertions (
  input logic        clk_i,
  input logic        rst_ni,
  input logic        csr_save_cause,
  input logic        csr_restore_mret_id,
  input logic        mstatus_mie,
  input logic        mstatus_mpie,
  input logic [1:0]  mstatus_mpp,
  input logic [1:0]  priv_lvl,
  input logic [31:0] mtvec,
  input logic [31:0] mepc
);

  default clocking cb @(posedge clk_i); endclocking
  default disable iff (!rst_ni);

  a_mtvec_vectored_aligned:
    assert property (mtvec[7:0] == 8'h01);

  a_mepc_bit0_zero:
    assert property (mepc[0] == 1'b0);

  a_priv_legal:
    assert property (priv_lvl inside {2'b00, 2'b11});

  a_trap_clears_mie:
    assert property (csr_save_cause |=> !mstatus_mie);

  a_trap_saves_mie_to_mpie:
    assert property (csr_save_cause |=> mstatus_mpie == $past(mstatus_mie));

  a_trap_saves_priv_to_mpp:
    assert property (csr_save_cause |=> mstatus_mpp == $past(priv_lvl));

  a_trap_enters_machine:
    assert property (csr_save_cause |=> priv_lvl == 2'b11);

  a_mret_restores_mie:
    assert property (csr_restore_mret_id |=> mstatus_mie == $past(mstatus_mpie));

  a_mret_restores_priv:
    assert property (csr_restore_mret_id |=> priv_lvl == $past(mstatus_mpp));

endmodule

bind ibex_core ibex_trap_assertions u_ibex_trap_assertions (
  .clk_i               (clk_i),
  .rst_ni              (rst_ni),
  .csr_save_cause      (csr_save_cause),
  .csr_restore_mret_id (csr_restore_mret_id),
  .mstatus_mie         (cs_registers_i.mstatus_q.mie),
  .mstatus_mpie        (cs_registers_i.mstatus_q.mpie),
  .mstatus_mpp         (cs_registers_i.mstatus_q.mpp),
  .priv_lvl            (cs_registers_i.priv_lvl_q),
  .mtvec               (cs_registers_i.mtvec_q),
  .mepc                (cs_registers_i.mepc_q)
);
