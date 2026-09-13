; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -verify-each | FileCheck %s --check-prefix=HB
; RUN: opt %s -S -mtriple=riscv32 -mcpu=hb-rv32 -passes=loop-unroll -hb-preserve-staged-loops=false -verify-each | FileCheck %s --check-prefix=OFF
; Live staged values constrain automatic replication; dead or already consumed
; values, and values belonging to separate batches, are not accumulated.

; HB-LABEL: define void @live_four(
; HB-COUNT-16: load volatile i32
; HB-NOT: load volatile
; HB: br i1
; HB: ret void
; OFF-LABEL: define void @live_four(
; OFF-COUNT-32: load volatile i32
; OFF-NOT: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @live_four(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %v0 = load volatile i32, ptr %a
  %v1 = load volatile i32, ptr %a
  %v2 = load volatile i32, ptr %a
  %v3 = load volatile i32, ptr %a
  call void asm sideeffect "", "~{memory}"()
  store volatile i32 %v0, ptr %b
  store volatile i32 %v1, ptr %b
  store volatile i32 %v2, ptr %b
  store volatile i32 %v3, ptr %b
  %inc = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %inc, 8
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; HB-LABEL: define void @last_only(
; HB-COUNT-32: load volatile i32
; HB-NOT: load volatile
; HB-NOT: br i1
; HB: ret void
; OFF-LABEL: define void @last_only(
; OFF-COUNT-32: load volatile i32
; OFF-NOT: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @last_only(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %v0 = load volatile i32, ptr %a
  %v1 = load volatile i32, ptr %a
  %v2 = load volatile i32, ptr %a
  %v3 = load volatile i32, ptr %a
  call void asm sideeffect "", "~{memory}"()
  store volatile i32 %v3, ptr %b
  %inc = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %inc, 8
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; HB-LABEL: define void @wide_last_only(
; HB-COUNT-32: load volatile i32
; HB-NOT: load volatile
; HB-NOT: br i1
; HB: ret void
; OFF-LABEL: define void @wide_last_only(
; OFF-COUNT-32: load volatile i32
; OFF-NOT: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @wide_last_only(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %v0 = load volatile i32, ptr %a
  %v1 = load volatile i32, ptr %a
  %v2 = load volatile i32, ptr %a
  %v3 = load volatile i32, ptr %a
  %v4 = load volatile i32, ptr %a
  %v5 = load volatile i32, ptr %a
  %v6 = load volatile i32, ptr %a
  %v7 = load volatile i32, ptr %a
  %v8 = load volatile i32, ptr %a
  %v9 = load volatile i32, ptr %a
  %v10 = load volatile i32, ptr %a
  %v11 = load volatile i32, ptr %a
  %v12 = load volatile i32, ptr %a
  %v13 = load volatile i32, ptr %a
  %v14 = load volatile i32, ptr %a
  %v15 = load volatile i32, ptr %a
  call void asm sideeffect "", "~{memory}"()
  store volatile i32 %v15, ptr %b
  %inc = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %inc, 2
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; HB-LABEL: define void @live_wide(
; HB-COUNT-16: load volatile i32
; HB-NOT: load volatile
; HB: br i1
; HB: ret void
; OFF-LABEL: define void @live_wide(
; OFF-COUNT-32: load volatile i32
; OFF-NOT: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @live_wide(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %v0 = load volatile i32, ptr %a
  %v1 = load volatile i32, ptr %a
  %v2 = load volatile i32, ptr %a
  %v3 = load volatile i32, ptr %a
  %v4 = load volatile i32, ptr %a
  %v5 = load volatile i32, ptr %a
  %v6 = load volatile i32, ptr %a
  %v7 = load volatile i32, ptr %a
  %v8 = load volatile i32, ptr %a
  %v9 = load volatile i32, ptr %a
  %v10 = load volatile i32, ptr %a
  %v11 = load volatile i32, ptr %a
  %v12 = load volatile i32, ptr %a
  %v13 = load volatile i32, ptr %a
  %v14 = load volatile i32, ptr %a
  %v15 = load volatile i32, ptr %a
  call void asm sideeffect "", "~{memory}"()
  store volatile i32 %v0, ptr %b
  store volatile i32 %v1, ptr %b
  store volatile i32 %v2, ptr %b
  store volatile i32 %v3, ptr %b
  store volatile i32 %v4, ptr %b
  store volatile i32 %v5, ptr %b
  store volatile i32 %v6, ptr %b
  store volatile i32 %v7, ptr %b
  store volatile i32 %v8, ptr %b
  store volatile i32 %v9, ptr %b
  store volatile i32 %v10, ptr %b
  store volatile i32 %v11, ptr %b
  store volatile i32 %v12, ptr %b
  store volatile i32 %v13, ptr %b
  store volatile i32 %v14, ptr %b
  store volatile i32 %v15, ptr %b
  %inc = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %inc, 2
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; HB-LABEL: define void @separate_batches(
; HB-COUNT-32: load volatile i32
; HB-NOT: load volatile
; HB-NOT: br i1
; HB: ret void
; OFF-LABEL: define void @separate_batches(
; OFF-COUNT-32: load volatile i32
; OFF-NOT: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @separate_batches(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %v0 = load volatile i32, ptr %a
  call void asm sideeffect "", "~{memory}"()
  store volatile i32 %v0, ptr %b
  %v1 = load volatile i32, ptr %a
  call void asm sideeffect "", "~{memory}"()
  store volatile i32 %v1, ptr %b
  %v2 = load volatile i32, ptr %a
  call void asm sideeffect "", "~{memory}"()
  store volatile i32 %v2, ptr %b
  %v3 = load volatile i32, ptr %a
  call void asm sideeffect "", "~{memory}"()
  store volatile i32 %v3, ptr %b
  %inc = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %inc, 8
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; The result of the memory-clobbering asm is defined at that instruction. It
; does not form a fourth live value spanning the clobber.
; HB-LABEL: define void @returning_asm(
; HB-COUNT-24: load volatile i32
; HB-NOT: load volatile
; HB-NOT: br i1
; HB: ret void
; OFF-LABEL: define void @returning_asm(
; OFF-COUNT-24: load volatile i32
; OFF-NOT: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @returning_asm(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %v0 = load volatile i32, ptr %a
  %v1 = load volatile i32, ptr %a
  %v2 = load volatile i32, ptr %a
  %new = call i32 asm sideeffect "li $0, 0", "=r,~{memory}"()
  store volatile i32 %v0, ptr %b
  store volatile i32 %v1, ptr %b
  store volatile i32 %v2, ptr %b
  store volatile i32 %new, ptr %b
  %inc = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %inc, 8
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; Integer and native FP32 data use distinct register files. Three live words
; in each file are not one six-word staged batch.
; HB-LABEL: define void @mixed_files(
; HB-COUNT-24: load volatile
; HB-NOT: load volatile
; HB-NOT: br i1
; HB: ret void
; OFF-LABEL: define void @mixed_files(
; OFF-COUNT-24: load volatile
; OFF-NOT: load volatile
; OFF-NOT: br i1
; OFF: ret void
define void @mixed_files(ptr %a, ptr %b) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %v0 = load volatile i32, ptr %a
  %v1 = load volatile i32, ptr %a
  %v2 = load volatile i32, ptr %a
  %f0 = load volatile float, ptr %a
  %f1 = load volatile float, ptr %a
  %f2 = load volatile float, ptr %a
  call void asm sideeffect "", "~{memory}"()
  store volatile i32 %v0, ptr %b
  store volatile i32 %v1, ptr %b
  store volatile i32 %v2, ptr %b
  store volatile float %f0, ptr %b
  store volatile float %f1, ptr %b
  store volatile float %f2, ptr %b
  %inc = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %inc, 4
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
