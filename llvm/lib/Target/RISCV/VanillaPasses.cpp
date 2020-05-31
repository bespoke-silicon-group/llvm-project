#include "RISCV.h"
#include "llvm/Pass.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {

struct VanillaPass : public MachineFunctionPass {
  static char ID;

  VanillaPass(): MachineFunctionPass(ID) {}

  bool runOnMachineFunction(MachineFunction &MF) override {
    errs() << "VanillaPass: ";
    errs() << MF.getName() << "\n";
    return false;
  }
};

}

FunctionPass* llvm::createRISCVVanillaPass() {
  return new VanillaPass();
}

char VanillaPass::ID = 0;
static RegisterPass<VanillaPass> X("vanilla", "Vanilla Pass");
