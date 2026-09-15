; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -verify-each | FileCheck %s --check-prefix=HB
; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -hb-runtime-memory-unroll=false -verify-each | FileCheck %s --check-prefix=OFF
; Runtime setup is not amortized by a small body alone. The current factor-four
; policy requires at least 16 proven/actually profiled iterations; unknown trips
; and the threshold-minus-one lower bound do not opt in. Explicit unroll
; requests are still handled by the generic unroller.

; HB-LABEL: define void @at_threshold(
; HB: loop:
; HB-COUNT-8: load i32
; HB-NOT: load i32
; HB: br i1
; OFF-LABEL: define void @at_threshold(
; OFF: loop:
; OFF-COUNT-2: load i32
; OFF-NOT: load i32
; OFF: br i1
define void @at_threshold(ptr %a, ptr %b, ptr %c, i32 %n) {
entry:
  %long = icmp uge i32 %n, 16
  br i1 %long, label %loop, label %exit
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

; HB-LABEL: define void @below_threshold(
; HB: loop:
; HB-COUNT-2: load i32
; HB-NOT: load i32
; HB: br i1
; OFF-LABEL: define void @below_threshold(
; OFF: loop:
; OFF-COUNT-2: load i32
; OFF-NOT: load i32
; OFF: br i1
define void @below_threshold(ptr %a, ptr %b, ptr %c, i32 %n) {
entry:
  %long = icmp uge i32 %n, 15
  br i1 %long, label %loop, label %exit
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

; HB-LABEL: define void @unknown(
; HB: loop:
; HB-COUNT-2: load i32
; HB-NOT: load i32
; HB: br i1
; OFF-LABEL: define void @unknown(
; OFF: loop:
; OFF-COUNT-2: load i32
; OFF-NOT: load i32
; OFF: br i1
define void @unknown(ptr %a, ptr %b, ptr %c, i32 %n) {
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
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; HB-LABEL: define void @profile_long(
; HB: loop:
; HB-COUNT-8: load i32
; HB-NOT: load i32
; HB: br i1
; OFF-LABEL: define void @profile_long(
; OFF: loop:
; OFF-COUNT-2: load i32
; OFF-NOT: load i32
; OFF: br i1
define void @profile_long(ptr %a, ptr %b, ptr %c, i32 %n) !prof !0 {
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

; HB-LABEL: define void @profile_short(
; HB: loop:
; HB-COUNT-2: load i32
; HB-NOT: load i32
; HB: br i1
; OFF-LABEL: define void @profile_short(
; OFF: loop:
; OFF-COUNT-2: load i32
; OFF-NOT: load i32
; OFF: br i1
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
  br i1 %done, label %exit, label %loop, !prof !2
exit:
  ret void
}

; HB-LABEL: define void @unprofiled_bias(
; HB: loop:
; HB-COUNT-2: load i32
; HB-NOT: load i32
; HB: br i1
; OFF-LABEL: define void @unprofiled_bias(
; OFF: loop:
; OFF-COUNT-2: load i32
; OFF-NOT: load i32
; OFF: br i1
define void @unprofiled_bias(ptr %a, ptr %b, ptr %c, i32 %n) {
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

; HB-LABEL: define void @explicit_unknown(
; HB: loop:
; HB-COUNT-8: load i32
; HB-NOT: load i32
; HB: br i1
; OFF-LABEL: define void @explicit_unknown(
; OFF: loop:
; OFF-COUNT-8: load i32
; OFF-NOT: load i32
; OFF: br i1
define void @explicit_unknown(ptr %a, ptr %b, ptr %c, i32 %n) {
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
  br i1 %done, label %exit, label %loop, !llvm.loop !3
exit:
  ret void
}

!0 = !{!"function_entry_count", i64 100}
!1 = !{!"branch_weights", i32 100, i32 1500}
!2 = !{!"branch_weights", i32 100, i32 1400}
!3 = distinct !{!3, !4}
!4 = !{!"llvm.loop.unroll.count", i32 4}

; Synthetic function-entry counts do not supply measured long-trip evidence.
; HB-LABEL: define void @synthetic_profile(
; HB: loop:
; HB-COUNT-2: load i32
; HB-NOT: load i32
; HB: br i1
; OFF-LABEL: define void @synthetic_profile(
; OFF: loop:
; OFF-COUNT-2: load i32
; OFF-NOT: load i32
; OFF: br i1
define void @synthetic_profile(ptr %a, ptr %b, ptr %c, i32 %n) !prof !5 {
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

!5 = !{!"synthetic_function_entry_count", i64 100}
