; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -hb-delay-conditional-fadd=true -stop-after=riscv-codegenprepare -verify-machineinstrs -verify-dom-info %s -o - | FileCheck %s
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -hb-delay-conditional-fadd=true -verify-machineinstrs %s -o /dev/null
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -hb-delay-conditional-fadd=false -verify-machineinstrs %s -o /dev/null

; Keep the original computation when the consumer can be skipped, or when
; it moves into a loop. Profitability must not rely on later invariant hoisting.
; CHECK-LABEL: define float @fp_cold(
; CHECK: %x = load float, ptr %p
; CHECK: %sum = fadd nnan nsz float
; CHECK: %merged = phi float
; CHECK-NOT: hb.late.add
; CHECK: ret float
; CHECK-LABEL: define float @fp_loop(
; CHECK: %x = load float, ptr %p
; CHECK: %sum = fadd nnan nsz float
; CHECK: %merged = phi float
; CHECK-NOT: hb.late.add
; CHECK: ret float

define float @fp_cold(ptr %p, ptr %q, float %base, i1 %cond, i32 %n)  {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  %later = load float, ptr %q
  %skip = icmp eq i32 %n, 0
  br i1 %skip, label %early, label %consume
consume:
  %answer = fmul nnan nsz float %merged, %later
  ret float %answer
early:
  ret float 0.0
}
define float @fp_loop(ptr %p, ptr %q, float %base, i1 %cond, i32 %n)  {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  %later = load float, ptr %q

  %zero = icmp eq i32 %n, 0
  br i1 %zero, label %early, label %consume
consume:
  %i = phi i32 [0, %join], [%inc, %consume]
  %acc = phi float [0.0, %join], [%out, %consume]
  %product = fmul nnan nsz float %merged, %later
  %out = fadd float %acc, %product
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %consume
exit:
  ret float %out
early:
  ret float 0.0
}
