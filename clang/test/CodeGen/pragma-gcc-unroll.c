// RUN: %clang_cc1 -emit-llvm %s -o - | FileCheck %s

int sum(int *values, int count) {
  int result = 0;
#pragma GCC unroll 4
  for (int i = 0; i < count; ++i)
    result += values[i];
  return result;
}

// CHECK: br label %for.cond, !llvm.loop ![[LOOP:[0-9]+]]
// CHECK: ![[LOOP]] = distinct !{![[LOOP]], ![[COUNT:[0-9]+]]}
// CHECK: ![[COUNT]] = !{!"llvm.loop.unroll.count", i32 4}
