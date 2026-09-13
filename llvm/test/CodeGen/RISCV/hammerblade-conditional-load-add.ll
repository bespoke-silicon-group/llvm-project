; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -stop-after=riscv-codegenprepare -verify-machineinstrs %s -o - | FileCheck %s --check-prefixes=HB,ALL
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -hb-delay-conditional-fadd=false -stop-after=riscv-codegenprepare %s -o - | FileCheck %s --check-prefixes=OFF,ALL
; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 -mattr=+f -stop-after=riscv-codegenprepare %s -o - | FileCheck %s --check-prefixes=OFF,ALL

; Undo conditional-load add folding only when FP flags permit the fallback
; identity. Preserve the loaded path's operand order and arithmetic grouping.

; HB-LABEL: define float @delay(
; HB: loaded:
; HB-NEXT: %x = load float
; HB-NEXT: br label %join
; HB: %hb.loaded = phi float [ %x, %loaded ], [ 0.000000e+00, %entry ]
; HB: consume:
; HB-NEXT: %hb.late.add = fadd nnan nsz float %base, %hb.loaded
; HB-NEXT: %answer = fmul nnan nsz float %hb.late.add, %later
; OFF-LABEL: define float @delay(
; OFF: %sum = fadd nnan nsz float %base, %x
; OFF: %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
define float @delay(ptr %p, ptr %q, float %base, i1 %cond)  {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
  %later = load float, ptr %q
  br label %consume
consume:
  %answer = fmul nnan nsz float %merged, %later
  ret float %answer
}

; ALL-LABEL: define float @size_optimized(
; ALL: %sum = fadd nnan nsz float %base, %x
; ALL: %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
; ALL-NOT: hb.late.add
; ALL: ret float
define float @size_optimized(ptr %p, ptr %q, float %base, i1 %cond) optsize {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
  %later = load float, ptr %q
  br label %consume
consume:
  %answer = fmul nnan nsz float %merged, %later
  ret float %answer
}

; HB-LABEL: define float @delay_reversed(
; HB: loaded:
; HB-NEXT: %x = load float
; HB-NEXT: br label %join
; HB: %hb.loaded = phi float [ %x, %loaded ], [ 0.000000e+00, %entry ]
; HB: consume:
; HB-NEXT: %hb.late.add = fadd nnan nsz float %hb.loaded, %base
; HB-NEXT: %answer = fmul nnan nsz float %hb.late.add, %later
; OFF-LABEL: define float @delay_reversed(
; OFF: %sum = fadd nnan nsz float %x, %base
; OFF: %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
define float @delay_reversed(ptr %p, ptr %q, float %base, i1 %cond)  {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %x, %base
  br label %join
join:
  %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
  %later = load float, ptr %q
  br label %consume
consume:
  %answer = fmul nnan nsz float %merged, %later
  ret float %answer
}

; ALL-LABEL: define float @strict(
; ALL: %sum = fadd nnan nsz float %base, %x
; ALL: %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
; ALL-NOT: hb.late.add
; ALL: ret float
define float @strict(ptr %p, ptr %q, float %base, i1 %cond) strictfp {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
  %later = load float, ptr %q
  br label %consume
consume:
  %answer = fmul nnan nsz float %merged, %later
  ret float %answer
}

; ALL-LABEL: define float @signed_zero(
; ALL: %sum = fadd nnan float %base, %x
; ALL: %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
; ALL-NOT: hb.late.add
; ALL: ret float
define float @signed_zero(ptr %p, ptr %q, float %base, i1 %cond)  {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan float %base, %x
  br label %join
join:
  %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
  %later = load float, ptr %q
  br label %consume
consume:
  %answer = fmul nnan float %merged, %later
  ret float %answer
}

; ALL-LABEL: define float @nan(
; ALL: %sum = fadd nsz float %base, %x
; ALL: %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
; ALL-NOT: hb.late.add
; ALL: ret float
define float @nan(ptr %p, ptr %q, float %base, i1 %cond)  {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nsz float %base, %x
  br label %join
join:
  %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
  %later = load float, ptr %q
  br label %consume
consume:
  %answer = fmul nsz float %merged, %later
  ret float %answer
}

; ALL-LABEL: define float @strict_user(
; ALL: %sum = fadd nnan nsz float %base, %x
; ALL: %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
; ALL-NOT: hb.late.add
; ALL: ret float
define float @strict_user(ptr %p, ptr %q, float %base, i1 %cond)  {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
  %later = load float, ptr %q
  br label %consume
consume:
  %answer = fmul  float %merged, %later
  ret float %answer
}

; ALL-LABEL: define float @multiple_users(
; ALL: %sum = fadd nnan nsz float %base, %x
; ALL: %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
; ALL-NOT: hb.late.add
; ALL: ret float
define float @multiple_users(ptr %p, ptr %q, float %base, i1 %cond)  {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
  %later = load float, ptr %q
  br label %consume
consume:
  %answer = fmul nnan nsz float %merged, %later
  %extra = fadd nnan nsz float %answer, %merged
  ret float %extra
}

; Introducing an identity add can flush a subnormal before multiplication
; turns it into a normal result. Require ordinary IEEE denormal handling.
; ALL-LABEL: define float @flush_output(
; ALL: %sum = fadd nnan nsz float %base, %x
; ALL: %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
; ALL-NOT: hb.late.add
; ALL: ret float
define float @flush_output(ptr %p, ptr %q, float %base, i1 %cond) "denormal-fp-math-f32"="positive-zero,ieee" {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [ %sum, %loaded ], [ %base, %entry ]
  %later = load float, ptr %q
  br label %consume
consume:
  %answer = fmul nnan nsz float %merged, %later
  ret float %answer
}
