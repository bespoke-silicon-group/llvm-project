//===-- RISCVInstrInfoHb.td - RISC-V Hb instructions --------*- tablegen -*-==//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RISC-V instructions for Hammerbalde
//
//===----------------------------------------------------------------------===//

let Predicates = [HasStdExtHb] in {

let hasSideEffects = 1, mayLoad = 1, mayStore = 1 in
def PseudoLoad4Exp : Pseudo<(outs FPRFour:$rd),
                            (ins GPR:$rs1, simm12:$imm12, GPR:$rs2),
                            [], "flw4", "$rd, ${imm12}(${rs1}), $rs2">,
                            Sched<[WriteLWD4, WriteAdr, ReadMemBase]>;
}

def : Pat<(int_riscv_flw4 BaseAddr:$rs1, GPR:$rs2),
          (PseudoLoad4Exp BaseAddr:$rs1, 0, GPR:$rs2)>;

def : Pat<(int_riscv_flw4 (add BaseAddr:$rs1, simm12:$imm12), GPR:$rs2),
          (PseudoLoad4Exp BaseAddr:$rs1, simm12:$imm12, GPR:$rs2)>;

def : Pat<(int_riscv_flw4 (IsOrAdd AddrFI:$rs1, simm12:$imm12), GPR:$rs2),
          (PseudoLoad4Exp AddrFI:$rs1, simm12:$imm12, GPR:$rs2)>;

def as_i16imm : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(N->getSExtValue() + 1, SDLoc(N), MVT::i16);
}]>;

def : Pat<(extractelt FPRFour:$rs1, imm:$imm12),
          (EXTRACT_SUBREG FPRFour:$rs1, (as_i16imm $imm12))>;
