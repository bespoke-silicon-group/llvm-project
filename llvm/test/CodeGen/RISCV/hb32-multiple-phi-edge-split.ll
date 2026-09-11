; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -verify-machineinstrs < %s | FileCheck %s

; On HB32, keep the four default-value copies off the path which loads all
; four values.  The shared-zero critical edge is split during PHI elimination.
define void @multiple_phi_incoming(float* %input, float* %output, i1 %use_input) {
; CHECK-LABEL: multiple_phi_incoming:
; CHECK:       bnez {{.*}}, [[LOAD:.LBB[0-9_]+]]
; CHECK:       flw
; CHECK-NEXT:  fmv.s
; CHECK-NEXT:  fmv.s
; CHECK-NEXT:  fmv.s
; CHECK:       j [[JOIN:.LBB[0-9_]+]]
; CHECK:       [[LOAD]]:
; CHECK:       flw
; CHECK:       flw
; CHECK:       flw
; CHECK:       flw
; CHECK:       [[JOIN]]:
entry:
  br i1 %use_input, label %load, label %join

load:
  %p1 = getelementptr float, float* %input, i32 1
  %p2 = getelementptr float, float* %input, i32 2
  %p3 = getelementptr float, float* %input, i32 3
  %v0 = load float, float* %input
  %v1 = load float, float* %p1
  %v2 = load float, float* %p2
  %v3 = load float, float* %p3
  br label %join

join:
  %a = phi float [ 0.0, %entry ], [ %v0, %load ]
  %b = phi float [ 0.0, %entry ], [ %v1, %load ]
  %c = phi float [ 0.0, %entry ], [ %v2, %load ]
  %d = phi float [ 0.0, %entry ], [ %v3, %load ]
  %o1 = getelementptr float, float* %output, i32 1
  %o2 = getelementptr float, float* %output, i32 2
  %o3 = getelementptr float, float* %output, i32 3
  store float %a, float* %output
  store float %b, float* %o1
  store float %c, float* %o2
  store float %d, float* %o3
  ret void
}
