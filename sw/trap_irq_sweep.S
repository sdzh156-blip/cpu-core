#include "riscv_test.h"
#include "test_macros.h"

#define TEST_CTRL_ADDR 0x8ffffff8
#define TEST_PASS_WORD 0x00000001
#define TEST_FAIL_WORD 0x00000101
#define ALL_MASKABLE_IRQS 0x7fff0888

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la   t0, irq_vector_table
  ori  t0, t0, 1
  csrw mtvec, t0

  li   t0, ALL_MASKABLE_IRQS
  csrw mie, t0
  li   t0, 8
  csrs mstatus, t0

main_wait:
  la   t0, irq_count
  lw   t1, 0(t0)
  li   t2, 19
  beq  t1, t2, irq_pass
  wfi
  j main_wait

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
  la   t0, irq_count
  lw   t1, 0(t0)
  addi t1, t1, 1
  sw   t1, 0(t0)

  # Give the UVM side time to deassert the level-sensitive source.
  li   t2, 64
1:
  addi t2, t2, -1
  bnez t2, 1b
  mret

irq_unexpected:
  j irq_fail

irq_pass:
  li   t0, TEST_CTRL_ADDR
  li   t1, TEST_PASS_WORD
  sw   t1, 0(t0)
2:
  wfi
  j 2b

irq_fail:
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
