; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll | FileCheck %s --check-prefixes=HB,ALL
; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -hb-runtime-memory-unroll=false | FileCheck %s --check-prefixes=OFF,ALL
; RUN: opt %s -S -mtriple=riscv32 -mcpu=generic-rv32 -passes=loop-unroll | FileCheck %s --check-prefixes=OFF,ALL

; Only small single-block, nonvolatile, call-free memory loops opt in.
; The generic unroller supplies the exact-trip-count remainder handling.

; HB-LABEL: define void @stream(
; HB: loop:
; HB-COUNT-8: load float
; HB: br i1
; HB: epil
; OFF-LABEL: define void @stream(
; OFF: loop:
; OFF-COUNT-2: load float
; OFF-NOT: load float
; OFF: ret void
define void @stream(ptr %a, ptr %b, ptr %c, i32 %n)  {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %ap = getelementptr float, ptr %a, i32 %i
  %bp = getelementptr float, ptr %b, i32 %i
  %cp = getelementptr float, ptr %c, i32 %i
  %x = load float, ptr %ap
  %y = load float, ptr %bp
  %z = fadd float %x, %y
  store float %z, ptr %cp
  %inc = add nuw i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; ALL-LABEL: define void @volatile_stream(
; ALL: loop:
; ALL-COUNT-2: load volatile float
; ALL-NOT: load
; ALL: ret void
define void @volatile_stream(ptr %a, ptr %b, ptr %c, i32 %n)  {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %ap = getelementptr float, ptr %a, i32 %i
  %bp = getelementptr float, ptr %b, i32 %i
  %cp = getelementptr float, ptr %c, i32 %i
  %x = load volatile float, ptr %ap
  %y = load volatile float, ptr %bp
  %z = fadd float %x, %y
  store float %z, ptr %cp
  %inc = add nuw i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; ALL-LABEL: define void @barrier_stream(
; ALL: loop:
; ALL-COUNT-2: load float
; ALL-NOT: load
; ALL: ret void
define void @barrier_stream(ptr %a, ptr %b, ptr %c, i32 %n)  {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %ap = getelementptr float, ptr %a, i32 %i
  %bp = getelementptr float, ptr %b, i32 %i
  %cp = getelementptr float, ptr %c, i32 %i
  %x = load float, ptr %ap
  %y = load float, ptr %bp
  call void asm sideeffect "", "~{memory}"()
  %z = fadd float %x, %y
  store float %z, ptr %cp
  %inc = add nuw i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; ALL-LABEL: define void @size_stream(
; ALL: loop:
; ALL-COUNT-2: load float
; ALL-NOT: load
; ALL: ret void
define void @size_stream(ptr %a, ptr %b, ptr %c, i32 %n) optsize {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %ap = getelementptr float, ptr %a, i32 %i
  %bp = getelementptr float, ptr %b, i32 %i
  %cp = getelementptr float, ptr %c, i32 %i
  %x = load float, ptr %ap
  %y = load float, ptr %bp
  %z = fadd float %x, %y
  store float %z, ptr %cp
  %inc = add nuw i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
