//==- RISCVSchedHB32.td - Hammerblade Scheduling Definitions -*- tablegen -*-=//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// ===---------------------------------------------------------------------===//
// The following definitions describe the simpler per-operand machine model.
// This works with MachineScheduler. See MCSchedule.h for details.

// Hammerblade machine model for scheduling and other instruction cost heuristics.
def HB32Model : SchedMachineModel {
  let MicroOpBufferSize = 0; // Explicitly set to zero since HB is in-order.
  let IssueWidth = 1;        // 1 micro-ops are dispatched per cycle.
  let LoadLatency = 2;
  let MispredictPenalty = 3; //TODO(Emily): need to determine this value
  let CompleteModel = false;     //TODO(Emily): need to remove this if all instr. covered
  let UnsupportedFeatures = [HasStdExtV, HasStdExtZvamo, HasStdExtZvlsseg];
}

//===----------------------------------------------------------------------===//
// Define each kind of processor resource and number available.

// Modeling each pipeline as a ProcResource using the BufferSize = 0 since
// Rocket is in-order.

let BufferSize = 0 in {
def HB32UnitALU        : ProcResource<1>; // Int ALU
def HB32UnitIMul       : ProcResource<1>; // Int Multiply
def HB32UnitMem        : ProcResource<1>; // Load/Store
def HB32UnitB          : ProcResource<1>; // Branch

def HB32UnitFPALU      : ProcResource<1>; // FP ALU
}

let BufferSize = 1 in {
def HB32UnitIDiv       : ProcResource<1>; // Int Division
def HB32UnitFPDivSqrt  : ProcResource<1>; // FP Divide/Sqrt
}

//===----------------------------------------------------------------------===//
// Subtarget-specific SchedWrite types which both map the ProcResources and
// set the latency.

let SchedModel = HB32Model in {

def : WriteRes<WriteJmp, [HB32UnitB]>;
def : WriteRes<WriteJal, [HB32UnitB]>;
def : WriteRes<WriteJalr, [HB32UnitB]>;
def : WriteRes<WriteJmpReg, [HB32UnitB]>;

def : WriteRes<WriteIALU, [HB32UnitALU]>;
def : WriteRes<WriteShiftImm, [HB32UnitALU]>;

def : WriteRes<WriteIMul, [HB32UnitIMul]> { let Latency = 32; }

// 32-bit divides take 32+ cycles, TODO(Emily): we maybe want to determine worst case
def : WriteRes<WriteIDiv, [HB32UnitIDiv]> {
  let Latency = 32;
  let ResourceCycles = [32];
}

// Memory
def : WriteRes<WriteSTB, [HB32UnitMem]>;
def : WriteRes<WriteSTH, [HB32UnitMem]>;
def : WriteRes<WriteSTW, [HB32UnitMem]>;
def : WriteRes<WriteFST32, [HB32UnitMem]>;
def : WriteRes<WriteFST64, [HB32UnitMem]>;

let Latency = 3 in {
def : WriteRes<WriteLDB, [HB32UnitMem]>;
def : WriteRes<WriteLDH, [HB32UnitMem]>;
def : WriteRes<WriteCSR, [HB32UnitALU]>;
}

let Latency = 2 in {
def : WriteRes<WriteLDW, [HB32UnitMem]>;
def : WriteRes<WriteFLD32, [HB32UnitMem]>;
def : WriteRes<WriteFLD64, [HB32UnitMem]>;

def : WriteRes<WriteAtomicW, [HB32UnitMem]>;
def : WriteRes<WriteAtomicLDW, [HB32UnitMem]>;
}

def : WriteRes<WriteAtomicSTW, [HB32UnitMem]>;

// Most FP single precision operations are 4 cycles
def : WriteRes<WriteFALU32, [HB32UnitFPALU]> { let Latency = 4; }

// Most FP double precision operations are 6 cycles
def : WriteRes<WriteFALU64, [HB32UnitFPALU]> { let Latency = 6; }

let Latency = 2 in {
def : WriteRes<WriteFCvtI32ToF32, [HB32UnitFPALU]>;
def : WriteRes<WriteFCvtI32ToF64, [HB32UnitFPALU]>;
def : WriteRes<WriteFCvtF32ToI32, [HB32UnitFPALU]>;
def : WriteRes<WriteFCvtF64ToI32, [HB32UnitFPALU]>;
def : WriteRes<WriteFCvtF32ToF64, [HB32UnitFPALU]>;
def : WriteRes<WriteFCvtF64ToF32, [HB32UnitFPALU]>;

def : WriteRes<WriteFClass32, [HB32UnitFPALU]>;
def : WriteRes<WriteFClass64, [HB32UnitFPALU]>;
def : WriteRes<WriteFCmp32, [HB32UnitFPALU]>;
def : WriteRes<WriteFCmp64, [HB32UnitFPALU]>;
def : WriteRes<WriteFMovF32ToI32, [HB32UnitFPALU]>;
def : WriteRes<WriteFMovI32ToF32, [HB32UnitFPALU]>;
}

//FPU takes 4 cycles (TODO: confirm this)
let Latency = 4 in {
def : WriteRes<WriteFMul32, [HB32UnitFPALU]>;
def : WriteRes<WriteFMulAdd32, [HB32UnitFPALU]>;
def : WriteRes<WriteFMulSub32, [HB32UnitFPALU]>;
}

def : WriteRes<WriteNop, []>;

def : InstRW<[WriteIALU], (instrs COPY)>;

//TODO(Emily): need to fill out the instructions we don't support
let Unsupported = 1 in {
def : WriteRes<WriteIALU32, []>;
def : WriteRes<WriteShift32, []>;
def : WriteRes<WriteIMul32, []>;
def : WriteRes<WriteIDiv32, []>;
def : WriteRes<WriteSTD, []>;
def : WriteRes<WriteLDWU, []>;
def : WriteRes<WriteLDD, []>;
def : WriteRes<WriteFMul64, []>;
def : WriteRes<WriteFMulAdd64, []>;
def : WriteRes<WriteFMulSub64, []>;
def : WriteRes<WriteFMA64, []>;
def : WriteRes<WriteFMA32, []>;
def : WriteRes<WriteFDiv32, []>;
def : WriteRes<WriteFDiv64, []>;
def : WriteRes<WriteFSqrt32, []>;
def : WriteRes<WriteFSqrt64, []>;
def : WriteRes<WriteAtomicD, []>;
def : WriteRes<WriteAtomicLDD, []>;
def : WriteRes<WriteAtomicSTD, []>;
def : WriteRes<WriteFCvtI64ToF32, []>;
def : WriteRes<WriteFCvtI64ToF64, []>;
def : WriteRes<WriteFCvtF64ToI64, []>;
def : WriteRes<WriteFCvtF32ToI64, []>;
def : WriteRes<WriteFMovI64ToF64, []>;
def : WriteRes<WriteFMovF64ToI64, []>;
def : WriteRes<WriteFMinMax64, []>;
def : WriteRes<WriteFMinMax32, []>;
def : WriteRes<WriteFSGNJ64, []>;
def : WriteRes<WriteFSGNJ32, []>;
def : WriteRes<WriteShiftReg, []>;
def : WriteRes<WriteShiftImm32, []>;
def : WriteRes<WriteShiftReg32, []>;
}

//===----------------------------------------------------------------------===//
// Subtarget-specific SchedRead types with cycles.
// TODO(Emily): need to determine if these are supported and their cycle counts
def : ReadAdvance<ReadJmp, 0>;
def : ReadAdvance<ReadJalr, 0>;
def : ReadAdvance<ReadCSR, 0>;
def : ReadAdvance<ReadStoreData, 0>;
def : ReadAdvance<ReadMemBase, 0>;
def : ReadAdvance<ReadIALU, 0>;
def : ReadAdvance<ReadIALU32, 0>;
def : ReadAdvance<ReadShiftImm, 0>;
def : ReadAdvance<ReadShiftReg, 0>;
def : ReadAdvance<ReadShiftReg32, 0>;
def : ReadAdvance<ReadShiftImm32, 0>;
def : ReadAdvance<ReadIDiv, 0>;
def : ReadAdvance<ReadIDiv32, 0>;
def : ReadAdvance<ReadIMul, 0>;
def : ReadAdvance<ReadIMul32, 0>;
def : ReadAdvance<ReadAtomicWA, 0>;
def : ReadAdvance<ReadAtomicWD, 0>;
def : ReadAdvance<ReadAtomicDA, 0>;
def : ReadAdvance<ReadAtomicDD, 0>;
def : ReadAdvance<ReadAtomicLDW, 0>;
def : ReadAdvance<ReadAtomicLDD, 0>;
def : ReadAdvance<ReadAtomicSTW, 0>;
def : ReadAdvance<ReadAtomicSTD, 0>;
def : ReadAdvance<ReadFMemBase, 0>;
def : ReadAdvance<ReadFMinMax64, 0>;
def : ReadAdvance<ReadFMinMax32, 0>;
def : ReadAdvance<ReadFALU32, 0>;
def : ReadAdvance<ReadFALU64, 0>;
def : ReadAdvance<ReadFMA64, 0>;
def : ReadAdvance<ReadFMA32, 0>;
def : ReadAdvance<ReadFMul32, 0>;
def : ReadAdvance<ReadFMulAdd32, 0>;
def : ReadAdvance<ReadFMulSub32, 0>;
def : ReadAdvance<ReadFMul64, 0>;
def : ReadAdvance<ReadFMulAdd64, 0>;
def : ReadAdvance<ReadFMulSub64, 0>;
def : ReadAdvance<ReadFDiv32, 0>;
def : ReadAdvance<ReadFDiv64, 0>;
def : ReadAdvance<ReadFSqrt32, 0>;
def : ReadAdvance<ReadFSqrt64, 0>;
def : ReadAdvance<ReadFCmp32, 0>;
def : ReadAdvance<ReadFCmp64, 0>;
def : ReadAdvance<ReadFCvtF32ToI32, 0>;
def : ReadAdvance<ReadFCvtF32ToI64, 0>;
def : ReadAdvance<ReadFCvtF64ToI32, 0>;
def : ReadAdvance<ReadFCvtF64ToI64, 0>;
def : ReadAdvance<ReadFCvtI32ToF32, 0>;
def : ReadAdvance<ReadFCvtI32ToF64, 0>;
def : ReadAdvance<ReadFCvtI64ToF32, 0>;
def : ReadAdvance<ReadFCvtI64ToF64, 0>;
def : ReadAdvance<ReadFCvtF32ToF64, 0>;
def : ReadAdvance<ReadFCvtF64ToF32, 0>;
def : ReadAdvance<ReadFMovF32ToI32, 0>;
def : ReadAdvance<ReadFMovI32ToF32, 0>;
def : ReadAdvance<ReadFMovF64ToI64, 0>;
def : ReadAdvance<ReadFMovI64ToF64, 0>;
def : ReadAdvance<ReadFClass32, 0>;
def : ReadAdvance<ReadFClass64, 0>;
def : ReadAdvance<ReadFSGNJ32, 0>;
def : ReadAdvance<ReadFSGNJ64, 0>;

//===----------------------------------------------------------------------===//
// Unsupported extensions
defm : UnsupportedSchedV;
defm : UnsupportedSchedZba;
defm : UnsupportedSchedZbb;
defm : UnsupportedSchedZfh;
}
