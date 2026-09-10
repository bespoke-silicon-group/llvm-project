#!/bin/sh

# Build the LLVM/Clang components required by HammerBlade on macOS.
# The full LLVM 10 `install` target includes optional host utilities that are
# unrelated to HammerBlade and no longer all compile with current Apple Clang.

set -eu

hb_llvm_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
hb_llvm_build=${HB_LLVM_BUILD_DIR:-"$hb_llvm_root/build-hammerblade-macos"}
hb_llvm_install=${HB_LLVM_INSTALL_DIR:-"$hb_llvm_root/install-hammerblade-macos"}
hb_llvm_cmake=${HB_LLVM_CMAKE:-cmake}
hb_llvm_arch=${HB_LLVM_ARCH:-$(uname -m)}

if [ -n "${HB_LLVM_JOBS:-}" ]; then
  hb_llvm_jobs=$HB_LLVM_JOBS
elif hb_llvm_jobs=$(sysctl -n hw.ncpu 2>/dev/null); then
  :
else
  hb_llvm_jobs=$(getconf _NPROCESSORS_ONLN)
fi

"$hb_llvm_cmake" -S "$hb_llvm_root/llvm" -B "$hb_llvm_build" \
  -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$hb_llvm_install" \
  -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_OSX_ARCHITECTURES="$hb_llvm_arch" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DLLVM_ENABLE_PROJECTS=clang \
  -DLLVM_TARGETS_TO_BUILD=RISCV \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DCLANG_INCLUDE_TESTS=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_ZLIB=OFF

"$hb_llvm_cmake" --build "$hb_llvm_build" \
  --target clang llc opt --parallel "$hb_llvm_jobs"

# install-clang does not install the builtin headers on this old tree. They
# are required for newlib headers that include stddef.h and related headers.
"$hb_llvm_cmake" --build "$hb_llvm_build" \
  --target install-clang install-clang-resource-headers install-llc install-opt \
  --parallel "$hb_llvm_jobs"

"$hb_llvm_install/bin/clang" --version
"$hb_llvm_install/bin/llc" --version

printf '\nHammerBlade LLVM prefix:\n  %s\n' "$hb_llvm_install"
printf 'Pass this path as RISCV_LLVM_PATH when building device code.\n'
