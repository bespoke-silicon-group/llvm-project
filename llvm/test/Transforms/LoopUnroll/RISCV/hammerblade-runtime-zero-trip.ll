; RUN: opt -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -verify-each -S %s -o - | FileCheck %s
; RUN: opt -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -hb-runtime-memory-unroll=false -verify-each -S %s -o - | FileCheck %s --check-prefix=OFF

; No noalias or overflow promises: overlapping buffers and loop-carried memory
; dependencies remain legal. Preserve the explicit zero-trip exit. An unknown
; count gets two copies with each original exit check, without a remainder.
; Differential execution covers lengths 0-9 and factor/promotion boundaries.
; CHECK-LABEL: define void @stream(
; CHECK: %zero = icmp eq i32 %n, 0
; CHECK: br i1 %zero, label %exit, label
; CHECK: loop:
; CHECK-COUNT-2: load i32
; CHECK-NOT: load i32
; CHECK: br i1
; CHECK: loop.1:
; CHECK-COUNT-2: load i32
; CHECK-NOT: load i32
; CHECK: br i1
; CHECK-NOT: epil
; CHECK: ret void
; OFF-LABEL: define void @stream(
; OFF: loop:
; OFF-COUNT-2: load i32
; OFF-NOT: load i32
; OFF: ret void

define void @stream(ptr %a, ptr %b, ptr %c, i32 %n) {
entry:
  %zero = icmp eq i32 %n, 0
  br i1 %zero, label %exit, label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %ap = getelementptr i32, ptr %a, i32 %i
  %bp = getelementptr i32, ptr %b, i32 %i
  %cp = getelementptr i32, ptr %c, i32 %i
  %x = load i32, ptr %ap
  %y = load i32, ptr %bp

  %sum = add i32 %x, %y
  store i32 %sum, ptr %cp
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
