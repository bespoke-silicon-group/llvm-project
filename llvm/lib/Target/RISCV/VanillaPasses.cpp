//===-- VanillaPasses.cpp - Vanilla Subtarget specific passes --------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Implements Vanilla Core specific passes.
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "VanillaPasses.h"
#include "llvm/Pass.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineScheduler.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

/// Example Machine Function Pass for Vanilla Core
namespace {

struct VanillaPass : public MachineFunctionPass {
  static char ID;

  VanillaPass(): MachineFunctionPass(ID) {}

  bool runOnMachineFunction(MachineFunction &MF) override {
    // Do nothing
    return false;
  }
};

}

FunctionPass* llvm::createRISCVVanillaPass() {
  return new VanillaPass();
}

char VanillaPass::ID = 0;

/// Vanilla Core Scheduler
SUnit *VanillaScheduler::pickNode (bool &IsTopNode) {
  errs() << "Running Vanilla Scheduler\n";

  return GenericScheduler::pickNode(IsTopNode);
}
