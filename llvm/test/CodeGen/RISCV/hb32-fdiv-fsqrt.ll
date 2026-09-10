; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f \
; RUN:   -verify-machineinstrs < %s | FileCheck --check-prefix=HARD %s
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f,+no-fdiv \
; RUN:   -verify-machineinstrs < %s | FileCheck --check-prefix=SOFT %s

; HammerBlade implements single-precision divide and square root in RTL.  Its
; normal hb-rv32 feature set must select those instructions, while no-fdiv
; remains an explicit fallback for configurations without the unit.

define float @fdiv_s(float %a, float %b) nounwind {
; HARD-LABEL: fdiv_s:
; HARD:       fdiv.s
; HARD-NOT:   call __divsf3
; SOFT-LABEL: fdiv_s:
; SOFT:       call __divsf3
  %quotient = fdiv float %a, %b
  ret float %quotient
}

declare float @llvm.sqrt.f32(float)

define float @fsqrt_s(float %a) nounwind {
; HARD-LABEL: fsqrt_s:
; HARD:       fsqrt.s
; HARD-NOT:   call sqrtf
; SOFT-LABEL: fsqrt_s:
; SOFT:       call sqrtf
  %root = call float @llvm.sqrt.f32(float %a)
  ret float %root
}
