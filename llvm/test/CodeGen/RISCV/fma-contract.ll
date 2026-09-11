; RUN: llc -mtriple=riscv32 -mattr=+f < %s | FileCheck %s --check-prefixes=CHECK,F32
; RUN: llc -mtriple=riscv64 -mattr=+f,+d < %s | FileCheck %s --check-prefixes=CHECK,F32,F64

define float @contract_f32(float %x, float %y, float %acc) {
; CHECK-LABEL: contract_f32:
; F32:       fmadd.s
; F32-NOT:   fmul.s
; F32-NOT:   fadd.s
  %mul = fmul contract float %x, %y
  %add = fadd contract float %mul, %acc
  ret float %add
}

define float @strict_f32(float %x, float %y, float %acc) {
; CHECK-LABEL: strict_f32:
; CHECK:      fmul.s
; CHECK:      fadd.s
  %mul = fmul float %x, %y
  %add = fadd float %mul, %acc
  ret float %add
}

define double @contract_f64(double %x, double %y, double %acc) {
; F64-LABEL: contract_f64:
; F64:       fmadd.d
; F64-NOT:   fmul.d
; F64-NOT:   fadd.d
  %mul = fmul contract double %x, %y
  %add = fadd contract double %mul, %acc
  ret double %add
}
