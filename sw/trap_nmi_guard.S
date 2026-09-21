#include "riscv_test.h"
#include "test_macros.h"

#define TEST_CTRL_ADDR 0x8ffffff8
#define TEST_PASS_WORD 0x00000001
#define TEST_FAIL_WORD 0x00000101
#define MSTATUS_MIE 0x00000008

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la   t0, irq_vector_table
  ori  t0, t0, 1
  csrw mtvec, t0

  csrw mie, zero
  li   t0, MSTATUS_MIE
  csrc mstatus, t0

nmi_wait:
  la   t0, irq_count
  lw   t1, 0(t0)
  li   t2, 1
  beq  t1, t2, nmi_pass
  wfi
  j nmi_wait

.balign 256
irq_vector_table:
  j irq_unexpected
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler
  j irq_handler

irq_handler:
  csrr t0, mcause
  li   t1, 0x8000001f
  bne  t0, t1, nmi_fail

  la   t0, irq_count
  lw   t1, 0(t0)
  addi t1, t1, 1
  sw   t1, 0(t0)

  # Stay in the NMI handler long enough for the UVM test to keep irq_nm high
  # and prove that a nested NMI is not accepted.
  li   t2, 500
1:
  addi t2, t2, -1
  bnez t2, 1b
  mret

irq_unexpected:
  j nmi_fail

nmi_pass:
  li   t0, TEST_CTRL_ADDR
  li   t1, TEST_PASS_WORD
  sw   t1, 0(t0)
2:
  wfi
  j 2b

nmi_fail:
  li   t0, TEST_CTRL_ADDR
  li   t1, TEST_FAIL_WORD
  sw   t1, 0(t0)
3:
  wfi
  j 3b

RVTEST_CODE_END

.data
.balign 4
irq_count: .word 0
