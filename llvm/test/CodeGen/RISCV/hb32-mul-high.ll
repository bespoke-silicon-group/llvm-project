; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 -mattr=+m -O3 < %s \
; RUN:   | FileCheck %s --check-prefix=RV32M
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m -O3 < %s \
; RUN:   | FileCheck %s --check-prefix=HB32
;
; HammerBlade implements MUL but not the three high-word multiply operations
; from the standard M extension.  They must be expanded for hb-rv32 even when
; +m remains enabled for the supported multiply and divide instructions.

define i32 @umul_high(i32 %a, i32 %b) {
; RV32M-LABEL: umul_high:
; RV32M:       mulhu
; HB32-LABEL:  umul_high:
; HB32-NOT:    mulh
; HB32:        ret
  %wide.a = zext i32 %a to i64
  %wide.b = zext i32 %b to i64
  %product = mul i64 %wide.a, %wide.b
  %high = lshr i64 %product, 32
  %result = trunc i64 %high to i32
  ret i32 %result
}

define i32 @smul_high(i32 %a, i32 %b) {
; RV32M-LABEL: smul_high:
; RV32M:       mulh
; HB32-LABEL:  smul_high:
; HB32-NOT:    mulh
; HB32:        ret
  %wide.a = sext i32 %a to i64
  %wide.b = sext i32 %b to i64
  %product = mul i64 %wide.a, %wide.b
  %high = lshr i64 %product, 32
  %result = trunc i64 %high to i32
  ret i32 %result
}
