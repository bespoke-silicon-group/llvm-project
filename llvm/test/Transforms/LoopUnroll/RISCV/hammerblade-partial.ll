; RUN: opt %s -S -mtriple=riscv32 -passes=loop-unroll -mcpu=generic-rv32 \
; RUN:   | FileCheck %s --check-prefix=GENERIC
; RUN: opt %s -S -mtriple=riscv32 -passes=loop-unroll -mcpu=hb-rv32 \
; RUN:   | FileCheck %s --check-prefix=HB

; HammerBlade's single-issue pipeline benefits from amortizing loop-control and
; address-generation work. Keep generic RISC-V unchanged while permitting
; conservative partial unrolling for hb-rv32.

define void @partial_unroll(ptr nocapture %dst) nounwind {
entry:
  br label %loop

loop:
  %iv = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %ptr = getelementptr inbounds i32, ptr %dst, i32 %iv
  store i32 %iv, ptr %ptr, align 4
  %inc = add nuw nsw i32 %iv, 1
  %done = icmp eq i32 %inc, 1024
  br i1 %done, label %exit, label %loop

exit:
  ret void
}

; GENERIC-LABEL: @partial_unroll(
; GENERIC:       loop:
; GENERIC:         store i32
; GENERIC-NOT:     store i32
; GENERIC:         icmp eq i32

; HB-LABEL: @partial_unroll(
; HB:       loop:
; HB:         store i32
; HB:         store i32
; HB:         icmp eq i32
