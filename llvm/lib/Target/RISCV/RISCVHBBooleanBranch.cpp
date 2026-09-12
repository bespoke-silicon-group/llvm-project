//===-- RISCVHBBooleanBranch.cpp - Fold proven post-RA Boolean branches -----===//
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
#include "llvm/CodeGen/LivePhysRegs.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/InitializePasses.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-hb-boolean-branch"
#define PASS_NAME "RISC-V HammerBlade Boolean Branch Folding"

static cl::opt<bool> HBBooleanBranches(
    "enable-riscv-hb-boolean-branches", cl::Hidden, cl::init(true),
    cl::desc("Fold proven HammerBlade post-RA zero-comparison branches"));

namespace {
class RISCVHBBooleanBranch : public MachineFunctionPass {
public:
  static char ID;
  RISCVHBBooleanBranch() : MachineFunctionPass(ID) {}
  StringRef getPassName() const override { return PASS_NAME; }
  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties()
        .set(MachineFunctionProperties::Property::NoVRegs)
        .set(MachineFunctionProperties::Property::NoPHIs);
  }
  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }
  bool runOnMachineFunction(MachineFunction &MF) override;
};

struct BooleanProof {
  Register Source;
  unsigned Opcode = 0;
  unsigned Budget = 4096;
  SmallPtrSet<MachineBasicBlock *, 16> Visiting;
  SmallPtrSet<MachineInstr *, 16> Definitions;
  SmallVector<MachineInstr *, 32> Between;
};

// Walk every reaching path. A cycle without a definition, a clobber, or an
// exhausted budget means "unknown", never permission to rewrite. Identity
// masks are transparent only after all incoming values are proved Boolean.
static bool proveBoolean(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator Stop, Register Reg,
                         const TargetRegisterInfo &TRI, BooleanProof &P) {
  if (!P.Budget-- || !P.Visiting.insert(&MBB).second)
    return false;
  for (auto I = Stop; I != MBB.begin();) {
    MachineInstr &MI = *--I;
    if (!P.Budget--)
      return false;
    if (!MI.isDebugInstr() && MI.modifiesRegister(Reg, &TRI)) {
      unsigned Op = MI.getOpcode();
      if (Op == RISCV::ANDI && MI.getOperand(0).getReg() == Reg &&
          MI.getOperand(1).getReg() == Reg && !MI.getOperand(1).isUndef() &&
          MI.getOperand(2).getImm() == 1) {
        P.Definitions.insert(&MI);
        continue;
      }
      unsigned SrcIdx = 1;
      bool IsSeqz = Op == RISCV::SLTIU && MI.getOperand(2).getImm() == 1;
      bool IsSnez = Op == RISCV::SLTU &&
                    MI.getOperand(1).getReg() == RISCV::X0;
      if (IsSnez)
        SrcIdx = 2;
      if ((!IsSeqz && !IsSnez) || MI.getOperand(0).getReg() != Reg ||
          MI.getOperand(SrcIdx).isUndef())
        return false;
      Register Source = MI.getOperand(SrcIdx).getReg();
      if (!Source.isPhysical() || Source == Reg || Source == RISCV::X0 ||
          (P.Source && (P.Source != Source || P.Opcode != Op)))
        return false;
      P.Source = Source;
      P.Opcode = Op;
      P.Definitions.insert(&MI);
      P.Visiting.erase(&MBB);
      return true;
    }
    P.Between.push_back(&MI);
  }
  if (MBB.pred_empty())
    return false;
  for (MachineBasicBlock *Pred : MBB.predecessors())
    if (!proveBoolean(*Pred, Pred->end(), Reg, TRI, P))
      return false;
  P.Visiting.erase(&MBB);
  return true;
}

// A read/modify/write is a USE of the old value, not just a killing definition.
// Scan the initial block suffix separately so a backedge can expose an earlier
// use of the preceding iteration's value.
static bool isDeadFrom(MachineBasicBlock &MBB,
                       MachineBasicBlock::iterator Begin, Register Reg,
                       const TargetRegisterInfo &TRI,
                       SmallPtrSetImpl<MachineBasicBlock *> &Visited,
                       SmallPtrSetImpl<MachineInstr *> &DebugValues,
                       unsigned &Budget) {
  if (!Budget--)
    return false;
  if (Begin == MBB.begin() && !Visited.insert(&MBB).second)
    return true;
  for (auto I = Begin; I != MBB.end(); ++I) {
    if (!Budget--)
      return false;
    MachineInstr &MI = *I;
    if (MI.readsRegister(Reg, &TRI)) {
      if (!MI.isDebugValue())
        return false;
      DebugValues.insert(&MI);
    }
    if (!MI.isDebugInstr() && MI.modifiesRegister(Reg, &TRI))
      return true;
  }
  for (MachineBasicBlock *Succ : MBB.successors())
    if (!isDeadFrom(*Succ, Succ->begin(), Reg, TRI, Visited, DebugValues, Budget))
      return false;
  return true;
}
} // namespace

char RISCVHBBooleanBranch::ID = 0;
INITIALIZE_PASS(RISCVHBBooleanBranch, DEBUG_TYPE, PASS_NAME, false, false)

bool RISCVHBBooleanBranch::runOnMachineFunction(MachineFunction &MF) {
  if (!HBBooleanBranches || skipFunction(MF.getFunction()) ||
      MF.getSubtarget<RISCVSubtarget>().getCPU() != "hb-rv32")
    return false;
  const auto &ST = MF.getSubtarget<RISCVSubtarget>();
  const auto &TRI = *ST.getRegisterInfo();
  const auto &TII = *ST.getInstrInfo();
  SmallPtrSet<MachineInstr *, 32> DeadCandidates;
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &Branch : MBB.terminators()) {
      unsigned Op = Branch.getOpcode();
      if (Op != RISCV::BEQ && Op != RISCV::BNE)
        continue;
      unsigned Operand;
      if (Branch.getOperand(1).getReg() == RISCV::X0)
        Operand = 0;
      else if (Branch.getOperand(0).getReg() == RISCV::X0)
        Operand = 1;
      else
        continue;
      Register Reg = Branch.getOperand(Operand).getReg();
      if (!Reg.isPhysical() || Reg == RISCV::X0 ||
          Branch.getOperand(Operand).isUndef())
        continue;
      BooleanProof P;
      if (!proveBoolean(MBB, Branch.getIterator(), Reg, TRI, P))
        continue;
      if (llvm::any_of(P.Between, [&](MachineInstr *MI) {
            return !MI->isDebugInstr() && MI->modifiesRegister(P.Source, &TRI);
          }))
        continue;
      if (P.Opcode == RISCV::SLTIU)
        Branch.setDesc(TII.get(Op == RISCV::BEQ ? RISCV::BNE : RISCV::BEQ));
      Branch.getOperand(Operand).setReg(P.Source);
      Branch.getOperand(Operand).setIsKill(false);
      DeadCandidates.insert(P.Definitions.begin(), P.Definitions.end());
      Changed = true;
    }
  }
  if (!Changed)
    return false;

  // Revisit definitions after removing dead masks: deleting a read/modify/write
  // can make its producer dead. Never remove a value with any remaining use.
  bool Removed;
  do {
    Removed = false;
    SmallVector<MachineInstr *, 32> Work(DeadCandidates.begin(),
                                        DeadCandidates.end());
    for (MachineInstr *MI : Work) {
      SmallPtrSet<MachineBasicBlock *, 32> Visited;
      SmallPtrSet<MachineInstr *, 16> DebugValues;
      unsigned Budget = 4096;
      if (!isDeadFrom(*MI->getParent(), std::next(MI->getIterator()),
                      MI->getOperand(0).getReg(), TRI, Visited, DebugValues,
                      Budget))
        continue;
      for (MachineInstr *DebugMI : DebugValues)
        DebugMI->setDebugValueUndef();
      DeadCandidates.erase(MI);
      MI->eraseFromParent();
      Removed = true;
    }
  } while (Removed);

  // Extending the original source's live range crosses blocks and old kill
  // flags. Recompute to a fixed point, rather than trusting stale annotations.
  SmallVector<MachineBasicBlock *, 32> Blocks;
  for (MachineBasicBlock &MBB : llvm::reverse(MF))
    Blocks.push_back(&MBB);
  fullyRecomputeLiveIns(Blocks);
  for (MachineBasicBlock &MBB : MF)
    recomputeLivenessFlags(MBB);
  return true;
}

FunctionPass *llvm::createRISCVHBBooleanBranchPass() {
  return new RISCVHBBooleanBranch();
}
