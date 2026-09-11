; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f \
; RUN:   -target-abi=ilp32f < %s | FileCheck %s --check-prefix=HB
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f \
; RUN:   -target-abi=ilp32f -hb32sched=false < %s | FileCheck %s --check-prefix=GENERIC
;
; HammerBlade DRAM streams benefit when independent loop bookkeeping fills the
; gap between FP loads and their consumer. The generic scheduler issues fadd.s
; directly after the loads, while the HB32 FP-stream policy exposes latency.

define void @float_stream(float addrspace(1)* noalias nocapture %out,
                          float addrspace(1)* noalias nocapture readonly %a,
                          float addrspace(1)* noalias nocapture readonly %b,
                          i32 %n) nounwind {
; HB-LABEL: float_stream:
; HB:       .LBB0_1:
; HB:         flw
; HB-NEXT:    flw
; HB-NEXT:    addi
; HB-NEXT:    addi
; HB:         fadd.s
;
; GENERIC-LABEL: float_stream:
; GENERIC:       .LBB0_1:
; GENERIC:         flw
; GENERIC-NEXT:    flw
; GENERIC-NEXT:    fadd.s
entry:
  %empty = icmp eq i32 %n, 0
  br i1 %empty, label %exit, label %loop

loop:
  %index = phi i32 [ 0, %entry ], [ %next, %loop ]
  %a.ptr = getelementptr inbounds float, float addrspace(1)* %a, i32 %index
  %b.ptr = getelementptr inbounds float, float addrspace(1)* %b, i32 %index
  %out.ptr = getelementptr inbounds float, float addrspace(1)* %out, i32 %index
  %av = load float, float addrspace(1)* %a.ptr, align 4
  %bv = load float, float addrspace(1)* %b.ptr, align 4
  %sum = fadd float %av, %bv
  store float %sum, float addrspace(1)* %out.ptr, align 4
  %next = add nuw i32 %index, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop

exit:
  ret void
}

; Do not use the FP-stream policy for integer-only functions. It can bunch
; local integer loads immediately before their consumers.
define i32 @integer_only(i32 addrspace(1)* %a, i32 addrspace(1)* %b) nounwind {
; HB-LABEL: integer_only:
; HB:         lw
; HB-NEXT:    lw
; HB-NEXT:    add
; HB-NEXT:    addi
  %av = load i32, i32 addrspace(1)* %a, align 4
  %av.next = add i32 %av, 1
  %bv = load i32, i32 addrspace(1)* %b, align 4
  %bv.next = add i32 %bv, 2
  %sum = add i32 %av.next, %bv.next
  ret i32 %sum
}
