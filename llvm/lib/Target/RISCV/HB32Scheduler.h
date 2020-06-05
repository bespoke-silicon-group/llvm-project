//===-- HB32Scheduler.h - HB32 Subtarget specific passes ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// HB32 Vanilla Core specific passes.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_POWERPC_VANILLASCHEDULER_H
#define LLVM_LIB_TARGET_POWERPC_VANILLASCHEDULER_H

#include "llvm/CodeGen/MachineScheduler.h"

namespace llvm {

/// Creates HB32 Scheduler. This creates a custom scheduler in place of default
/// scheduler if corresponding flag is provided on the command line.
ScheduleDAGInstrs *createHB32Scheduler(MachineSchedContext *C);

/// Custom scheduler for HB32 Vanilla Core extending the generic scheduler
class HB32Scheduler : public GenericScheduler {
public:
  HB32Scheduler(const MachineSchedContext *C): GenericScheduler(C) {}

protected:
  SUnit *pickNode (bool &IsTopNode) override;
};

} // end namespace llvm

#endif // LLVM_LIB_TARGET_POWERPC_VANILLASCHEDULER_H
