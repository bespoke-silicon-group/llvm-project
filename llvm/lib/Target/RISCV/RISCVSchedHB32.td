//===-- RISCVSchedHB32.td - HammerBlade scheduling model -------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// HammerBlade's vanilla core is a scalar, single-issue, in-order RV32 core.
// These latency and acceptance values are calibrated against the RTL rather
// than inherited from an unrelated commercial RISC-V implementation.
def HB32Model : SchedMachineModel {
  let MicroOpBufferSize = 0;
  let IssueWidth = 1;
  let LoadLatency = 2;
  let MispredictPenalty = 3;
  let CompleteModel = false;
}

let BufferSize = 0 in {
def HB32UnitALU   : ProcResource<1>;
def HB32UnitIMul  : ProcResource<1>;
def HB32UnitMem   : ProcResource<1>;
def HB32UnitB     : ProcResource<1>;
def HB32UnitFPALU : ProcResource<1>;
}

let BufferSize = 1 in {
def HB32UnitIDiv      : ProcResource<1>;
def HB32UnitFPDivSqrt : ProcResource<1>;
}

let SchedModel = HB32Model in {
def : WriteRes<WriteJmp,  [HB32UnitB]>;
def : WriteRes<WriteJal,  [HB32UnitB]>;
def : WriteRes<WriteJalr, [HB32UnitB]>;

def : WriteRes<WriteIALU,       [HB32UnitALU]>;
def : WriteRes<WriteShiftImm,   [HB32UnitALU]>;
def : WriteRes<WriteShiftReg,   [HB32UnitALU]>;
def : WriteRes<WriteCSR,        [HB32UnitALU]> { let Latency = 1; }
def : WriteRes<WriteIMul,       [HB32UnitIMul]> { let Latency = 2; }

// The current one-result-bit-per-iteration BaseJump integer divider has
// data-dependent setup and repair states. Full-core traces observe a 42-cycle
// worst case for both dependent use and back-to-back acceptance.
foreach Write = [WriteIDiv, WriteIRem] in
  def : WriteRes<Write, [HB32UnitIDiv]> {
    let Latency = 42;
    let ReleaseAtCycles = [42];
  }

foreach Write = [WriteSTB, WriteSTH, WriteSTW, WriteFST32] in
  def : WriteRes<Write, [HB32UnitMem]>;

foreach Write = [WriteLDB, WriteLDH, WriteLDW, WriteAtomicW,
                 WriteAtomicLDW] in
  def : WriteRes<Write, [HB32UnitMem]> { let Latency = 2; }

def : WriteRes<WriteFLD32, [HB32UnitMem]> { let Latency = 3; }
def : WriteRes<WriteAtomicSTW, [HB32UnitMem]>;

foreach Write = [WriteFAdd32, WriteFSGNJ32, WriteFMinMax32,
                 WriteFMul32, WriteFMA32] in
  def : WriteRes<Write, [HB32UnitFPALU]> { let Latency = 3; }

foreach Write = [WriteFCvtI32ToF32, WriteFMovI32ToF32] in
  def : WriteRes<Write, [HB32UnitFPALU]> { let Latency = 3; }

foreach Write = [WriteFCvtF32ToI32, WriteFClass32, WriteFCmp32,
                 WriteFMovF32ToI32] in
  def : WriteRes<Write, [HB32UnitFPALU]> { let Latency = 1; }

// The current HardFloat unit produces two quotient/root bits per iteration.
// It is not pipelined; dependency latency and acceptance interval differ by
// one cycle in full-core RTL traces.
def : WriteRes<WriteFDiv32, [HB32UnitFPDivSqrt]> {
  let Latency = 15;
  let ReleaseAtCycles = [16];
}
def : WriteRes<WriteFSqrt32, [HB32UnitFPDivSqrt]> {
  let Latency = 14;
  let ReleaseAtCycles = [15];
}

def : WriteRes<WriteNop, []>;
def : InstRW<[WriteIALU], (instrs COPY)>;

def : ReadAdvance<ReadJmp, 0>;
def : ReadAdvance<ReadJalr, 0>;
def : ReadAdvance<ReadCSR, 0>;
def : ReadAdvance<ReadMemBase, 0>;
def : ReadAdvance<ReadFMemBase, 0>;
def : ReadAdvance<ReadStoreData, 0>;
def : ReadAdvance<ReadFStoreData, 0>;
def : ReadAdvance<ReadIALU, 0>;
def : ReadAdvance<ReadShiftImm, 0>;
def : ReadAdvance<ReadShiftReg, 0>;
def : ReadAdvance<ReadIDiv, 0>;
def : ReadAdvance<ReadIRem, 0>;
def : ReadAdvance<ReadIMul, 0>;
def : ReadAdvance<ReadAtomicWA, 0>;
def : ReadAdvance<ReadAtomicWD, 0>;
def : ReadAdvance<ReadAtomicLDW, 0>;
def : ReadAdvance<ReadAtomicSTW, 0>;
def : ReadAdvance<ReadFAdd32, 0>;
def : ReadAdvance<ReadFMul32, 0>;
def : ReadAdvance<ReadFMA32, 0>;
def : ReadAdvance<ReadFMA32Addend, 0>;
def : ReadAdvance<ReadFDiv32, 0>;
def : ReadAdvance<ReadFSqrt32, 0>;
def : ReadAdvance<ReadFCmp32, 0>;
def : ReadAdvance<ReadFSGNJ32, 0>;
def : ReadAdvance<ReadFMinMax32, 0>;
def : ReadAdvance<ReadFCvtF32ToI32, 0>;
def : ReadAdvance<ReadFCvtI32ToF32, 0>;
def : ReadAdvance<ReadFMovF32ToI32, 0>;
def : ReadAdvance<ReadFMovI32ToF32, 0>;
def : ReadAdvance<ReadFClass32, 0>;

// Explicitly mark RV64-only and extension-only scheduling classes that cannot
// execute on this scalar RV32IMAF configuration. This also keeps TableGen from
// silently assigning an unrelated default resource model to them.
let Unsupported = true in {
def : WriteRes<WriteIALU32, []>;
def : WriteRes<WriteShiftImm32, []>;
def : WriteRes<WriteShiftReg32, []>;
def : WriteRes<WriteIMul32, []>;
def : WriteRes<WriteIDiv32, []>;
def : WriteRes<WriteIRem32, []>;
def : WriteRes<WriteSTD, []>;
def : WriteRes<WriteLDD, []>;
def : WriteRes<WriteAtomicD, []>;
def : WriteRes<WriteAtomicLDD, []>;
def : WriteRes<WriteAtomicSTD, []>;
def : WriteRes<WriteFCvtI64ToF32, []>;
def : WriteRes<WriteFCvtF32ToI64, []>;
def : ReadAdvance<ReadIALU32, 0>;
def : ReadAdvance<ReadShiftImm32, 0>;
def : ReadAdvance<ReadShiftReg32, 0>;
def : ReadAdvance<ReadIMul32, 0>;
def : ReadAdvance<ReadIDiv32, 0>;
def : ReadAdvance<ReadIRem32, 0>;
def : ReadAdvance<ReadAtomicDA, 0>;
def : ReadAdvance<ReadAtomicDD, 0>;
def : ReadAdvance<ReadAtomicLDD, 0>;
def : ReadAdvance<ReadAtomicSTD, 0>;
def : ReadAdvance<ReadFCvtI64ToF32, 0>;
def : ReadAdvance<ReadFCvtF32ToI64, 0>;
}
defm : UnsupportedSchedD;
defm : UnsupportedSchedV;
defm : UnsupportedSchedZabha;
defm : UnsupportedSchedZba;
defm : UnsupportedSchedZbb;
defm : UnsupportedSchedZbc;
defm : UnsupportedSchedZbs;
defm : UnsupportedSchedZbkb;
defm : UnsupportedSchedZbkx;
defm : UnsupportedSchedZfa;
defm : UnsupportedSchedZfhmin;
defm : UnsupportedSchedSFB;
defm : UnsupportedSchedZvk;
defm : UnsupportedSchedXsf;
}
