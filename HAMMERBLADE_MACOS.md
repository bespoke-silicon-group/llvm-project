# HammerBlade LLVM on macOS

The HammerBlade compiler work is on the `hb-dev` branch. It is an LLVM/Clang
10 tree with the `hb-rv32` scheduling model and HammerBlade-specific RISC-V
changes. The repository's generic installer assumes a Linux host compiler
under `/opt/rh`; use the macOS component build instead:

```sh
HB_LLVM_JOBS=12 \
  ./utils/build-hammerblade-macos.sh
```

The default build and installation directories are
`build-hammerblade-macos` and `install-hammerblade-macos` in the checkout.
Override them with `HB_LLVM_BUILD_DIR` and `HB_LLVM_INSTALL_DIR`. Override the
CMake executable with `HB_LLVM_CMAKE` when it is not on `PATH`.

The script builds and installs only the components used by HammerBlade:
Clang, Clang's builtin resource headers, `llc`, and `opt`. It intentionally
does not use LLVM's full `install` target. Optional LLVM 10 host tools such as
`sancov` do not all compile with current Apple Clang, and they are not part of
the HammerBlade device compilation path.

## HammerBench integration

HammerBench's Replicant make rules lower a device source in three steps:

1. `clang`/`clang++` emits LLVM IR for RV32IMAF with the ILP32F ABI.
2. `llc -mcpu=hb-rv32` applies the HammerBlade backend and emits assembly.
3. Clang assembles the object; the established GCC/newlib toolchain performs
   the final device link.

In a generated HammerBench case, select that existing path with its opt-in
make fragment:

```sh
gmake -f Makefile -f /path/to/hb_hammerbench/mk/llvm-hammerblade.mk \
  RISCV_LLVM_PATH=/path/to/install-hammerblade-macos \
  main.so main.riscv
```

Host code remains compiled by the host compiler, and GCC remains
HammerBench's default device compiler unless the fragment is explicitly used.
