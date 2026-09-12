; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f -misched-dcpl -verify-machineinstrs < %s -o /dev/null 2>&1 | FileCheck %s

; Ordinary integer results need four cycles before the FP-stage rs1 read.
; Their latency to another integer instruction must remain unchanged.
define float @add_move(i32 %x) {
; CHECK: add_move:
; CHECK-NEXT: Critical Path(GS-RR ): 9
  %v = add i32 %x, 1
  %r = bitcast i32 %v to float
  ret float %r
}

define float @mul_convert(i32 %x, i32 %y) {
; CHECK: mul_convert:
; CHECK-NEXT: Critical Path(GS-RR ): 9
  %v = mul i32 %x, %y
  %r = sitofp i32 %v to float
  ret float %r
}

define float @compare_convert(float %x, float %y) {
; CHECK: compare_convert:
; CHECK-NEXT: Critical Path(GS-RR ): 9
  %c = fcmp oeq float %x, %y
  %v = zext i1 %c to i32
  %r = uitofp i32 %v to float
  ret float %r
}

define i32 @add_integer(i32 %x, i32 %y) {
; CHECK: add_integer:
; CHECK-NEXT: Critical Path(GS-RR ): 4
  %v = add i32 %x, 1
  %r = xor i32 %v, %y
  ret i32 %r
}

; FSW's data operand is one cycle later than an FP arithmetic consumer.
define void @add_store(ptr %dst, float %x, float %y) {
; CHECK: add_store:
; CHECK-NEXT: Critical Path(GS-RR ): 5
  %r = fadd float %x, %y
  store float %r, ptr %dst
  ret void
}
