; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -target-abi=ilp32f -verify-machineinstrs < %s | FileCheck %s --check-prefix=POOL
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -target-abi=ilp32f -riscv-lower-fpimm-cost=3 -verify-machineinstrs < %s | FileCheck %s --check-prefix=IMM
; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 -mattr=+f -target-abi=ilp32f -verify-machineinstrs < %s | FileCheck %s --check-prefix=IMM

; Avoid the integer-producer -> FMV forwarding delay on HammerBlade.
; Preserve exact constants and the register-free positive-zero case.
define float @one() {
; POOL-LABEL: one:
; POOL: flw
; POOL-NOT: fmv.w.x
; POOL: ret
; IMM-LABEL: one:
; IMM: fmv.w.x
; IMM: ret
  ret float 1.0
}

define float @zero() {
; POOL-LABEL: zero:
; POOL: fmv.w.x {{[a-z0-9]+}}, zero
; POOL: ret
; IMM-LABEL: zero:
; IMM: fmv.w.x {{[a-z0-9]+}}, zero
; IMM: ret
  ret float 0.0
}

define float @negative_zero() {
; POOL-LABEL: negative_zero:
; POOL: lui a0, 524288
; POOL: fmv.w.x fa0, a0
; POOL: ret
; IMM-LABEL: negative_zero:
; IMM: lui a0, 524288
; IMM: fmv.w.x fa0, a0
; IMM: ret
  ret float -0.0
}
