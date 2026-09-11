; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f -O3 < %s | FileCheck %s
;
; Rebase a scalar FP32 loop store on the incremented pointer so its address
; update can be scheduled before the store and fill FP producer latency.

define void @fp_stream(float addrspace(1)* %a, float addrspace(1)* %b,
                       float addrspace(1)* %c, i32 %n) nounwind {
; CHECK-LABEL: fp_stream:
; CHECK:       .LBB0_1:
; CHECK:         fadd.s [[SUM:f[a-z0-9]+]], {{f[a-z0-9]+}}, {{f[a-z0-9]+}}
; CHECK:         fsw [[SUM]], -4({{[a-z][a-z0-9]+}})
entry:
  br label %loop

loop:
  %ap = phi float addrspace(1)* [ %a, %entry ], [ %ap.next, %loop ]
  %bp = phi float addrspace(1)* [ %b, %entry ], [ %bp.next, %loop ]
  %cp = phi float addrspace(1)* [ %c, %entry ], [ %cp.next, %loop ]
  %left = phi i32 [ %n, %entry ], [ %left.next, %loop ]
  %av = load float, float addrspace(1)* %ap, align 4
  %bv = load float, float addrspace(1)* %bp, align 4
  %sum = fadd fast float %av, %bv
  store float %sum, float addrspace(1)* %cp, align 4
  %ap.next = getelementptr inbounds float, float addrspace(1)* %ap, i32 1
  %bp.next = getelementptr inbounds float, float addrspace(1)* %bp, i32 1
  %cp.next = getelementptr inbounds float, float addrspace(1)* %cp, i32 1
  %left.next = add nsw i32 %left, -1
  %done = icmp eq i32 %left.next, 0
  br i1 %done, label %exit, label %loop

exit:
  ret void
}
