// RUN: %clang --target=riscv32 -mcpu=hb-rv32 -### -c %s 2>&1 \
// RUN:   | FileCheck %s --check-prefix=CPU
// RUN: %clang --target=riscv32 -march=rv32imaf -mtune=bsg_vanilla_2020 \
// RUN:   -### -c %s 2>&1 | FileCheck %s --check-prefix=TUNE

// CPU: "-target-cpu" "hb-rv32"
// CPU: "-target-feature" "+m"
// CPU: "-target-feature" "+a"
// CPU: "-target-feature" "+f"
// TUNE: "-tune-cpu" "bsg_vanilla_2020"

int hammerblade_cpu_smoke(void) { return 0; }
