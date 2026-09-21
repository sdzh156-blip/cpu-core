#include "riscv_test.h"
#include "test_macros.h"

#define TEST_CTRL_ADDR 0x8ffffff8
#define TEST_PASS_WORD 0x00000001
#define TEST_FAIL_WORD 0x00000101

RVTEST_RV32M
RVTEST_CODE_BEGIN

  # Program mtvec with deliberately dirty low bits. Ibex must retain vectored
  # mode and a 256-byte-aligned base, so the low byte reads back as 0x01.
  la   t0, trap_handler
  ori  t0, t0, 0xff
  csrw mtvec, t0
  csrr t1, mtvec
  andi t2, t1, 0xff
  li   t3, 1
  bne  t2, t3, trap_fail

  # M-mode ECALL: cause=11, mtval=0.
  ecall
  la   t0, last_mcause
  lw   t1, 0(t0)
  li   t2, 11
  bne  t1, t2, trap_fail
  la   t0, last_mtval
  lw   t1, 0(t0)
  bnez t1, trap_fail

  # EBREAK exception: cause=3, mtval=0 when DCSR ebreakm is clear.
  ebreak
  la   t0, last_mcause
  lw   t1, 0(t0)
  li   t2, 3
  bne  t1, t2, trap_fail
  la   t0, last_mtval
  lw   t1, 0(t0)
  bnez t1, trap_fail

  # Illegal 32-bit instruction: cause=2, mtval contains the instruction bits.
illegal_site:
  .word 0xffffffff
  la   t0, last_mcause
  lw   t1, 0(t0)
  li   t2, 2
  bne  t1, t2, trap_fail
  la   t0, last_mtval
  lw   t1, 0(t0)
  li   t2, -1
  bne  t1, t2, trap_fail

  # Enter U-mode and deliberately execute ECALL. The handler redirects this
  # particular trap back to machine_resume in M-mode.
  la   t0, user_ecall
  csrw mepc, t0
  csrr t1, mstatus
  li   t2, 0xffffe7ff
  and  t1, t1, t2
  csrw mstatus, t1
  mret

machine_resume:
  la   t0, last_mcause
  lw   t1, 0(t0)
  li   t2, 8
  bne  t1, t2, trap_fail
  la   t0, last_mtval
  lw   t1, 0(t0)
  bnez t1, trap_fail
  j trap_pass

user_ecall:
  ecall
  j trap_fail

.balign 256
trap_handler:
  csrr t0, mcause
  la   t1, last_mcause
  sw   t0, 0(t1)
  csrr t0, mtval
  la   t1, last_mtval
  sw   t0, 0(t1)

  csrr t0, mcause
  li   t1, 8
  beq  t0, t1, return_u_ecall_to_m

  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

return_u_ecall_to_m:
  la   t0, machine_resume
  csrw mepc, t0
  csrr t1, mstatus
  li   t2, 0x1800
  or   t1, t1, t2
  csrw mstatus, t1
  mret

trap_pass:
  li   t0, TEST_CTRL_ADDR
  li   t1, TEST_PASS_WORD
  sw   t1, 0(t0)
1:
  wfi
  j 1b

trap_fail:
  li   t0, TEST_CTRL_ADDR
  li   t1, TEST_FAIL_WORD
  sw   t1, 0(t0)
2:
  wfi
  j 2b

RVTEST_CODE_END

.data
.balign 4
last_mcause: .word 0
last_mtval:  .word 0
