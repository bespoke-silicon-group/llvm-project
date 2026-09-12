; RUN: opt -mtriple=riscv32 -mcpu=hb-rv32 -passes='print<cost-model>' -disable-output < %s 2>&1 | FileCheck %s --check-prefixes=HB,THROUGHPUT
; RUN: opt -mtriple=riscv32 -mcpu=hb-rv32 -cost-kind=latency -passes='print<cost-model>' -disable-output < %s 2>&1 | FileCheck %s --check-prefixes=HB,LATENCY
; RUN: opt -mtriple=riscv32 -mcpu=hb-rv32 -cost-kind=code-size -passes='print<cost-model>' -disable-output < %s 2>&1 | FileCheck %s --check-prefix=SIZE
; RUN: opt -mtriple=riscv32 -mcpu=generic-rv32 -mattr=+m -passes='print<cost-model>' -disable-output < %s 2>&1 | FileCheck %s --check-prefix=GENERIC

; Model native variable div/rem using the same iterative-divider latency as
; machine scheduling. Constants and code-size queries retain generic costing.
define i32 @costs(i32 %a, i32 %b) {
; HB: cost of 42 for instruction: %sd = sdiv
; HB: cost of 42 for instruction: %ud = udiv
; HB: cost of 42 for instruction: %sr = srem
; HB: cost of 42 for instruction: %ur = urem
; SIZE: cost of 4 for instruction: %sd = sdiv
; SIZE: cost of 4 for instruction: %ud = udiv
; SIZE: cost of 4 for instruction: %sr = srem
; SIZE: cost of 4 for instruction: %ur = urem
; GENERIC: cost of 1 for instruction: %sd = sdiv
; GENERIC: cost of 1 for instruction: %ud = udiv
; GENERIC: cost of 1 for instruction: %sr = srem
; GENERIC: cost of 1 for instruction: %ur = urem
  %sd = sdiv i32 %a, %b
  %ud = udiv i32 %a, %b
  %sr = srem i32 %a, %b
  %ur = urem i32 %a, %b
; THROUGHPUT: cost of 1 for instruction: %pow2 = udiv
; LATENCY: cost of 4 for instruction: %pow2 = udiv
; SIZE: cost of 4 for instruction: %pow2 = udiv
; GENERIC: cost of 1 for instruction: %pow2 = udiv
  %pow2 = udiv i32 %a, 8
  ret i32 %pow2
}
