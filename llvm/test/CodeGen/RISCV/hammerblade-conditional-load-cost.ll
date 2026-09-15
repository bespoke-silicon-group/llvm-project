; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -stop-after=riscv-codegenprepare %s -o - | FileCheck %s --check-prefix=OFF
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -hb-delay-conditional-fadd=true -stop-after=riscv-codegenprepare -verify-machineinstrs -verify-dom-info %s -o - | FileCheck %s --check-prefix=HB
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -hb-delay-conditional-fadd=false -stop-after=riscv-codegenprepare %s -o - | FileCheck %s --check-prefix=OFF
; RUN: llc -mtriple=riscv32 -mcpu=generic-rv32 -mattr=+f -hb-delay-conditional-fadd=true -stop-after=riscv-codegenprepare %s -o - | FileCheck %s --check-prefix=OFF
; RUN: llc -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+f -hb-delay-conditional-fadd=true -verify-machineinstrs %s -o /dev/null

; Four live independent scalar requests are only an opt-in eligibility window.
; Local-load measurements still regress: the original add can overlap its own
; result latency with these loads. The transform therefore remains default-off;
; enabling it needs workload-specific profiling, not just this request count.
; Every CFG negative has the same four-request window, isolating the frequency
; gate from the load-count gate. Profile metadata works for either branch order.

; HB-LABEL: define float @three_requests(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @three_requests(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @three_requests(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %result = fadd float %s2, 1.0
  ret float %result
}

; HB-LABEL: define float @four_requests(
; HB: %hb.loaded = phi float
; HB: %hb.late.add = fadd nnan nsz float
; HB: ret float
; OFF-LABEL: define float @four_requests(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @four_requests(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @likely_loaded(
; HB: %hb.loaded = phi float
; HB: %hb.late.add = fadd nnan nsz float
; HB: ret float
; OFF-LABEL: define float @likely_loaded(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @likely_loaded(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join, !prof !0
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @likely_fallback(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @likely_fallback(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @likely_fallback(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join, !prof !1
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @likely_loaded_reversed(
; HB: %hb.loaded = phi float
; HB: %hb.late.add = fadd nnan nsz float
; HB: ret float
; OFF-LABEL: define float @likely_loaded_reversed(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @likely_loaded_reversed(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %join, label %loaded, !prof !1
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @likely_fallback_reversed(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @likely_fallback_reversed(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @likely_fallback_reversed(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %join, label %loaded, !prof !0
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @dependent_addresses(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @dependent_addresses(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @dependent_addresses(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %root = load ptr, ptr %q
  %p0 = getelementptr float, ptr %root, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %root, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %root, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %root, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @consumed_requests(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @consumed_requests(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @consumed_requests(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %before1 = fadd float %a0, %a1
  %before2 = fadd float %before1, %a2
  %answer = fmul nnan nsz float %merged, %a3
  %result = fadd float %answer, %before2
  ret float %result
}

; HB-LABEL: define float @volatile_requests(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @volatile_requests(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @volatile_requests(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load volatile float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load volatile float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load volatile float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load volatile float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @completion_barrier(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @completion_barrier(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @completion_barrier(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  fence seq_cst
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @same_loop(
; HB: %hb.loaded = phi float
; HB: %hb.late.add = fadd nnan nsz float
; HB: ret float
; OFF-LABEL: define float @same_loop(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @same_loop(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br label %loop
loop:
  %i = phi i32 [0, %entry], [%inc, %consume]
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %loop]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %loop
exit:
  ret float %result
}

; HB-LABEL: define float @inner_loop(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @inner_loop(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @inner_loop(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  %zero = icmp eq i32 %n, 0
  br i1 %zero, label %early, label %consume
consume:
  %i = phi i32 [0, %join], [%inc, %consume]
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  %inc = add i32 %i, 1
  %done = icmp eq i32 %inc, %n
  br i1 %done, label %exit, label %consume
exit:
  ret float %result
early:
  ret float 0.0
}

; HB-LABEL: define float @early_exit(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @early_exit(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @early_exit(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  %zero = icmp eq i32 %n, 0
  br i1 %zero, label %early, label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
early:
  ret float 0.0
}


; Repeated pointers/constant GEPs cannot count as independent issued requests;
; completion boundaries in the original load arm also remove overlap.
; HB-LABEL: define float @duplicate_pointers(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @duplicate_pointers(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @duplicate_pointers(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %q
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %q
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %q
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %q
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @duplicate_constant_geps(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @duplicate_constant_geps(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @duplicate_constant_geps(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr i8, ptr %q, i32 8
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @post_add_fence(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @post_add_fence(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @post_add_fence(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  fence seq_cst
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @pre_add_fence(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @pre_add_fence(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @pre_add_fence(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  fence seq_cst
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @post_add_call(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @post_add_call(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @post_add_call(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  call void @opaque()
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; HB-LABEL: define float @pre_add_call(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @pre_add_call(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @pre_add_call(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  call void @opaque()
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  br label %consume
consume:
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  ret float %result
}

; The consumer postdominates the merge but can repeat in an irreducible
; two-entry cycle, which ordinary LoopInfo does not represent as a loop.
; HB-LABEL: define float @irreducible_consumer(
; HB: %sum = fadd nnan nsz float
; HB: %merged = phi float
; HB-NOT: hb.late.add
; HB: ret float
; OFF-LABEL: define float @irreducible_consumer(
; OFF: %sum = fadd nnan nsz float
; OFF: %merged = phi float
; OFF-NOT: hb.late.add
; OFF: ret float
define float @irreducible_consumer(ptr %p, ptr %q, float %base, i1 %cond, i32 %n) {
entry:
  br i1 %cond, label %loaded, label %join
loaded:
  %x = load float, ptr %p
  %sum = fadd nnan nsz float %base, %x
  br label %join
join:
  %merged = phi float [%sum, %loaded], [%base, %entry]
  %first = icmp eq i32 %n, 0
  br i1 %first, label %consume, label %other
other:
  %j = phi i32 [0, %join], [%i, %consume]
  %inc = add i32 %j, 1
  br label %consume
consume:
  %i = phi i32 [0, %join], [%inc, %other]
  %p0 = getelementptr float, ptr %q, i32 0
  %a0 = load float, ptr %p0
  %p1 = getelementptr float, ptr %q, i32 1
  %a1 = load float, ptr %p1
  %p2 = getelementptr float, ptr %q, i32 2
  %a2 = load float, ptr %p2
  %p3 = getelementptr float, ptr %q, i32 3
  %a3 = load float, ptr %p3
  %answer = fmul nnan nsz float %merged, %a0
  %s1 = fadd float %answer, %a1
  %s2 = fadd float %s1, %a2
  %s3 = fadd float %s2, %a3
  %result = fadd float %s3, 1.0
  %done = icmp uge i32 %i, %n
  br i1 %done, label %exit, label %other
exit:
  ret float %result
}

declare void @opaque()

!0 = !{!"branch_weights", i32 100, i32 1}
!1 = !{!"branch_weights", i32 1, i32 100}
