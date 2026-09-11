//===-- RISCVHBStaticBranch.cpp - Tune branches for HB32 ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVSubtarget.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/MachineBranchProbabilityInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/TargetRegisterInfo.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-hb-static-branch"
#define RISCV_HB_STATIC_BRANCH_NAME "RISC-V HammerBlade Static Branch Tuning"

namespace {

class RISCVHBStaticBranch : public MachineFunctionPass {
public:
  static char ID;

  RISCVHBStaticBranch() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override { return RISCV_HB_STATIC_BRANCH_NAME; }

  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties().set(
        MachineFunctionProperties::Property::NoVRegs);
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<MachineBranchProbabilityInfo>();
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

static bool collectReachingSeqzDefs(
    MachineBasicBlock *MBB, MachineBasicBlock::iterator Stop, Register Reg,
    const TargetRegisterInfo &TRI,
    SmallPtrSetImpl<MachineBasicBlock *> &Visiting,
    SmallVectorImpl<MachineInstr *> &Definitions,
    SmallVectorImpl<MachineInstr *> &Between, Register &Source) {
  if (!Visiting.insert(MBB).second)
    return false;

  for (auto I = Stop; I != MBB->begin();) {
    MachineInstr &MI = *--I;
    if (!MI.isDebugInstr() && MI.modifiesRegister(Reg, &TRI)) {
      bool IsSeqz =
          MI.getOpcode() == RISCV::SLTIU && MI.getOperand(0).isReg() &&
          MI.getOperand(0).getReg() == Reg && MI.getOperand(1).isReg() &&
          MI.getOperand(2).isImm() && MI.getOperand(2).getImm() == 1;
      Register ThisSource = IsSeqz ? MI.getOperand(1).getReg() : Register();
      if (!ThisSource || !ThisSource.isPhysical() || ThisSource == Reg ||
          (Source && Source != ThisSource)) {
        Visiting.erase(MBB);
        return false;
      }
      Source = ThisSource;
      if (!is_contained(Definitions, &MI))
        Definitions.push_back(&MI);
      Visiting.erase(MBB);
      return true;
    }
    Between.push_back(&MI);
  }

  if (MBB->pred_empty()) {
    Visiting.erase(MBB);
    return false;
  }
  for (MachineBasicBlock *Pred : MBB->predecessors())
    if (!collectReachingSeqzDefs(Pred, Pred->end(), Reg, TRI, Visiting,
                                 Definitions, Between, Source)) {
      Visiting.erase(MBB);
      return false;
    }
  Visiting.erase(MBB);
  return true;
}

static bool isResultDeadFrom(MachineBasicBlock *MBB,
                             MachineBasicBlock::iterator Begin,
                             MachineInstr *Definition, Register Reg,
                             const TargetRegisterInfo &TRI,
                             SmallPtrSetImpl<MachineBasicBlock *> &Visited,
                             SmallVectorImpl<MachineInstr *> &DeadDebugValues) {
  // The initial scan starts just after Definition.  Do not mark that partial
  // block as complete: a backedge may expose a use before Definition that
  // consumes the preceding iteration's value.
  if (Begin == MBB->begin() && !Visited.insert(MBB).second)
    return true;

  for (auto I = Begin; I != MBB->end(); ++I) {
    MachineInstr &MI = *I;
    if (&MI == Definition ||
        (!MI.isDebugInstr() && MI.modifiesRegister(Reg, &TRI)))
      return true;
    if (!MI.readsRegister(Reg, &TRI))
      continue;
    if (!MI.isDebugInstr())
      return false;
    DeadDebugValues.push_back(&MI);
  }

  for (MachineBasicBlock *Succ : MBB->successors())
    if (!isResultDeadFrom(Succ, Succ->begin(), Definition, Reg, TRI, Visited,
                          DeadDebugValues))
      return false;
  return true;
}

static bool removeLateSeqzBranches(MachineFunction &MF,
                                   const RISCVInstrInfo &TII) {
  const TargetRegisterInfo &TRI = *MF.getSubtarget().getRegisterInfo();
  SmallVector<MachineInstr *, 16> Branches;
  for (MachineBasicBlock &MBB : MF)
    for (MachineInstr &MI : MBB.terminators())
      if (MI.getOpcode() == RISCV::BEQ || MI.getOpcode() == RISCV::BNE)
        Branches.push_back(&MI);

  SmallVector<MachineInstr *, 16> CandidateDefinitions;
  bool Changed = false;
  for (MachineInstr *Branch : Branches) {
    unsigned RegOperand;
    if (Branch->getOperand(1).isReg() &&
        Branch->getOperand(1).getReg() == RISCV::X0)
      RegOperand = 0;
    else if (Branch->getOperand(0).isReg() &&
             Branch->getOperand(0).getReg() == RISCV::X0)
      RegOperand = 1;
    else
      continue;

    Register Reg = Branch->getOperand(RegOperand).getReg();
    if (!Reg.isPhysical() || Reg == RISCV::X0)
      continue;
    SmallPtrSet<MachineBasicBlock *, 16> Visiting;
    SmallVector<MachineInstr *, 8> Definitions;
    SmallVector<MachineInstr *, 64> Between;
    Register Source;
    if (!collectReachingSeqzDefs(Branch->getParent(), Branch->getIterator(),
                                 Reg, TRI, Visiting, Definitions, Between,
                                 Source))
      continue;

    bool SourceClobbered = any_of(Between, [&](MachineInstr *MI) {
      return !MI->isDebugInstr() && MI->modifiesRegister(Source, &TRI);
    });
    if (SourceClobbered)
      continue;

    Branch->setDesc(
        TII.get(Branch->getOpcode() == RISCV::BNE ? RISCV::BEQ : RISCV::BNE));
    Branch->getOperand(RegOperand).setReg(Source);
    Branch->getOperand(RegOperand).setIsKill(false);
    for (MachineInstr *Definition : Definitions)
      if (!is_contained(CandidateDefinitions, Definition))
        CandidateDefinitions.push_back(Definition);
    Changed = true;
  }

  for (MachineInstr *Definition : CandidateDefinitions) {
    Register Reg = Definition->getOperand(0).getReg();
    SmallPtrSet<MachineBasicBlock *, 32> Visited;
    SmallVector<MachineInstr *, 16> DeadDebugValues;
    if (!isResultDeadFrom(Definition->getParent(),
                          std::next(Definition->getIterator()), Definition, Reg,
                          TRI, Visited, DeadDebugValues))
      continue;
    for (MachineInstr *DebugValue : DeadDebugValues)
      if (DebugValue->getParent())
        DebugValue->eraseFromParent();
    Definition->eraseFromParent();
  }
  return Changed;
}

} // end anonymous namespace

char RISCVHBStaticBranch::ID = 0;

INITIALIZE_PASS_BEGIN(RISCVHBStaticBranch, DEBUG_TYPE,
                      RISCV_HB_STATIC_BRANCH_NAME, false, false)
INITIALIZE_PASS_DEPENDENCY(MachineBranchProbabilityInfo)
INITIALIZE_PASS_END(RISCVHBStaticBranch, DEBUG_TYPE,
                    RISCV_HB_STATIC_BRANCH_NAME, false, false)

bool RISCVHBStaticBranch::runOnMachineFunction(MachineFunction &MF) {
  if (skipFunction(MF.getFunction()) ||
      MF.getSubtarget<RISCVSubtarget>().getCPU() != "hb-rv32")
    return false;

  const RISCVInstrInfo *TII = MF.getSubtarget<RISCVSubtarget>().getInstrInfo();
  bool Changed = removeLateSeqzBranches(MF, *TII);
  const MachineBranchProbabilityInfo &MBPI =
      getAnalysis<MachineBranchProbabilityInfo>();
  const BranchProbability Half(1, 2);
  const BranchProbability Rare(1, 8);
  SmallPtrSet<MachineBasicBlock *, 32> EarlierBlocks;
  SmallVector<BranchCandidate, 4> Candidates;

  // HammerBlade uses the conventional static rule: backward branches are
  // predicted taken and forward branches are predicted not taken. Redirect a
  // rare backward edge through a forward trampoline placed after the return,
  // so its common not-taken path has the right static direction. For less-rare
  // edges, accept only a tightly constrained diamond: place the trampoline
  // after the fallthrough block when that block explicitly rejoins the same
  // backward target. Both forms preserve the hot fallthrough path and charge
  // the extra jump only to the less-likely edge.
  for (MachineBasicBlock &MBB : MF) {
    MachineBasicBlock *Target = nullptr;
    MachineBasicBlock *FalseTarget = nullptr;
    SmallVector<MachineOperand, 4> Cond;
    if (TII->analyzeBranch(MBB, Target, FalseTarget, Cond, false) || !Target ||
        FalseTarget || Cond.empty() || MBB.succ_size() != 2 ||
        !EarlierBlocks.count(Target)) {
      EarlierBlocks.insert(&MBB);
      continue;
    }

    BranchProbability Taken = MBPI.getEdgeProbability(&MBB, Target);
    if (Taken.isUnknown() || Taken >= Half) {
      EarlierBlocks.insert(&MBB);
      continue;
    }

    MachineBasicBlock *Fallthrough = MBB.getNextNode();
    bool OutOfLine = Taken <= Rare && !MF.back().canFallThrough();
    if (!OutOfLine) {
      if (!Fallthrough || !MBB.isSuccessor(Fallthrough) ||
          Fallthrough->succ_size() != 1 ||
          *Fallthrough->succ_begin() != Target) {
        EarlierBlocks.insert(&MBB);
        continue;
      }

      MachineBasicBlock *JoinTarget = nullptr;
      MachineBasicBlock *Unused = nullptr;
      SmallVector<MachineOperand, 4> JoinCond;
      if (TII->analyzeBranch(*Fallthrough, JoinTarget, Unused, JoinCond,
                             false) ||
          JoinTarget != Target || Unused || !JoinCond.empty()) {
        EarlierBlocks.insert(&MBB);
        continue;
      }
    }

    MachineInstr *Branch = nullptr;
    for (MachineInstr &MI : MBB.terminators())
      if (MI.getDesc().isConditionalBranch()) {
        if (Branch) {
          Branch = nullptr;
          break;
        }
        Branch = &MI;
      }
    if (Branch)
      Candidates.push_back({&MBB, Target, Fallthrough, Branch, OutOfLine});
    EarlierBlocks.insert(&MBB);
  }

  for (const BranchCandidate &Candidate : Candidates) {
    MachineBasicBlock *Trampoline = MF.CreateMachineBasicBlock();
    if (Candidate.OutOfLine)
      MF.push_back(Trampoline);
    else
      MF.insert(std::next(Candidate.Fallthrough->getIterator()), Trampoline);
    TII->insertBranch(*Trampoline, Candidate.Target, nullptr, {},
                      Candidate.Branch->getDebugLoc());
    Trampoline->addSuccessor(Candidate.Target, BranchProbability::getOne());

    for (MachineOperand &MO : Candidate.Branch->operands())
      if (MO.isMBB() && MO.getMBB() == Candidate.Target)
        MO.setMBB(Trampoline);
    Candidate.MBB->replaceSuccessor(Candidate.Target, Trampoline);
  }

  return Changed || !Candidates.empty();
}

FunctionPass *llvm::createRISCVHBStaticBranchPass() {
  return new RISCVHBStaticBranch();
}
