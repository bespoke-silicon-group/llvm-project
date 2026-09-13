; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -verify-machineinstrs %s -o - | FileCheck %s --check-prefixes=HB,ALL
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -hb-hoist-boundary-immediate=false %s -o - | FileCheck %s --check-prefixes=OFF,ALL
; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 %s -o - | FileCheck %s --check-prefixes=OFF,ALL

; Signed-immediate asymmetry: +2048 needs two ADDIs but -2048 needs one.
; In a loop, materialize the negative value once and subtract it each trip.
; Do not impose the extra live register on straight-line or optsize code.
; HB-LABEL: boundary_loop:
; HB: li [[STEP:[a-z0-9]+]], -2048
; HB: .LBB0_1:
; HB: sub {{[a-z0-9]+}}, {{[a-z0-9]+}}, [[STEP]]
; OFF-LABEL: boundary_loop:
; OFF: addi {{[a-z0-9]+}}, {{[a-z0-9]+}}, 2047
; OFF: addi {{[a-z0-9]+}}, {{[a-z0-9]+}}, 1
define i32 @boundary_loop(ptr %p, i32 %start, i32 %n) {
entry:
  br label %loop
loop:
  %iv = phi i32 [%start, %entry], [%next, %loop]
  store volatile i32 %iv, ptr %p
  %next = add i32 %iv, 2048
  %more = icmp slt i32 %next, %n
  br i1 %more, label %loop, label %exit
exit:
  ret i32 %next
}

; ALL-LABEL: straight_line:
; ALL: addi {{[a-z0-9]+}}, {{[a-z0-9]+}}, 2047
; ALL: addi {{[a-z0-9]+}}, {{[a-z0-9]+}}, 1
define i32 @straight_line(i32 %x) {
  %next = add i32 %x, 2048
  ret i32 %next
}

; ALL-LABEL: size_loop:
; ALL: addi {{[a-z0-9]+}}, {{[a-z0-9]+}}, 2047
; ALL: addi {{[a-z0-9]+}}, {{[a-z0-9]+}}, 1
define i32 @size_loop(ptr %p, i32 %start, i32 %n) optsize {
entry:
  br label %loop
loop:
  %iv = phi i32 [%start, %entry], [%next, %loop]
  store volatile i32 %iv, ptr %p
  %next = add i32 %iv, 2048
  %more = icmp slt i32 %next, %n
  br i1 %more, label %loop, label %exit
exit:
  ret i32 %next
}

; ALL-LABEL: immediate_fits:
; ALL: addi {{[a-z0-9]+}}, {{[a-z0-9]+}}, 2047
; ALL-NOT: sub
; ALL: ret
define i32 @immediate_fits(ptr %p, i32 %start, i32 %n) {
entry:
  br label %loop
loop:
  %iv = phi i32 [%start, %entry], [%next, %loop]
  store volatile i32 %iv, ptr %p
  %next = add i32 %iv, 2047
  %more = icmp slt i32 %next, %n
  br i1 %more, label %loop, label %exit
exit:
  ret i32 %next
}
