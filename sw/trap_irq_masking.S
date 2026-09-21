#include "riscv_test.h"
#include "test_macros.h"

#define TEST_CTRL_ADDR 0x8ffffff8
#define TEST_PASS_WORD 0x00000001
#define TEST_FAIL_WORD 0x00000101
#define MEIE 0x00000800
#define MSTATUS_MIE 0x00000008

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la   t0, irq_vector_table
  ori  t0, t0, 1
  csrw mtvec, t0

  # Phase A: external interrupt locally enabled, global MIE disabled.
  li   t0, MEIE
  csrw mie, t0
  li   t0, MSTATUS_MIE
  csrc mstatus, t0

  li   t0, 2000
1:
  addi t0, t0, -1
  bnez t0, 1b

  li   t0, MSTATUS_MIE
  csrs mstatus, t0

wait_first:
  la   t0, irq_count
  lw   t1, 0(t0)
  li   t2, 1
  bne  t1, t2, wait_first

  # Phase B: global MIE enabled, external interrupt locally disabled.
  li   t0, MEIE
  csrc mie, t0

  li   t0, 2000
2:
  addi t0, t0, -1
  bnez t0, 2b

  li   t0, MEIE
  csrs mie, t0

wait_second:
  la   t0, irq_count
  lw   t1, 0(t0)
  li   t2, 2
  bne  t1, t2, wait_second
  j irq_pass

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
  li   t1, 0x8000000b
  bne  t0, t1, irq_fail

  la   t0, irq_count
  lw   t1, 0(t0)
  addi t1, t1, 1
  sw   t1, 0(t0)

  li   t2, 64
3:
  addi t2, t2, -1
  bnez t2, 3b
  mret

irq_unexpected:
  j irq_fail

irq_pass:
  li   t0, TEST_CTRL_ADDR
  li   t1, TEST_PASS_WORD
  sw   t1, 0(t0)
4:
  wfi
  j 4b

irq_fail:
  li   t0, TEST_CTRL_ADDR
  li   t1, TEST_FAIL_WORD
  sw   t1, 0(t0)
5:
  wfi
  j 5b

RVTEST_CODE_END

.data
.balign 4
irq_count: .word 0
