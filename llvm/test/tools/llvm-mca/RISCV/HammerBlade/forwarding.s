# RUN: llvm-mca -mtriple=riscv32 -mcpu=hb-rv32 -iterations=1 -timeline < %s | FileCheck %s

# FSW consumes these values four cycles after producer issue, not three.
# LLVM-MCA-BEGIN add_store
fadd.s ft0, ft1, ft2
fsw ft0, 0(a0)
# LLVM-MCA-END
# CHECK: Code Region - add_store
# CHECK: Total Cycles:      6
# CHECK: [0,0]     DeeE .   fadd.s
# CHECK-NEXT: [0,1]     .   DE   fsw

# LLVM-MCA-BEGIN load_store
flw ft0, 0(a0)
fsw ft0, 0(a1)
# LLVM-MCA-END
# CHECK: Code Region - load_store
# CHECK: Total Cycles:      6
# CHECK: [0,0]     DeeE .   flw
# CHECK-NEXT: [0,1]     .   DE   fsw

# An FP consumer still sees the normal three-cycle arithmetic latency.
# LLVM-MCA-BEGIN add_add
fadd.s ft0, ft1, ft2
fadd.s ft3, ft0, ft2
# LLVM-MCA-END
# CHECK: Code Region - add_add
# CHECK: Total Cycles:      7
# CHECK: [0,0]     DeeE ..   fadd.s
# CHECK-NEXT: [0,1]     .  DeeE   fadd.s
