; RUN: opt < %s -passes=instcombine -S | FileCheck %s

declare float @llvm.sqrt.f32(float)

define i1 @compare_sqrts_fast(float %x, float %y) {
; CHECK-LABEL: @compare_sqrts_fast(
; CHECK-NEXT:  [[CMP:%.*]] = fcmp fast olt float %x, %y
; CHECK-NEXT:  ret i1 [[CMP]]
  %sx = call fast float @llvm.sqrt.f32(float %x)
  %sy = call fast float @llvm.sqrt.f32(float %y)
  %cmp = fcmp fast olt float %sx, %sy
  ret i1 %cmp
}

define i1 @compare_sqrts_strict(float %x, float %y) {
; CHECK-LABEL: @compare_sqrts_strict(
; CHECK:       call float @llvm.sqrt.f32(float %x)
; CHECK:       call float @llvm.sqrt.f32(float %y)
; CHECK:       fcmp olt float
  %sx = call float @llvm.sqrt.f32(float %x)
  %sy = call float @llvm.sqrt.f32(float %y)
  %cmp = fcmp olt float %sx, %sy
  ret i1 %cmp
}

define float @select_sqrts(i1 %cond, float %x, float %y) {
; CHECK-LABEL: @select_sqrts(
; CHECK-NEXT:  [[SEL:%.*]] = select i1 %cond, float %x, float %y
; CHECK-NEXT:  [[SQRT:%.*]] = call fast float @llvm.sqrt.f32(float [[SEL]])
; CHECK-NEXT:  ret float [[SQRT]]
  %sx = call fast float @llvm.sqrt.f32(float %x)
  %sy = call fast float @llvm.sqrt.f32(float %y)
  %sel = select i1 %cond, float %sx, float %sy
  ret float %sel
}

define i1 @sqrt_less_positive_infinity(float %x) {
; CHECK-LABEL: @sqrt_less_positive_infinity(
; CHECK-NEXT:  ret i1 true
  %sx = call fast float @llvm.sqrt.f32(float %x)
  %cmp = fcmp fast olt float %sx, 0x7FF0000000000000
  ret i1 %cmp
}
