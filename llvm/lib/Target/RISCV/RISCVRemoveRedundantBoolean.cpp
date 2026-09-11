//===-- RISCVRemoveRedundantBoolean.cpp - Simplify boolean operations ----===//
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
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetOpcodes.h"
#include "llvm/Pass.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-remove-redundant-boolean"
#define RISCV_REMOVE_REDUNDANT_BOOLEAN_NAME                                    \
  "RISC-V Remove Redundant Boolean Operations"

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
  bool isKnownZero(Register Reg, const MachineRegisterInfo &MRI) const;
  Register getSeqzSource(Register Reg,
                         const MachineRegisterInfo &MRI) const;
  Register buildUnmaterializedCondition(Register Reg, MachineBasicBlock &MBB,
                                        MachineRegisterInfo &MRI,
                                        const RISCVInstrInfo &TII) const;
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

bool RISCVRemoveRedundantBoolean::isKnownZero(
    Register Reg, const MachineRegisterInfo &MRI) const {
  if (Reg == RISCV::X0)
    return true;
  if (!Reg.isVirtual())
    return false;

  const MachineInstr *Def = MRI.getVRegDef(Reg);
  if (!Def)
    return false;
  if (Def->isCopy())
    return isKnownZero(Def->getOperand(1).getReg(), MRI);
  return Def->getOpcode() == RISCV::ADDI && Def->getOperand(1).isReg() &&
         Def->getOperand(1).getReg() == RISCV::X0 &&
         Def->getOperand(2).isImm() && Def->getOperand(2).getImm() == 0;
}

Register RISCVRemoveRedundantBoolean::getSeqzSource(
    Register Reg, const MachineRegisterInfo &MRI) const {
  if (!Reg.isVirtual())
    return Register();

  const MachineInstr *Def = MRI.getVRegDef(Reg);
  if (!Def)
    return Register();
  if (Def->isCopy())
    return getSeqzSource(Def->getOperand(1).getReg(), MRI);
  if (Def->getOpcode() == RISCV::SLTIU && Def->getOperand(2).isImm() &&
      Def->getOperand(2).getImm() == 1)
    return Def->getOperand(1).getReg();
  return Register();
}

Register RISCVRemoveRedundantBoolean::buildUnmaterializedCondition(
    Register Reg, MachineBasicBlock &MBB, MachineRegisterInfo &MRI,
    const RISCVInstrInfo &TII) const {
  if (Register Source = getSeqzSource(Reg, MRI))
    return Source;
  if (!Reg.isVirtual())
    return Register();

  MachineInstr *Def = MRI.getVRegDef(Reg);
  if (!Def || !Def->isPHI() || Def->getParent() != &MBB)
    return Register();

  SmallVector<std::pair<Register, MachineBasicBlock *>, 4> Incoming;
  for (unsigned I = 1, E = Def->getNumOperands(); I < E; I += 2) {
    if (!Def->getOperand(I).isReg() || !Def->getOperand(I + 1).isMBB())
      return Register();
    Register Source = getSeqzSource(Def->getOperand(I).getReg(), MRI);
    if (!Source)
      return Register();
    Incoming.emplace_back(Source, Def->getOperand(I + 1).getMBB());
  }

  Register NewReg = MRI.createVirtualRegister(&RISCV::GPRRegClass);
  MachineInstrBuilder NewPhi =
      BuildMI(MBB, MBB.getFirstNonPHI(), Def->getDebugLoc(),
              TII.get(TargetOpcode::PHI), NewReg);
  for (const auto &ValueAndBlock : Incoming)
    NewPhi.addReg(ValueAndBlock.first).addMBB(ValueAndBlock.second);
  return NewReg;
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
  bool Changed = !Dead.empty();

  // Replacing boolean PHIs with their full-width sources lengthens the source
  // live ranges.  It is profitable in compact branchy functions, but large
  // CFGs can pay more in register pressure than they save in seqz operations.
  if (MF.size() > 64)
    return Changed;

  const RISCVInstrInfo *TII =
      MF.getSubtarget<RISCVSubtarget>().getInstrInfo();
  SmallVector<Register, 16> DeadRoots;
  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : MBB) {
      unsigned Opcode = MI.getOpcode();
      if ((Opcode != RISCV::BEQ && Opcode != RISCV::BNE) ||
          !MI.getOperand(0).isReg() || !MI.getOperand(1).isReg())
        continue;

      unsigned CondOperand;
      if (isKnownZero(MI.getOperand(1).getReg(), MRI))
        CondOperand = 0;
      else if (isKnownZero(MI.getOperand(0).getReg(), MRI))
        CondOperand = 1;
      else
        continue;

      Register Cond = MI.getOperand(CondOperand).getReg();
      Register Value =
          buildUnmaterializedCondition(Cond, MBB, MRI, *TII);
      if (!Value)
        continue;

      MI.setDesc(TII->get(Opcode == RISCV::BNE ? RISCV::BEQ : RISCV::BNE));
      MI.getOperand(CondOperand).setReg(Value);
      MI.getOperand(CondOperand).setIsKill(false);
      DeadRoots.push_back(Cond);
      Changed = true;
    }
  }

  // Remove the old boolean PHIs as well as their seqz definitions.  Leaving
  // those now-dead chains until after register allocation creates artificial
  // live ranges and can cost more than the eliminated instructions.
  while (!DeadRoots.empty()) {
    Register Reg = DeadRoots.pop_back_val();
    if (!Reg.isVirtual() || !MRI.use_nodbg_empty(Reg))
      continue;
    MachineInstr *Def = MRI.getVRegDef(Reg);
    if (!Def || (!Def->isPHI() && !Def->isCopy() &&
                 Def->getOpcode() != RISCV::SLTIU))
      continue;
    for (const MachineOperand &MO : Def->operands())
      if (MO.isReg() && MO.isUse() && MO.getReg().isVirtual())
        DeadRoots.push_back(MO.getReg());
    Def->eraseFromParent();
  }

  return Changed;
}

FunctionPass *llvm::createRISCVRemoveRedundantBooleanPass() {
  return new RISCVRemoveRedundantBoolean();
}
