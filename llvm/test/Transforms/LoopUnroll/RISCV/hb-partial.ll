; RUN: opt < %s -S -loop-unroll -mtriple=riscv32 -mcpu=generic-rv32 | FileCheck %s --check-prefix=GENERIC
; RUN: opt < %s -S -loop-unroll -mtriple=riscv32 -mcpu=hb-rv32 | FileCheck %s --check-prefix=HB

; HammerBlade has no hardware loop buffer, but partial unrolling is profitable
; because it reduces loop-control and address-generation work.  Keep generic
; RISC-V unchanged while enabling a conservative target policy for hb-rv32.

define void @partial_unroll(i32* nocapture %dst) nounwind {
entry:
  br label %loop

loop:
  %iv = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %ptr = getelementptr inbounds i32, i32* %dst, i32 %iv
  store i32 %iv, i32* %ptr, align 4
  %inc = add nuw nsw i32 %iv, 1
  %done = icmp eq i32 %inc, 1024
  br i1 %done, label %exit, label %loop

exit:
  ret void
}

; GENERIC-LABEL: @partial_unroll(
; GENERIC: loop:
; GENERIC: store i32
; GENERIC-NOT: store i32
; GENERIC: icmp eq i32

; HB-LABEL: @partial_unroll(
; HB: loop:
; HB: store i32
; HB: store i32
; HB: icmp eq i32
