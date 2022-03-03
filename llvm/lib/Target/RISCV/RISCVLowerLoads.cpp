//===- RISCVLowerLoads.cpp - Lower float loads for HB       ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements a function pass that replaces a float load with an
// explicit post update with a custom load instruction with an implicit post
// update.
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVSubtarget.h"
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include <queue>
using namespace llvm;

#define DEBUG_TYPE "riscv-lower-loads"
#define RISCV_LOWER_LOADS_NAME "RISCV Lower Loads"

namespace {

class RISCVLowerLoads : public MachineFunctionPass {
  const TargetInstrInfo *TII;
  MachineRegisterInfo *MRI;

public:
  static char ID;

  RISCVLowerLoads() : MachineFunctionPass(ID) {
    initializeRISCVLowerLoadsPass(*PassRegistry::getPassRegistry());
  }
  bool runOnMachineFunction(MachineFunction &MF) override;
  bool expandMBB(MachineBasicBlock &MBB);
  bool expandMI(MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI, MachineBasicBlock::iterator &NextMBBI);
 
  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  StringRef getPassName() const override { return RISCV_LOWER_LOADS_NAME; }
};
} // end anonymous namespace

char RISCVLowerLoads::ID = 0;

INITIALIZE_PASS(RISCVLowerLoads, DEBUG_TYPE, RISCV_LOWER_LOADS_NAME,
                false, false)

bool RISCVLowerLoads::runOnMachineFunction(MachineFunction &MF) {
    llvm::errs() << "lower loads now\n";
  bool Modified = false;
  for (auto &MBB : MF)
    Modified |= expandMBB(MBB);
  return Modified;
}

bool RISCVLowerLoads::expandMBB(MachineBasicBlock &MBB) {
  bool Modified = false;

  MachineBasicBlock::iterator MBBI = MBB.begin(), E = MBB.end();
  while (MBBI != E) {
    MachineBasicBlock::iterator NMBBI = std::next(MBBI);
    Modified |= expandMI(MBB, MBBI, NMBBI);
    MBBI = NMBBI;
  }

  return Modified;
}

bool RISCVLowerLoads::expandMI(MachineBasicBlock &MBB,
                                 MachineBasicBlock::iterator MBBI,
                                 MachineBasicBlock::iterator &NextMBBI) {
  MachineRegisterInfo &MRI = MBB.getParent()->getRegInfo();
  const RISCVInstrInfo *TII =
      MBB.getParent()->getSubtarget<RISCVSubtarget>().getInstrInfo();
  if (MBBI->getOpcode() == RISCV::FLW) {
    MachineInstr &Load = *MBBI;
    assert(MBBI->getOperand(1).isReg() && "first operand not a reg");
    Register Address = MBBI->getOperand(1).getReg();
    bool LoadFound = false;
    int LoadPostUpdates = 0;
    MachineInstr *LoadAddrPostUpdate = nullptr;
    for (auto Inst : MRI.use_operands(Address)) {
      MachineInstr *MI = Inst.getParent();
      if (!LoadFound && MI == &*MBBI)
        LoadFound = true;
      if (LoadFound && MI->getOpcode() == RISCV::ADDI) {
        LoadPostUpdates += 1;
        LoadAddrPostUpdate = MI;
      }
    }
    if (LoadPostUpdates == 1) {
      MachineOperand MO = LoadAddrPostUpdate->getOperand(2);
      assert(MO.isImm() && "ADDI 2nd operand should be imm");
      if (MO.getImm() == 4) {
        LoadAddrPostUpdate->getOperand(1).setIsKill(false);
        MachineOperand OldAddr = LoadAddrPostUpdate->getOperand(1);
        MRI.replaceRegWith(LoadAddrPostUpdate->getOperand(0).getReg(),
                           OldAddr.getReg());
        LoadAddrPostUpdate->eraseFromParent();
        MRI.clearKillFlags(OldAddr.getReg());

        Register OffsetReg = MRI.createVirtualRegister(&RISCV::GPRRegClass);
        MachineInstr *ImmToReg = BuildMI(MBB, MBBI, Load.getDebugLoc(),
                                         TII->get(RISCV::ADDI), OffsetReg)
                                     .addReg(RISCV::X0)
                                     .addImm(Load.getOperand(2).getImm());

        Register TempDef = MRI.createVirtualRegister(&RISCV::GPRRegClass);
        MachineInstr *LoadPostUpdateAddr =
            BuildMI(MBB, MBBI, Load.getDebugLoc(), TII->get(RISCV::LoadRegReg),
                    Load.getOperand(0).getReg());
        LoadPostUpdateAddr->addOperand(
            MachineOperand::CreateReg(TempDef, true));
        LoadPostUpdateAddr->addOperand(Load.getOperand(1));
        LoadPostUpdateAddr->addOperand(ImmToReg->getOperand(0));
        LoadPostUpdateAddr->getOperand(3).setIsDef(false);
        Load.eraseFromParent();
        return true;
      }
    }
  }
  return false;
}

FunctionPass *llvm::createRISCVLowerLoadsPass() {
  return new RISCVLowerLoads();
}
