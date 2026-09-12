; RUN: opt -passes='print<branch-prob>' -disable-output < %s 2>&1 | FileCheck %s --check-prefixes=CHECK,ON
; RUN: opt -hb-integer-equality-bias=false -passes='print<branch-prob>' -disable-output < %s 2>&1 | FileCheck %s --check-prefixes=CHECK,OFF

; Only a weak tie-breaking heuristic. Profile/loop probabilities, Boolean
; values, constants, pointers, and other targets must keep their own policies.

define i32 @equal(i32 %a, i32 %b) #0 {
; CHECK-LABEL: function 'equal':
; ON: edge %entry -> %yes probability is {{.*}} = 37.50%
; ON: edge %entry -> %no probability is {{.*}} = 62.50%
; OFF: edge %entry -> %yes probability is {{.*}} = 50.00%
; OFF: edge %entry -> %no probability is {{.*}} = 50.00%
entry:
  %c = icmp eq i32 %a, %b
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}

define i32 @unequal(i32 %a, i32 %b) #0 {
; CHECK-LABEL: function 'unequal':
; ON: edge %entry -> %yes probability is {{.*}} = 62.50%
; ON: edge %entry -> %no probability is {{.*}} = 37.50%
; OFF: edge %entry -> %yes probability is {{.*}} = 50.00%
; OFF: edge %entry -> %no probability is {{.*}} = 50.00%
entry:
  %c = icmp ne i32 %a, %b
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}

define i32 @generic(i32 %a, i32 %b)  {
; CHECK-LABEL: function 'generic':
; CHECK: edge %entry -> %yes probability is {{.*}} = 50.00%
; CHECK: edge %entry -> %no probability is {{.*}} = 50.00%
entry:
  %c = icmp eq i32 %a, %b
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}

define i32 @boolean(i1 %a, i1 %b) #0 {
; CHECK-LABEL: function 'boolean':
; CHECK: edge %entry -> %yes probability is {{.*}} = 50.00%
; CHECK: edge %entry -> %no probability is {{.*}} = 50.00%
entry:
  %c = icmp eq i1 %a, %b
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}

define i32 @widened(i1 %a, i1 %b) #0 {
; CHECK-LABEL: function 'widened':
; CHECK: edge %entry -> %yes probability is {{.*}} = 50.00%
; CHECK: edge %entry -> %no probability is {{.*}} = 50.00%
entry:
  %x = zext i1 %a to i32
  %y = zext i1 %b to i32
  %c = icmp eq i32 %x, %y
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}

define i32 @signed_boolean(i1 %a, i1 %b) #0 {
; CHECK-LABEL: function 'signed_boolean':
; CHECK: edge %entry -> %yes probability is {{.*}} = 50.00%
; CHECK: edge %entry -> %no probability is {{.*}} = 50.00%
entry:
  %x = sext i1 %a to i32
  %y = sext i1 %b to i32
  %c = icmp eq i32 %x, %y
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}

define i32 @masked(i32 %a, i32 %b) #0 {
; CHECK-LABEL: function 'masked':
; CHECK: edge %entry -> %yes probability is {{.*}} = 50.00%
; CHECK: edge %entry -> %no probability is {{.*}} = 50.00%
entry:
  %x = and i32 %a, 1
  %c = icmp eq i32 %x, %b
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}

define i32 @profiled(i32 %a, i32 %b) #0 {
; CHECK-LABEL: function 'profiled':
; CHECK: edge %entry -> %yes probability is {{.*}} = 95.00%
; CHECK: edge %entry -> %no probability is {{.*}} = 5.00%
entry:
  %c = icmp eq i32 %a, %b
  br i1 %c, label %yes, label %no, !prof !0
yes:
  ret i32 1
no:
  ret i32 0
}

define i32 @loop(i32 %n) #0 {
; CHECK-LABEL: function 'loop':
; CHECK: edge %loop -> %loop probability is {{.*}} = 96.88%
; CHECK: edge %loop -> %exit probability is {{.*}} = 3.12%
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%next, %loop]
  %next = add i32 %i, 1
  %c = icmp ne i32 %next, %n
  br i1 %c, label %loop, label %exit
exit:
  ret i32 %next
}
attributes #0 = { "target-cpu"="hb-rv32" }
!0 = !{!"branch_weights", i32 95, i32 5}
