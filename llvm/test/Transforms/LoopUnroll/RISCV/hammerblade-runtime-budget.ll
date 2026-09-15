; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -verify-each | FileCheck %s
; Reject software-width bodies despite small IR size. Do not bypass generic
; short-count vetoes, and do not disable exact full unrolling of small loops.

; CHECK-LABEL: define void @wide_integer(
; CHECK: loop:
; CHECK-COUNT-2: load i64
; CHECK-NOT: load
; CHECK: ret void
define void @wide_integer(ptr %a, ptr %b, ptr %c, i32 %n) {
entry:
  %long = icmp uge i32 %n, 16
  br i1 %long, label %loop, label %exit
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %ap = getelementptr i64, ptr %a, i32 %i
  %bp = getelementptr i64, ptr %b, i32 %i
  %cp = getelementptr i64, ptr %c, i32 %i
  %x = load i64, ptr %ap
  %y = load i64, ptr %bp
  %z = add i64 %x, %y
  store i64 %z, ptr %cp
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; CHECK-LABEL: define void @software_fp(
; CHECK: loop:
; CHECK-COUNT-2: load double
; CHECK-NOT: load
; CHECK: ret void
define void @software_fp(ptr %a, ptr %b, ptr %c, i32 %n) {
entry:
  %long = icmp uge i32 %n, 16
  br i1 %long, label %loop, label %exit
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %ap = getelementptr double, ptr %a, i32 %i
  %bp = getelementptr double, ptr %b, i32 %i
  %cp = getelementptr double, ptr %c, i32 %i
  %x = load double, ptr %ap
  %y = load double, ptr %bp
  %z = fadd double %x, %y
  store double %z, ptr %cp
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; CHECK-LABEL: define void @profile_short(
; CHECK: loop:
; CHECK-COUNT-2: load i32
; CHECK-NOT: load
; CHECK: ret void
define void @profile_short(ptr %a, ptr %b, ptr %c, i32 %n) !prof !0 {
entry:
  %nonzero = icmp ne i32 %n, 0
  br i1 %nonzero, label %loop, label %exit
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
  br i1 %done, label %exit, label %loop, !prof !1
exit:
  ret void
}

; CHECK-LABEL: define void @bounded_short(
; CHECK: loop:
; CHECK-COUNT-2: load i32
; CHECK-NOT: load
; CHECK: ret void
define void @bounded_short(ptr %a, ptr %b, ptr %c, i32 %bound) {
entry:
  %n = and i32 %bound, 7
  %nonzero = icmp ne i32 %n, 0
  br i1 %nonzero, label %loop, label %exit
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

; CHECK-LABEL: define void @exact_four(
; CHECK-COUNT-8: load i32
; CHECK-NOT: load
; CHECK-NOT: br i1
; CHECK: ret void
define void @exact_four(ptr %a, ptr %b, ptr %c) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %ap = getelementptr i32, ptr %a, i32 %i
  %bp = getelementptr i32, ptr %b, i32 %i
  %cp = getelementptr i32, ptr %c, i32 %i
  %x = load i32, ptr %ap
  %y = load i32, ptr %bp
  %z = add i32 %x, %y
  store i32 %z, ptr %cp
  %inc = add nuw i32 %i, 1
  %done = icmp eq i32 %inc, 4
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

!0 = !{!"function_entry_count", i64 100}
!1 = !{!"branch_weights", i32 100, i32 200}
