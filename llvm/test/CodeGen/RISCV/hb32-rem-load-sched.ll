; RUN: llc -march=riscv32 -mattr=+m,+a,+f -target-abi=ilp32f -mcpu=hb-rv32 \
; RUN:    < %s | FileCheck %s

define void @vec_add(i32 addrspace(1)* noalias nocapture %a,
                     i32 addrspace(1)* noalias nocapture readonly %b) 
                    nounwind {
; CHECK-LABEL: vec_add:
; CHECK:       # %bb.0:
; CHECK-NEXT:    lw  a6, 0(a1)
; CHECK-NEXT:    lw  a7, 0(a0)
; CHECK-NEXT:    lw  t0, 4(a1)
; CHECK-NEXT:    lw  t1, 4(a0)
; CHECK-NEXT:    lw  a2, 8(a1)
; CHECK-NEXT:    lw  a3, 8(a0)
; CHECK-NEXT:    lw  a1, 12(a1)
; CHECK-NEXT:    lw  a4, 12(a0)
; CHECK-NEXT:    add a5, a7, a6
; CHECK-NEXT:    sw  a5, 0(a0)
; CHECK-NEXT:    add a5, t1, t0
; CHECK-NEXT:    sw  a5, 4(a0)
; CHECK-NEXT:    add a2, a3, a2
; CHECK-NEXT:    sw  a2, 8(a0)
; CHECK-NEXT:    add a1, a4, a1
; CHECK-NEXT:    sw  a1, 12(a0)
; CHECK-NEXT:    ret
entry:
  %0 = load i32, i32 addrspace(1)* %b
  %1 = load i32, i32 addrspace(1)* %a
  %add = add nsw i32 %1, %0
  store i32 %add, i32 addrspace(1)* %a
  %arrayidx2 = getelementptr inbounds i32, i32 addrspace(1)* %b, i32 1
  %2 = load i32, i32 addrspace(1)* %arrayidx2
  %arrayidx3 = getelementptr inbounds i32, i32 addrspace(1)* %a, i32 1
  %3 = load i32, i32 addrspace(1)* %arrayidx3
  %add4 = add nsw i32 %3, %2
  store i32 %add4, i32 addrspace(1)* %arrayidx3
  %arrayidx5 = getelementptr inbounds i32, i32 addrspace(1)* %b, i32 2
  %4 = load i32, i32 addrspace(1)* %arrayidx5
  %arrayidx6 = getelementptr inbounds i32, i32 addrspace(1)* %a, i32 2
  %5 = load i32, i32 addrspace(1)* %arrayidx6
  %add7 = add nsw i32 %5, %4
  store i32 %add7, i32 addrspace(1)* %arrayidx6
  %arrayidx8 = getelementptr inbounds i32, i32 addrspace(1)* %b, i32 3
  %6 = load i32, i32 addrspace(1)* %arrayidx8
  %arrayidx9 = getelementptr inbounds i32, i32 addrspace(1)* %a, i32 3
  %7 = load i32, i32 addrspace(1)* %arrayidx9
  %add10 = add nsw i32 %7, %6
  store i32 %add10, i32 addrspace(1)* %arrayidx9
  ret void
}

