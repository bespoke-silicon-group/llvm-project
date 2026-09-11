; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -debug-pass=Structure \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=HB
; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 -debug-pass=Structure \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=GENERIC
;
; HammerBlade's static backward-taken/forward-not-taken predictor favors the
; natural SelectionDAG loop layout for branch-dense functions. Keep machine
; block placement in the pipeline so the hb-rv32 subtarget can retain it for
; large or instruction-dense functions. Standard RISC-V always enables it.
;
; HB: RISCV DAG->DAG Pattern Instruction Selection
; HB: Branch Probability Basic Block Placement
; GENERIC: Branch Probability Basic Block Placement

define void @empty() {
entry:
  ret void
}
