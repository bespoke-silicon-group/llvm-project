; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f -verify-machineinstrs %s -o /dev/null
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f -hb-split-fp-copy-edges=false -hb-hoist-boundary-immediate=false -verify-machineinstrs %s -o /dev/null
; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 -mattr=+m,+a,+f -verify-machineinstrs %s -o /dev/null

; Stress coalescing and register allocation with distinct/shared PHI sources,
; 24 simultaneously live FP values, and 28 live integer values across a loop.
; Boundary increments intentionally have no nsw/nuw assumptions: wraparound
; is valid. These functions also have a zero-trip exit.

define float @copies_4_0(ptr %p, ptr %b, i1 %cond) noinline {
entry:
  %bp0 = getelementptr float, ptr %b, i32 0
  %base0 = load volatile float, ptr %bp0
  %bp1 = getelementptr float, ptr %b, i32 1
  %base1 = load volatile float, ptr %bp1
  %bp2 = getelementptr float, ptr %b, i32 2
  %base2 = load volatile float, ptr %bp2
  %bp3 = getelementptr float, ptr %b, i32 3
  %base3 = load volatile float, ptr %bp3
  br i1 %cond, label %loaded, label %join
loaded:
  %p0 = getelementptr float, ptr %p, i32 0
  %x0 = load volatile float, ptr %p0
  %p1 = getelementptr float, ptr %p, i32 1
  %x1 = load volatile float, ptr %p1
  %p2 = getelementptr float, ptr %p, i32 2
  %x2 = load volatile float, ptr %p2
  %p3 = getelementptr float, ptr %p, i32 3
  %x3 = load volatile float, ptr %p3
  br label %join
join:
  %v0 = phi float [%x0, %loaded], [%base0, %entry]
  %v1 = phi float [%x1, %loaded], [%base1, %entry]
  %v2 = phi float [%x2, %loaded], [%base2, %entry]
  %v3 = phi float [%x3, %loaded], [%base3, %entry]
  %s1 = fadd float %v0, %v1
  %s2 = fadd float %s1, %v2
  %s3 = fadd float %s2, %v3
  ret float %s3
}

define float @copies_24_1(ptr %p, ptr %b, i1 %cond) noinline {
entry:
  %bp0 = getelementptr float, ptr %b, i32 0
  %base0 = load volatile float, ptr %bp0
  br i1 %cond, label %loaded, label %join
loaded:
  %p0 = getelementptr float, ptr %p, i32 0
  %x0 = load volatile float, ptr %p0
  %p1 = getelementptr float, ptr %p, i32 1
  %x1 = load volatile float, ptr %p1
  %p2 = getelementptr float, ptr %p, i32 2
  %x2 = load volatile float, ptr %p2
  %p3 = getelementptr float, ptr %p, i32 3
  %x3 = load volatile float, ptr %p3
  %p4 = getelementptr float, ptr %p, i32 4
  %x4 = load volatile float, ptr %p4
  %p5 = getelementptr float, ptr %p, i32 5
  %x5 = load volatile float, ptr %p5
  %p6 = getelementptr float, ptr %p, i32 6
  %x6 = load volatile float, ptr %p6
  %p7 = getelementptr float, ptr %p, i32 7
  %x7 = load volatile float, ptr %p7
  %p8 = getelementptr float, ptr %p, i32 8
  %x8 = load volatile float, ptr %p8
  %p9 = getelementptr float, ptr %p, i32 9
  %x9 = load volatile float, ptr %p9
  %p10 = getelementptr float, ptr %p, i32 10
  %x10 = load volatile float, ptr %p10
  %p11 = getelementptr float, ptr %p, i32 11
  %x11 = load volatile float, ptr %p11
  %p12 = getelementptr float, ptr %p, i32 12
  %x12 = load volatile float, ptr %p12
  %p13 = getelementptr float, ptr %p, i32 13
  %x13 = load volatile float, ptr %p13
  %p14 = getelementptr float, ptr %p, i32 14
  %x14 = load volatile float, ptr %p14
  %p15 = getelementptr float, ptr %p, i32 15
  %x15 = load volatile float, ptr %p15
  %p16 = getelementptr float, ptr %p, i32 16
  %x16 = load volatile float, ptr %p16
  %p17 = getelementptr float, ptr %p, i32 17
  %x17 = load volatile float, ptr %p17
  %p18 = getelementptr float, ptr %p, i32 18
  %x18 = load volatile float, ptr %p18
  %p19 = getelementptr float, ptr %p, i32 19
  %x19 = load volatile float, ptr %p19
  %p20 = getelementptr float, ptr %p, i32 20
  %x20 = load volatile float, ptr %p20
  %p21 = getelementptr float, ptr %p, i32 21
  %x21 = load volatile float, ptr %p21
  %p22 = getelementptr float, ptr %p, i32 22
  %x22 = load volatile float, ptr %p22
  %p23 = getelementptr float, ptr %p, i32 23
  %x23 = load volatile float, ptr %p23
  br label %join
join:
  %v0 = phi float [%x0, %loaded], [%base0, %entry]
  %v1 = phi float [%x1, %loaded], [%base0, %entry]
  %v2 = phi float [%x2, %loaded], [%base0, %entry]
  %v3 = phi float [%x3, %loaded], [%base0, %entry]
  %v4 = phi float [%x4, %loaded], [%base0, %entry]
  %v5 = phi float [%x5, %loaded], [%base0, %entry]
  %v6 = phi float [%x6, %loaded], [%base0, %entry]
  %v7 = phi float [%x7, %loaded], [%base0, %entry]
  %v8 = phi float [%x8, %loaded], [%base0, %entry]
  %v9 = phi float [%x9, %loaded], [%base0, %entry]
  %v10 = phi float [%x10, %loaded], [%base0, %entry]
  %v11 = phi float [%x11, %loaded], [%base0, %entry]
  %v12 = phi float [%x12, %loaded], [%base0, %entry]
  %v13 = phi float [%x13, %loaded], [%base0, %entry]
  %v14 = phi float [%x14, %loaded], [%base0, %entry]
  %v15 = phi float [%x15, %loaded], [%base0, %entry]
  %v16 = phi float [%x16, %loaded], [%base0, %entry]
  %v17 = phi float [%x17, %loaded], [%base0, %entry]
  %v18 = phi float [%x18, %loaded], [%base0, %entry]
  %v19 = phi float [%x19, %loaded], [%base0, %entry]
  %v20 = phi float [%x20, %loaded], [%base0, %entry]
  %v21 = phi float [%x21, %loaded], [%base0, %entry]
  %v22 = phi float [%x22, %loaded], [%base0, %entry]
  %v23 = phi float [%x23, %loaded], [%base0, %entry]
  %s1 = fadd float %v0, %v1
  %s2 = fadd float %s1, %v2
  %s3 = fadd float %s2, %v3
  %s4 = fadd float %s3, %v4
  %s5 = fadd float %s4, %v5
  %s6 = fadd float %s5, %v6
  %s7 = fadd float %s6, %v7
  %s8 = fadd float %s7, %v8
  %s9 = fadd float %s8, %v9
  %s10 = fadd float %s9, %v10
  %s11 = fadd float %s10, %v11
  %s12 = fadd float %s11, %v12
  %s13 = fadd float %s12, %v13
  %s14 = fadd float %s13, %v14
  %s15 = fadd float %s14, %v15
  %s16 = fadd float %s15, %v16
  %s17 = fadd float %s16, %v17
  %s18 = fadd float %s17, %v18
  %s19 = fadd float %s18, %v19
  %s20 = fadd float %s19, %v20
  %s21 = fadd float %s20, %v21
  %s22 = fadd float %s21, %v22
  %s23 = fadd float %s22, %v23
  ret float %s23
}

define i32 @imm_2047_0(ptr %p, ptr %values, i32 %start, i32 %n) noinline {
entry:
  %zero = icmp eq i32 %n, 0
  br i1 %zero, label %exit, label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %value = phi i32 [%start, %entry], [%next, %loop]
  %next = add i32 %value, 2047
  store volatile i32 %next, ptr %p
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  %answer = phi i32 [%start, %entry], [%next, %loop]
  ret i32 %answer
}

define i32 @imm_2048_28(ptr %p, ptr %values, i32 %start, i32 %n) noinline {
entry:
  %p0 = getelementptr i32, ptr %values, i32 0
  %v0 = load volatile i32, ptr %p0
  %p1 = getelementptr i32, ptr %values, i32 1
  %v1 = load volatile i32, ptr %p1
  %p2 = getelementptr i32, ptr %values, i32 2
  %v2 = load volatile i32, ptr %p2
  %p3 = getelementptr i32, ptr %values, i32 3
  %v3 = load volatile i32, ptr %p3
  %p4 = getelementptr i32, ptr %values, i32 4
  %v4 = load volatile i32, ptr %p4
  %p5 = getelementptr i32, ptr %values, i32 5
  %v5 = load volatile i32, ptr %p5
  %p6 = getelementptr i32, ptr %values, i32 6
  %v6 = load volatile i32, ptr %p6
  %p7 = getelementptr i32, ptr %values, i32 7
  %v7 = load volatile i32, ptr %p7
  %p8 = getelementptr i32, ptr %values, i32 8
  %v8 = load volatile i32, ptr %p8
  %p9 = getelementptr i32, ptr %values, i32 9
  %v9 = load volatile i32, ptr %p9
  %p10 = getelementptr i32, ptr %values, i32 10
  %v10 = load volatile i32, ptr %p10
  %p11 = getelementptr i32, ptr %values, i32 11
  %v11 = load volatile i32, ptr %p11
  %p12 = getelementptr i32, ptr %values, i32 12
  %v12 = load volatile i32, ptr %p12
  %p13 = getelementptr i32, ptr %values, i32 13
  %v13 = load volatile i32, ptr %p13
  %p14 = getelementptr i32, ptr %values, i32 14
  %v14 = load volatile i32, ptr %p14
  %p15 = getelementptr i32, ptr %values, i32 15
  %v15 = load volatile i32, ptr %p15
  %p16 = getelementptr i32, ptr %values, i32 16
  %v16 = load volatile i32, ptr %p16
  %p17 = getelementptr i32, ptr %values, i32 17
  %v17 = load volatile i32, ptr %p17
  %p18 = getelementptr i32, ptr %values, i32 18
  %v18 = load volatile i32, ptr %p18
  %p19 = getelementptr i32, ptr %values, i32 19
  %v19 = load volatile i32, ptr %p19
  %p20 = getelementptr i32, ptr %values, i32 20
  %v20 = load volatile i32, ptr %p20
  %p21 = getelementptr i32, ptr %values, i32 21
  %v21 = load volatile i32, ptr %p21
  %p22 = getelementptr i32, ptr %values, i32 22
  %v22 = load volatile i32, ptr %p22
  %p23 = getelementptr i32, ptr %values, i32 23
  %v23 = load volatile i32, ptr %p23
  %p24 = getelementptr i32, ptr %values, i32 24
  %v24 = load volatile i32, ptr %p24
  %p25 = getelementptr i32, ptr %values, i32 25
  %v25 = load volatile i32, ptr %p25
  %p26 = getelementptr i32, ptr %values, i32 26
  %v26 = load volatile i32, ptr %p26
  %p27 = getelementptr i32, ptr %values, i32 27
  %v27 = load volatile i32, ptr %p27
  %zero = icmp eq i32 %n, 0
  br i1 %zero, label %exit, label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %value = phi i32 [%start, %entry], [%next, %loop]
  %next = add i32 %value, 2048
  store volatile i32 %next, ptr %p
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  %answer = phi i32 [%start, %entry], [%next, %loop]
  %sum0 = add i32 %answer, %v0
  %sum1 = add i32 %sum0, %v1
  %sum2 = add i32 %sum1, %v2
  %sum3 = add i32 %sum2, %v3
  %sum4 = add i32 %sum3, %v4
  %sum5 = add i32 %sum4, %v5
  %sum6 = add i32 %sum5, %v6
  %sum7 = add i32 %sum6, %v7
  %sum8 = add i32 %sum7, %v8
  %sum9 = add i32 %sum8, %v9
  %sum10 = add i32 %sum9, %v10
  %sum11 = add i32 %sum10, %v11
  %sum12 = add i32 %sum11, %v12
  %sum13 = add i32 %sum12, %v13
  %sum14 = add i32 %sum13, %v14
  %sum15 = add i32 %sum14, %v15
  %sum16 = add i32 %sum15, %v16
  %sum17 = add i32 %sum16, %v17
  %sum18 = add i32 %sum17, %v18
  %sum19 = add i32 %sum18, %v19
  %sum20 = add i32 %sum19, %v20
  %sum21 = add i32 %sum20, %v21
  %sum22 = add i32 %sum21, %v22
  %sum23 = add i32 %sum22, %v23
  %sum24 = add i32 %sum23, %v24
  %sum25 = add i32 %sum24, %v25
  %sum26 = add i32 %sum25, %v26
  %sum27 = add i32 %sum26, %v27
  ret i32 %sum27
}

define i32 @imm_2049_0(ptr %p, ptr %values, i32 %start, i32 %n) noinline {
entry:
  %zero = icmp eq i32 %n, 0
  br i1 %zero, label %exit, label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %loop]
  %value = phi i32 [%start, %entry], [%next, %loop]
  %next = add i32 %value, 2049
  store volatile i32 %next, ptr %p
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  %answer = phi i32 [%start, %entry], [%next, %loop]
  ret i32 %answer
}
