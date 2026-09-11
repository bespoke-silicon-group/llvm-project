//===-- RISCVRemoveRedundantBoolean.cpp - Remove redundant masks ---------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVSubtarget.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetOpcodes.h"
#include "llvm/Pass.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-remove-redundant-boolean"
#define RISCV_REMOVE_REDUNDANT_BOOLEAN_NAME                                    \
  "RISC-V Remove Redundant Boolean Masks"

namespace {

class RISCVRemoveRedundantBoolean : public MachineFunctionPass {
public:
  static char ID;

  RISCVRemoveRedundantBoolean() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return RISCV_REMOVE_REDUNDANT_BOOLEAN_NAME;
  }

  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties().set(
        MachineFunctionProperties::Property::IsSSA);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  bool isKnownZeroOrOne(Register Reg, const MachineRegisterInfo &MRI,
                        SmallPtrSetImpl<const MachineInstr *> &Visiting) const;
};

} // end anonymous namespace

char RISCVRemoveRedundantBoolean::ID = 0;

INITIALIZE_PASS(RISCVRemoveRedundantBoolean, "riscv-remove-redundant-boolean",
                RISCV_REMOVE_REDUNDANT_BOOLEAN_NAME, false, false)

bool RISCVRemoveRedundantBoolean::isKnownZeroOrOne(
    Register Reg, const MachineRegisterInfo &MRI,
    SmallPtrSetImpl<const MachineInstr *> &Visiting) const {
  if (!Reg.isVirtual())
    return false;

  const MachineInstr *Def = MRI.getVRegDef(Reg);
  if (!Def || !Visiting.insert(Def).second)
    return false;

  bool Known = false;
  switch (Def->getOpcode()) {
  case RISCV::SLT:
  case RISCV::SLTU:
  case RISCV::SLTI:
  case RISCV::SLTIU:
    Known = true;
    break;
  case RISCV::ANDI:
    Known = Def->getOperand(2).isImm() && Def->getOperand(2).getImm() == 1;
    break;
  case RISCV::XORI:
    Known = Def->getOperand(2).isImm() && Def->getOperand(2).getImm() == 1 &&
            isKnownZeroOrOne(Def->getOperand(1).getReg(), MRI, Visiting);
    break;
  case TargetOpcode::COPY:
    Known = isKnownZeroOrOne(Def->getOperand(1).getReg(), MRI, Visiting);
    break;
  case TargetOpcode::PHI:
    Known = true;
    for (unsigned I = 1, E = Def->getNumOperands(); I < E; I += 2) {
      const MachineOperand &Incoming = Def->getOperand(I);
      if (!Incoming.isReg() ||
          !isKnownZeroOrOne(Incoming.getReg(), MRI, Visiting)) {
        Known = false;
        break;
      }
    }
    break;
  default:
    break;
  }

  Visiting.erase(Def);
  return Known;
}

bool RISCVRemoveRedundantBoolean::runOnMachineFunction(MachineFunction &MF) {
  if (skipFunction(MF.getFunction()) ||
      MF.getSubtarget<RISCVSubtarget>().getCPU() != "hb-rv32")
    return false;

  MachineRegisterInfo &MRI = MF.getRegInfo();
  SmallVector<MachineInstr *, 4> Dead;
  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : MBB) {
      if (MI.getOpcode() != RISCV::ANDI || !MI.getOperand(2).isImm() ||
          MI.getOperand(2).getImm() != 1)
        continue;

      Register Dst = MI.getOperand(0).getReg();
      Register Src = MI.getOperand(1).getReg();
      SmallPtrSet<const MachineInstr *, 8> Visiting;
      if (!Dst.isVirtual() || !isKnownZeroOrOne(Src, MRI, Visiting))
        continue;

      MRI.replaceRegWith(Dst, Src);
      Dead.push_back(&MI);
    }
  }

  for (MachineInstr *MI : Dead)
    MI->eraseFromParent();
  return !Dead.empty();
}

FunctionPass *llvm::createRISCVRemoveRedundantBooleanPass() {
  return new RISCVRemoveRedundantBoolean();
}
