//===-- RISCVHBStaticBranch.cpp - Tune HB32 static branch direction --------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVSubtarget.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/CodeGen/MachineBranchProbabilityInfo.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/InitializePasses.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-hb-static-branch"
#define RISCV_HB_STATIC_BRANCH_NAME "RISC-V HammerBlade Static Branch Tuning"

static cl::opt<bool> HBStaticBranch(
    "enable-riscv-hb-static-branch", cl::Hidden, cl::init(true),
    cl::desc("Tune rare backward branches for HammerBlade's static predictor"));

namespace {
class RISCVHBStaticBranch : public MachineFunctionPass {
public:
  static char ID;
  RISCVHBStaticBranch() : MachineFunctionPass(ID) {}
  StringRef getPassName() const override { return RISCV_HB_STATIC_BRANCH_NAME; }
  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties()
        .set(MachineFunctionProperties::Property::NoVRegs)
        .set(MachineFunctionProperties::Property::NoPHIs);
  }
  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<MachineBranchProbabilityInfoWrapperPass>();
    MachineFunctionPass::getAnalysisUsage(AU);
  }
  bool runOnMachineFunction(MachineFunction &MF) override;
};

struct BranchCandidate {
  MachineBasicBlock *MBB;
  MachineBasicBlock *Target;
  MachineBasicBlock *Fallthrough;
  MachineInstr *Branch;
  bool OutOfLine;
};
} // namespace

char RISCVHBStaticBranch::ID = 0;
INITIALIZE_PASS_BEGIN(RISCVHBStaticBranch, DEBUG_TYPE,
                      RISCV_HB_STATIC_BRANCH_NAME, false, false)
INITIALIZE_PASS_DEPENDENCY(MachineBranchProbabilityInfoWrapperPass)
INITIALIZE_PASS_END(RISCVHBStaticBranch, DEBUG_TYPE,
                    RISCV_HB_STATIC_BRANCH_NAME, false, false)

bool RISCVHBStaticBranch::runOnMachineFunction(MachineFunction &MF) {
  if (!HBStaticBranch || skipFunction(MF.getFunction()) ||
      MF.getFunction().hasOptSize() ||
      MF.getSubtarget<RISCVSubtarget>().getCPU() != "hb-rv32")
    return false;

  const RISCVInstrInfo *TII = MF.getSubtarget<RISCVSubtarget>().getInstrInfo();
  const auto &MBPI =
      getAnalysis<MachineBranchProbabilityInfoWrapperPass>().getMBPI();
  SmallPtrSet<MachineBasicBlock *, 32> EarlierBlocks;
  SmallVector<BranchCandidate, 4> Candidates;

  // Backward conditional branches are predicted taken. A forward trampoline
  // preserves the common not-taken fallthrough; only the rare path pays the
  // extra unconditional jump. Do not change probability estimates. For edges
  // above 1/8 probability require a tight diamond whose fallthrough explicitly
  // jumps to the same join, so the trampoline can remain adjacent.
  for (MachineBasicBlock &MBB : MF) {
    MachineBasicBlock *Target = nullptr, *FalseTarget = nullptr;
    SmallVector<MachineOperand, 4> Cond;
    bool Backward = !TII->analyzeBranch(MBB, Target, FalseTarget, Cond, false) &&
                    Target && !FalseTarget && !Cond.empty() &&
                    MBB.succ_size() == 2 && EarlierBlocks.contains(Target);
    EarlierBlocks.insert(&MBB);
    if (!Backward)
      continue;

    BranchProbability Taken = MBPI.getEdgeProbability(&MBB, Target);
    if (Taken.isUnknown() || Taken >= BranchProbability(1, 2))
      continue;

    MachineBasicBlock *Fallthrough = MBB.getNextNode();
    if (!Fallthrough || !MBB.isSuccessor(Fallthrough))
      continue;
    bool OutOfLine = Taken <= BranchProbability(1, 8) &&
                     !MF.back().canFallThrough();
    if (!OutOfLine) {
      if (Fallthrough->succ_size() != 1 ||
          *Fallthrough->succ_begin() != Target)
        continue;
      MachineBasicBlock *JoinTarget = nullptr, *Unused = nullptr;
      SmallVector<MachineOperand, 4> JoinCond;
      if (TII->analyzeBranch(*Fallthrough, JoinTarget, Unused, JoinCond, false) ||
          JoinTarget != Target || Unused || !JoinCond.empty())
        continue;
    }

    MachineInstr *Branch = nullptr;
    for (MachineInstr &MI : MBB.terminators()) {
      if (!MI.isConditionalBranch())
        continue;
      if (Branch) {
        Branch = nullptr;
        break;
      }
      Branch = &MI;
    }
    if (Branch)
      Candidates.push_back({&MBB, Target, Fallthrough, Branch, OutOfLine});
  }

  for (const BranchCandidate &C : Candidates) {
    MachineBasicBlock *Trampoline = MF.CreateMachineBasicBlock();
    if (C.OutOfLine)
      MF.push_back(Trampoline);
    else
      MF.insert(std::next(C.Fallthrough->getIterator()), Trampoline);
    // No register values change along the new edge. Preserve all target
    // live-ins, including lane masks, for post-RA liveness and verification.
    for (const auto &LI : C.Target->liveins())
      Trampoline->addLiveIn(LI);
    TII->insertBranch(*Trampoline, C.Target, nullptr, {}, C.Branch->getDebugLoc());
    Trampoline->addSuccessor(C.Target, BranchProbability::getOne());
    for (MachineOperand &MO : C.Branch->operands())
      if (MO.isMBB() && MO.getMBB() == C.Target)
        MO.setMBB(Trampoline);
    C.MBB->replaceSuccessor(C.Target, Trampoline);
  }
  return !Candidates.empty();
}

FunctionPass *llvm::createRISCVHBStaticBranchPass() {
  return new RISCVHBStaticBranch();
}
