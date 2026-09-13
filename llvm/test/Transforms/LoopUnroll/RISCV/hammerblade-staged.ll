; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll | FileCheck %s --check-prefix=HB
; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -hb-preserve-staged-loops=false | FileCheck %s --check-prefix=OFF
; Explicit requests retain priority over the staged-loop policy.
; Bound automatic replication of manually staged memory-clobber batches.

; HB-LABEL: define void @wide(
; HB-COUNT-16: load volatile
; HB-NOT: load volatile
; HB: br i1
; OFF-LABEL: define void @wide(
; OFF-COUNT-32: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @wide(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %iv = phi i32 [0, %entry], [%inc, %loop]
  %offset = mul i32 %iv, 16
  %off0 = add i32 %offset, 0
  %p0 = getelementptr i32, ptr %a, i32 %off0
  %v0 = load volatile i32, ptr %p0
  %off1 = add i32 %offset, 1
  %p1 = getelementptr i32, ptr %a, i32 %off1
  %v1 = load volatile i32, ptr %p1
  %off2 = add i32 %offset, 2
  %p2 = getelementptr i32, ptr %a, i32 %off2
  %v2 = load volatile i32, ptr %p2
  %off3 = add i32 %offset, 3
  %p3 = getelementptr i32, ptr %a, i32 %off3
  %v3 = load volatile i32, ptr %p3
  %off4 = add i32 %offset, 4
  %p4 = getelementptr i32, ptr %a, i32 %off4
  %v4 = load volatile i32, ptr %p4
  %off5 = add i32 %offset, 5
  %p5 = getelementptr i32, ptr %a, i32 %off5
  %v5 = load volatile i32, ptr %p5
  %off6 = add i32 %offset, 6
  %p6 = getelementptr i32, ptr %a, i32 %off6
  %v6 = load volatile i32, ptr %p6
  %off7 = add i32 %offset, 7
  %p7 = getelementptr i32, ptr %a, i32 %off7
  %v7 = load volatile i32, ptr %p7
  %off8 = add i32 %offset, 8
  %p8 = getelementptr i32, ptr %a, i32 %off8
  %v8 = load volatile i32, ptr %p8
  %off9 = add i32 %offset, 9
  %p9 = getelementptr i32, ptr %a, i32 %off9
  %v9 = load volatile i32, ptr %p9
  %off10 = add i32 %offset, 10
  %p10 = getelementptr i32, ptr %a, i32 %off10
  %v10 = load volatile i32, ptr %p10
  %off11 = add i32 %offset, 11
  %p11 = getelementptr i32, ptr %a, i32 %off11
  %v11 = load volatile i32, ptr %p11
  %off12 = add i32 %offset, 12
  %p12 = getelementptr i32, ptr %a, i32 %off12
  %v12 = load volatile i32, ptr %p12
  %off13 = add i32 %offset, 13
  %p13 = getelementptr i32, ptr %a, i32 %off13
  %v13 = load volatile i32, ptr %p13
  %off14 = add i32 %offset, 14
  %p14 = getelementptr i32, ptr %a, i32 %off14
  %v14 = load volatile i32, ptr %p14
  %off15 = add i32 %offset, 15
  %p15 = getelementptr i32, ptr %a, i32 %off15
  %v15 = load volatile i32, ptr %p15
  call void asm sideeffect "", "~{memory}"()
  %inc = add nuw nsw i32 %iv, 1
  %done = icmp eq i32 %inc, 2
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; HB-LABEL: define void @small(
; HB-COUNT-16: load volatile
; HB-NOT: load volatile
; HB: br i1
; OFF-LABEL: define void @small(
; OFF-COUNT-32: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @small(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %iv = phi i32 [0, %entry], [%inc, %loop]
  %offset = mul i32 %iv, 4
  %off0 = add i32 %offset, 0
  %p0 = getelementptr i32, ptr %a, i32 %off0
  %v0 = load volatile i32, ptr %p0
  %off1 = add i32 %offset, 1
  %p1 = getelementptr i32, ptr %a, i32 %off1
  %v1 = load volatile i32, ptr %p1
  %off2 = add i32 %offset, 2
  %p2 = getelementptr i32, ptr %a, i32 %off2
  %v2 = load volatile i32, ptr %p2
  %off3 = add i32 %offset, 3
  %p3 = getelementptr i32, ptr %a, i32 %off3
  %v3 = load volatile i32, ptr %p3
  call void asm sideeffect "", "~{memory}"()
  %inc = add nuw nsw i32 %iv, 1
  %done = icmp eq i32 %inc, 8
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; HB-LABEL: define void @wide_words(
; HB-COUNT-8: load volatile i64
; HB-NOT: load volatile
; HB: br i1
; OFF-LABEL: define void @wide_words(
; OFF-COUNT-16: load volatile i64
; OFF-NOT: br i1
; OFF: ret void
define void @wide_words(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %iv = phi i32 [0, %entry], [%inc, %loop]
  %offset = mul i32 %iv, 8
  %off0 = add i32 %offset, 0
  %p0 = getelementptr i64, ptr %a, i32 %off0
  %v0 = load volatile i64, ptr %p0
  %off1 = add i32 %offset, 1
  %p1 = getelementptr i64, ptr %a, i32 %off1
  %v1 = load volatile i64, ptr %p1
  %off2 = add i32 %offset, 2
  %p2 = getelementptr i64, ptr %a, i32 %off2
  %v2 = load volatile i64, ptr %p2
  %off3 = add i32 %offset, 3
  %p3 = getelementptr i64, ptr %a, i32 %off3
  %v3 = load volatile i64, ptr %p3
  %off4 = add i32 %offset, 4
  %p4 = getelementptr i64, ptr %a, i32 %off4
  %v4 = load volatile i64, ptr %p4
  %off5 = add i32 %offset, 5
  %p5 = getelementptr i64, ptr %a, i32 %off5
  %v5 = load volatile i64, ptr %p5
  %off6 = add i32 %offset, 6
  %p6 = getelementptr i64, ptr %a, i32 %off6
  %v6 = load volatile i64, ptr %p6
  %off7 = add i32 %offset, 7
  %p7 = getelementptr i64, ptr %a, i32 %off7
  %v7 = load volatile i64, ptr %p7
  call void asm sideeffect "", "~{memory}"()
  %q0 = getelementptr i64, ptr %b, i32 %off0
  store volatile i64 %v0, ptr %q0
  %q1 = getelementptr i64, ptr %b, i32 %off1
  store volatile i64 %v1, ptr %q1
  %q2 = getelementptr i64, ptr %b, i32 %off2
  store volatile i64 %v2, ptr %q2
  %q3 = getelementptr i64, ptr %b, i32 %off3
  store volatile i64 %v3, ptr %q3
  %q4 = getelementptr i64, ptr %b, i32 %off4
  store volatile i64 %v4, ptr %q4
  %q5 = getelementptr i64, ptr %b, i32 %off5
  store volatile i64 %v5, ptr %q5
  %q6 = getelementptr i64, ptr %b, i32 %off6
  store volatile i64 %v6, ptr %q6
  %q7 = getelementptr i64, ptr %b, i32 %off7
  store volatile i64 %v7, ptr %q7
  %inc = add nuw nsw i32 %iv, 1
  %done = icmp eq i32 %inc, 2
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; HB-LABEL: define void @explicit(
; HB-COUNT-32: load volatile
; HB-NOT: br i1
; HB: ret void
; OFF-LABEL: define void @explicit(
; OFF-COUNT-32: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @explicit(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %iv = phi i32 [0, %entry], [%inc, %loop]
  %offset = mul i32 %iv, 16
  %off0 = add i32 %offset, 0
  %p0 = getelementptr i32, ptr %a, i32 %off0
  %v0 = load volatile i32, ptr %p0
  %off1 = add i32 %offset, 1
  %p1 = getelementptr i32, ptr %a, i32 %off1
  %v1 = load volatile i32, ptr %p1
  %off2 = add i32 %offset, 2
  %p2 = getelementptr i32, ptr %a, i32 %off2
  %v2 = load volatile i32, ptr %p2
  %off3 = add i32 %offset, 3
  %p3 = getelementptr i32, ptr %a, i32 %off3
  %v3 = load volatile i32, ptr %p3
  %off4 = add i32 %offset, 4
  %p4 = getelementptr i32, ptr %a, i32 %off4
  %v4 = load volatile i32, ptr %p4
  %off5 = add i32 %offset, 5
  %p5 = getelementptr i32, ptr %a, i32 %off5
  %v5 = load volatile i32, ptr %p5
  %off6 = add i32 %offset, 6
  %p6 = getelementptr i32, ptr %a, i32 %off6
  %v6 = load volatile i32, ptr %p6
  %off7 = add i32 %offset, 7
  %p7 = getelementptr i32, ptr %a, i32 %off7
  %v7 = load volatile i32, ptr %p7
  %off8 = add i32 %offset, 8
  %p8 = getelementptr i32, ptr %a, i32 %off8
  %v8 = load volatile i32, ptr %p8
  %off9 = add i32 %offset, 9
  %p9 = getelementptr i32, ptr %a, i32 %off9
  %v9 = load volatile i32, ptr %p9
  %off10 = add i32 %offset, 10
  %p10 = getelementptr i32, ptr %a, i32 %off10
  %v10 = load volatile i32, ptr %p10
  %off11 = add i32 %offset, 11
  %p11 = getelementptr i32, ptr %a, i32 %off11
  %v11 = load volatile i32, ptr %p11
  %off12 = add i32 %offset, 12
  %p12 = getelementptr i32, ptr %a, i32 %off12
  %v12 = load volatile i32, ptr %p12
  %off13 = add i32 %offset, 13
  %p13 = getelementptr i32, ptr %a, i32 %off13
  %v13 = load volatile i32, ptr %p13
  %off14 = add i32 %offset, 14
  %p14 = getelementptr i32, ptr %a, i32 %off14
  %v14 = load volatile i32, ptr %p14
  %off15 = add i32 %offset, 15
  %p15 = getelementptr i32, ptr %a, i32 %off15
  %v15 = load volatile i32, ptr %p15
  call void asm sideeffect "", "~{memory}"()
  %q0 = getelementptr i32, ptr %b, i32 %off0
  store volatile i32 %v0, ptr %q0
  %q1 = getelementptr i32, ptr %b, i32 %off1
  store volatile i32 %v1, ptr %q1
  %q2 = getelementptr i32, ptr %b, i32 %off2
  store volatile i32 %v2, ptr %q2
  %q3 = getelementptr i32, ptr %b, i32 %off3
  store volatile i32 %v3, ptr %q3
  %q4 = getelementptr i32, ptr %b, i32 %off4
  store volatile i32 %v4, ptr %q4
  %q5 = getelementptr i32, ptr %b, i32 %off5
  store volatile i32 %v5, ptr %q5
  %q6 = getelementptr i32, ptr %b, i32 %off6
  store volatile i32 %v6, ptr %q6
  %q7 = getelementptr i32, ptr %b, i32 %off7
  store volatile i32 %v7, ptr %q7
  %q8 = getelementptr i32, ptr %b, i32 %off8
  store volatile i32 %v8, ptr %q8
  %q9 = getelementptr i32, ptr %b, i32 %off9
  store volatile i32 %v9, ptr %q9
  %q10 = getelementptr i32, ptr %b, i32 %off10
  store volatile i32 %v10, ptr %q10
  %q11 = getelementptr i32, ptr %b, i32 %off11
  store volatile i32 %v11, ptr %q11
  %q12 = getelementptr i32, ptr %b, i32 %off12
  store volatile i32 %v12, ptr %q12
  %q13 = getelementptr i32, ptr %b, i32 %off13
  store volatile i32 %v13, ptr %q13
  %q14 = getelementptr i32, ptr %b, i32 %off14
  store volatile i32 %v14, ptr %q14
  %q15 = getelementptr i32, ptr %b, i32 %off15
  store volatile i32 %v15, ptr %q15
  %inc = add nuw nsw i32 %iv, 1
  %done = icmp eq i32 %inc, 2
  br i1 %done, label %exit, label %loop, !llvm.loop !0
exit:
  ret void
}

!0 = distinct !{!0, !1}
!1 = !{!"llvm.loop.unroll.count", i32 2}
