# RUN: llvm-mca -mtriple=riscv32 -mcpu=hb-rv32 -mattr=+m,+a,+f \
# RUN:   -instruction-tables < %s | FileCheck %s

# Verify the fixed-latency portions of the HammerBlade machine model against
# the current Vanilla core pipeline.  Remote loads and integer division are
# deliberately absent because their current RTL latency is variable.

mul a0, a1, a2
lb a0, 0(a1)
lh a0, 0(a1)
lw a0, 0(a1)
flw ft0, 0(a0)
fadd.s ft0, ft1, ft2
fmul.s ft0, ft1, ft2
fmadd.s ft0, ft1, ft2, ft3
fcvt.w.s a0, ft0
fclass.s a0, ft0
feq.s a0, ft0, ft1
fmv.x.w a0, ft0
fcvt.s.w ft0, a0
fmv.w.x ft0, a0
fdiv.s ft0, ft1, ft2
fsqrt.s ft0, ft1

# CHECK-LABEL: Instruction Info:
# CHECK: 1{{ +}}2{{ +}}1.00{{ +}}mul
# CHECK: 1{{ +}}2{{ +}}1.00{{ +}}*{{ +}}lb
# CHECK: 1{{ +}}2{{ +}}1.00{{ +}}*{{ +}}lh
# CHECK: 1{{ +}}2{{ +}}1.00{{ +}}*{{ +}}lw
# CHECK: 1{{ +}}3{{ +}}1.00{{ +}}*{{ +}}flw
# CHECK: 1{{ +}}3{{ +}}1.00{{ +}}fadd.s
# CHECK: 1{{ +}}3{{ +}}1.00{{ +}}fmul.s
# CHECK: 1{{ +}}3{{ +}}1.00{{ +}}fmadd.s
# CHECK: 1{{ +}}1{{ +}}1.00{{ +}}fcvt.w.s
# CHECK: 1{{ +}}1{{ +}}1.00{{ +}}fclass.s
# CHECK: 1{{ +}}1{{ +}}1.00{{ +}}feq.s
# CHECK: 1{{ +}}1{{ +}}1.00{{ +}}fmv.x.w
# CHECK: 1{{ +}}3{{ +}}1.00{{ +}}fcvt.s.w
# CHECK: 1{{ +}}3{{ +}}1.00{{ +}}fmv.w.x
# CHECK: 1{{ +}}26{{ +}}25.00{{ +}}fdiv.s
# CHECK: 1{{ +}}26{{ +}}25.00{{ +}}fsqrt.s
