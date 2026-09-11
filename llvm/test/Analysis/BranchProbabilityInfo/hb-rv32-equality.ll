; RUN: opt < %s -analyze -branch-prob | FileCheck %s

; HammerBlade uses a target-specific bias for otherwise unconstrained integer
; equality. Other targets retain the generic 50/50 probability.

define i32 @hammerblade(i32 %a, i32 %b) #0 {
; CHECK-LABEL: Printing analysis 'Branch Probability Analysis' for function 'hammerblade':
; CHECK: edge entry -> equal probability is 0x0ccccccd / 0x80000000 = 10.00%
; CHECK: edge entry -> unequal probability is 0x73333333 / 0x80000000 = 90.00% [HOT edge]
entry:
  %cmp = icmp eq i32 %a, %b
  br i1 %cmp, label %equal, label %unequal

equal:
  ret i32 1

unequal:
  ret i32 0
}

define i32 @generic(i32 %a, i32 %b) {
; CHECK-LABEL: Printing analysis 'Branch Probability Analysis' for function 'generic':
; CHECK: edge entry -> equal probability is 0x40000000 / 0x80000000 = 50.00%
; CHECK: edge entry -> unequal probability is 0x40000000 / 0x80000000 = 50.00%
entry:
  %cmp = icmp eq i32 %a, %b
  br i1 %cmp, label %equal, label %unequal

equal:
  ret i32 1

unequal:
  ret i32 0
}

attributes #0 = { "target-cpu"="hb-rv32" }
