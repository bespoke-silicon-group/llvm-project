; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -debug-pass=Structure \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=HB
; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 -debug-pass=Structure \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=GENERIC
;
; HammerBlade's static backward-taken/forward-not-taken predictor favors the
; natural SelectionDAG loop layout. Disable generic machine block placement
; only for hb-rv32; standard RISC-V targets retain the pass.
;
; HB: RISCV DAG->DAG Pattern Instruction Selection
; HB-NOT: Branch Probability Basic Block Placement
; GENERIC: Branch Probability Basic Block Placement

define void @empty() {
entry:
  ret void
}
