// RUN: %clang -target riscv32 -mcpu=hb-rv32 -### -c %s 2>&1 \
// RUN:   | FileCheck -check-prefix=HB %s
// RUN: %clang -target riscv32 -mcpu=generic-rv32 -### -c %s 2>&1 \
// RUN:   | FileCheck -check-prefix=GENERIC %s
// RUN: not %clang -target riscv32 -mcpu=rocket-rv64 -c %s 2>&1 \
// RUN:   | FileCheck -check-prefix=WRONG-XLEN %s

// HB: "-cc1"
// HB-SAME: "-target-cpu" "hb-rv32"
// GENERIC: "-cc1"
// GENERIC-SAME: "-target-cpu" "generic-rv32"
// WRONG-XLEN: error: unknown target CPU 'rocket-rv64'
