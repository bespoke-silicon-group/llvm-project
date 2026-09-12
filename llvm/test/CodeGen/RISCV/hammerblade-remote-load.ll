; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f -verify-machineinstrs -misched-dcpl < %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=REMOTE
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f -riscv-hb-remote-load-latency=0 -verify-machineinstrs -misched-dcpl < %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=LOCAL
; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 -mattr=+m,+a,+f -verify-machineinstrs -misched-dcpl < %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=GENERIC
; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 -mattr=+m,+a,+f -riscv-hb-remote-load-latency=0 -verify-machineinstrs -misched-dcpl < %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=GENERIC

; Two independent chains: a short load-to-add path and a multiply chain.
; Only the annotated remote load should get the long scheduling estimate.
define i32 @remote_integer(ptr addrspace(1) %p, i32 %x) {
; REMOTE: remote_integer:
; REMOTE-NEXT: Critical Path(GS-RR ): 23
; LOCAL: remote_integer:
; LOCAL-NEXT: Critical Path(GS-RR ): 13
; GENERIC: remote_integer:
; GENERIC-NEXT: Critical Path(GS-RR ): 6
  %v = load i32, ptr addrspace(1) %p
  %a = mul i32 %x, %x
  %b = mul i32 %a, %a
  %c = mul i32 %b, %b
  %d = mul i32 %c, %c
  %e = mul i32 %d, %d
  %r = add i32 %v, %e
  ret i32 %r
}

define i32 @local_integer(ptr %p, i32 %x) {
; GENERIC: local_integer:
; GENERIC-NEXT: Critical Path(GS-RR ): 6
; REMOTE: local_integer:
; REMOTE-NEXT: Critical Path(GS-RR ): 13
; LOCAL: local_integer:
; LOCAL-NEXT: Critical Path(GS-RR ): 13
  %v = load i32, ptr %p
  %a = mul i32 %x, %x
  %b = mul i32 %a, %a
  %c = mul i32 %b, %b
  %d = mul i32 %c, %c
  %e = mul i32 %d, %d
  %r = add i32 %v, %e
  ret i32 %r
}

define float @remote_float(ptr addrspace(1) %p, float %x) {
; REMOTE: remote_float:
; REMOTE-NEXT: Critical Path(GS-RR ): 25
; LOCAL: remote_float:
; LOCAL-NEXT: Critical Path(GS-RR ): 8
; GENERIC: remote_float:
; GENERIC-NEXT: Critical Path(GS-RR ): 5
  %v = load float, ptr addrspace(1) %p
  %r = fadd float %v, %x
  ret float %r
}

; An atomic RMW is not a plain remote load; do not rewrite its edges.
define i32 @remote_atomic(ptr addrspace(1) %p, i32 %x) {
; REMOTE: remote_atomic:
; REMOTE-NEXT: Critical Path(GS-RR ): 5
; LOCAL: remote_atomic:
; LOCAL-NEXT: Critical Path(GS-RR ): 5
; GENERIC: remote_atomic:
; GENERIC-NEXT: Critical Path(GS-RR ): 5
  %v = atomicrmw add ptr addrspace(1) %p, i32 %x monotonic
  %r = add i32 %v, %x
  ret i32 %r
}
