; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -verify-each | FileCheck %s --check-prefix=HB
; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -unroll-count=2 -unroll-runtime=true -verify-each | FileCheck %s --check-prefix=EXPLICIT
; RUN: opt %s -S -mtriple=riscv32 -mcpu=generic-rv32 -passes=loop-unroll -unroll-count=2 -unroll-runtime=true -verify-each | FileCheck %s --check-prefix=EXPLICIT
; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -unroll-runtime=false -verify-each | FileCheck %s --check-prefix=OFF
;
; A target preference for retained exit checks applies to automatic choices,
; not an explicit command-line request for runtime main/remainder unrolling.
; Other CPUs retain the previous default form.

; HB-LABEL: define void @stream(
; HB: loop:
; HB-COUNT-2: load i32
; HB: br i1
; HB: loop.1:
; HB-COUNT-2: load i32
; HB: br i1
; HB-NOT: epil
; HB: ret void
; EXPLICIT-LABEL: define void @stream(
; EXPLICIT: loop:
; EXPLICIT-COUNT-4: load i32
; EXPLICIT: br i1
; EXPLICIT: epil
; OFF-LABEL: define void @stream(
; OFF: loop:
; OFF-COUNT-2: load i32
; OFF-NOT: load
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
  %z = add i32 %x, %y
  store i32 %z, ptr %cp
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
