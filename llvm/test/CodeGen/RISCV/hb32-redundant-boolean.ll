; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f -O3 \
; RUN:   < %s | FileCheck %s
;
; SelectionDAG promotes i1 PHIs to GPRs and can leave an ANDI 1 before a
; branch even when every incoming definition is a zero-or-one comparison.
; Keep the input i1 mask, but omit the redundant mask at the merge.

define i32 @bool_phi(i32 %a, i32 %b, i1 %pick, i32* %sink) nounwind {
; CHECK-LABEL: bool_phi:
; CHECK:         andi a2, a2, 1
; CHECK:       .LBB0_3:
; CHECK-NEXT:    beqz a2, .LBB0_5
entry:
  %az = icmp eq i32 %a, 0
  %bz = icmp eq i32 %b, 0
  br i1 %pick, label %left, label %right

left:
  store volatile i32 %a, i32* %sink
  br label %merge

right:
  store volatile i32 %b, i32* %sink
  br label %merge

merge:
  %value = phi i1 [ %az, %left ], [ %bz, %right ]
  br i1 %value, label %zero, label %nonzero

zero:
  ret i32 1

nonzero:
  ret i32 0
}
