//===-- HB32Scheduler.cpp - HB32 Subtarget specific passes -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Implements HB32 Vanilla Core specific passes.
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "HB32Scheduler.h"
#include "llvm/Pass.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineScheduler.h"
#include "llvm/CodeGen/MachineMemOperand.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

#define DEBUG_TYPE "machine-scheduler"

static cl::opt<bool>
    HB32Sched("hb32sched",
              cl::desc("Enable HB32 Vanilla Core's custom scheduler"),
              cl::init(false), cl::Hidden);

/// HB32 Vanilla Core Scheduler
SUnit *HB32Scheduler::pickNode (bool &IsTopNode) {
  // Run generic scheduler if HB32Sched is not enabled on command line
  if (!HB32Sched) {
    return GenericScheduler::pickNode(IsTopNode);
  }

  if (DAG->top() == DAG->bottom()) {
    assert(Top.Available.empty() && Top.Pending.empty() &&
           Bot.Available.empty() && Bot.Pending.empty() && "ReadyQ garbage");
    return nullptr;
  }

  SUnit *SU;

  do {
    SU = Top.pickOnlyChoice();

    // Priorotize loads from address space 1
    if (!SU) {
      for(SUnit* SUi : Top.Available) {
        MachineInstr* MI = SUi->getInstr();
        ArrayRef<MachineMemOperand*> memops = MI->memoperands();
        if (MI->mayLoad() &&
            !memops.empty() && memops[0]->getAddrSpace() == 1) {
          LLVM_DEBUG(dbgs() << "HB32Scheduler bumping load ("
                            << SUi->NodeNum << ") "
                            << *MI);
          SU = SUi;
          break;
        }
      }
    }

    // Fallback to top-down policy of generic scheduler
    if (!SU) {
      CandPolicy NoPolicy;
      TopCand.reset(NoPolicy);
      pickNodeFromQueue(Top, NoPolicy, DAG->getTopRPTracker(), TopCand);
      assert(TopCand.Reason != NoCand && "failed to find a candidate");
      SU = TopCand.SU;
    }
    IsTopNode = true;
  } while (SU->isScheduled);

  if (SU->isTopReady())
    Top.removeReady(SU);
  if (SU->isBottomReady())
    Bot.removeReady(SU);

  LLVM_DEBUG(dbgs() << "Scheduling SU(" << SU->NodeNum << ") "
                    << *SU->getInstr());
  return SU;
}
