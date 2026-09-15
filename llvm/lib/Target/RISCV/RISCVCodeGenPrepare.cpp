//===----- RISCVCodeGenPrepare.cpp ----------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This is a RISC-V specific version of CodeGenPrepare.
// It munges the code in the input function to better prepare it for
// SelectionDAG-based code generation. This works around limitations in it's
// basic-block-at-a-time approach.
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVTargetMachine.h"
#include "llvm/ADT/FloatingPointMode.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/CFG.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/PostDominators.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/IR/CFG.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstVisitor.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/PatternMatch.h"
#include "llvm/IR/ProfDataUtils.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Transforms/Utils/Local.h"
#include <optional>

using namespace llvm;

#define DEBUG_TYPE "riscv-codegenprepare"
#define PASS_NAME "RISC-V CodeGenPrepare"

static cl::opt<bool> HBDelayConditionalFAdd(
    "hb-delay-conditional-fadd", cl::Hidden, cl::init(false),
    cl::desc("Experimentally delay HB conditional-load additions"));

namespace {
class RISCVCodeGenPrepare : public InstVisitor<RISCVCodeGenPrepare, bool> {
  Function &F;
  const DataLayout *DL;
  const DominatorTree *DT;
  const RISCVSubtarget *ST;
  // The HB profitability checks need these only after finding a legal match.
  // This transform does not change the CFG, so they remain valid throughout.
  std::optional<LoopInfo> HBLI;
  std::optional<PostDominatorTree> HBPDT;
  bool HBIrreducible = false;

  bool shouldDelayHBConditionalFAdd(PHINode &PN, BinaryOperator &Add,
                                    LoadInst &Load, BinaryOperator &Use,
                                    unsigned LoadedIdx);

public:
  RISCVCodeGenPrepare(Function &F, const DominatorTree *DT,
                      const RISCVSubtarget *ST)
      : F(F), DL(&F.getDataLayout()), DT(DT), ST(ST) {}
  bool run();
  bool visitInstruction(Instruction &I) { return false; }
  bool visitAnd(BinaryOperator &BO);
  bool visitPHINode(PHINode &PN);
  bool visitIntrinsicInst(IntrinsicInst &I);
  bool expandVPStrideLoad(IntrinsicInst &I);
  bool widenVPMerge(IntrinsicInst &I);
};
} // namespace

namespace {
class RISCVCodeGenPrepareLegacyPass : public FunctionPass {
public:
  static char ID;

  RISCVCodeGenPrepareLegacyPass() : FunctionPass(ID) {}

  bool runOnFunction(Function &F) override;
  StringRef getPassName() const override { return PASS_NAME; }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    AU.addRequired<DominatorTreeWrapperPass>();
    AU.addRequired<TargetPassConfig>();
  }
};
} // namespace

// A later request cannot overlap the first load if computing its address
// already needs the merged value or another new load. Permit cheap address
// arithmetic rooted in values available at the merge, but not pointer chasing.
static bool isIndependentHBLoadAddress(Value *V, const PHINode &PN,
                                       const DominatorTree &DT,
                                       SmallPtrSetImpl<Value *> &Visited) {
  auto *I = dyn_cast<Instruction>(V);
  if (!I || DT.dominates(I, &PN))
    return V != &PN;
  if (Visited.size() >= 16 || I->mayReadOrWriteMemory() ||
      I->mayHaveSideEffects() || isa<PHINode>(I) || I->isTerminator())
    return false;
  if (!Visited.insert(I).second)
    return true;
  return llvm::all_of(I->operands(), [&](Value *Op) {
    return isIndependentHBLoadAddress(Op, PN, DT, Visited);
  });
}

// Form a bounded constant-GEP key to avoid counting duplicate requests. Do not
// chase aliases or returned pointer arguments, or make no-alias assumptions.
static std::optional<std::pair<Value *, int64_t>>
getHBLoadAddress(Value *Ptr, const DataLayout &DL) {
  APInt Offset(DL.getIndexTypeSizeInBits(Ptr->getType()), 0);
  for (unsigned Depth = 0; Depth != 16; ++Depth) {
    auto *GEP = dyn_cast<GEPOperator>(Ptr);
    if (!GEP)
      return std::make_pair(Ptr, Offset.getSExtValue());
    APInt GEPOffset(Offset.getBitWidth(), 0);
    if (!GEP->accumulateConstantOffset(DL, GEPOffset))
      return std::make_pair(Ptr, Offset.getSExtValue());
    Offset += GEPOffset;
    Ptr = GEP->getPointerOperand();
  }
  return std::nullopt;
}

bool RISCVCodeGenPrepare::shouldDelayHBConditionalFAdd(PHINode &PN,
                                                       BinaryOperator &Add,
                                                       LoadInst &Load,
                                                       BinaryOperator &Use,
                                                       unsigned LoadedIdx) {
  if (!Load.isSimple() || !Load.hasOneUse())
    return false;

  // Restrict the original execution count to a simple load/fallback triangle.
  // In particular, do not substitute an unknown multi-predecessor load count.
  BasicBlock *Fallback = PN.getIncomingBlock(1 - LoadedIdx);
  auto *Guard = dyn_cast<BranchInst>(Fallback->getTerminator());
  if (Add.getParent()->getSinglePredecessor() != Fallback || !Guard ||
      !Guard->isConditional())
    return false;
  unsigned LoadSucc = Guard->getSuccessor(0) == Add.getParent() ? 0 : 1;
  if (Guard->getSuccessor(LoadSucc) != Add.getParent() ||
      Guard->getSuccessor(1 - LoadSucc) != PN.getParent())
    return false;

  // Moving to a loop body or across an early exit can change how often the
  // identity add runs. Do not rely on a later machine pass to hoist it back.
  if (!HBLI) {
    HBLI.emplace(*DT);
    HBPDT.emplace(F);
    ReversePostOrderTraversal<Function *> RPOT(&F);
    HBIrreducible = containsIrreducibleCFG<BasicBlock *>(RPOT, *HBLI);
  }
  // LoopInfo alone does not describe repeated execution in irreducible CFGs.
  if (HBIrreducible ||
      HBLI->getLoopFor(PN.getParent()) != HBLI->getLoopFor(Use.getParent()) ||
      !HBPDT->dominates(Use.getParent(), PN.getParent()))
    return false;

  // The fallback acquires one FP add. With profile/expect information, do not
  // optimize a load arm less frequent than that fallback. Without it, a
  // balanced branch is only a profitability heuristic, not a promised gain.
  uint64_t TrueWeight, FalseWeight;
  if (extractBranchWeights(*Guard, TrueWeight, FalseWeight)) {
    uint64_t LoadWeight = LoadSucc == 0 ? TrueWeight : FalseWeight;
    uint64_t FallbackWeight = LoadSucc == 0 ? FalseWeight : TrueWeight;
    if (LoadWeight < FallbackWeight)
      return false;
  }

  // A completion barrier between the original add and its proposed consumer
  // removes the overlap opportunity. Bound this search; complicated regions
  // can retain the original code rather than guess at a benefit.
  auto PreventsOverlap = [](Instruction &I) {
    return isa<CallBase, FenceInst>(I) || I.mayWriteToMemory() ||
           (isa<LoadInst>(I) && !cast<LoadInst>(I).isSimple());
  };
  // Include the load-arm suffix, not just blocks after the merge. A fence
  // after the load (on either side of its add) has already waited for it.
  for (Instruction *I = Load.getNextNode(); I; I = I->getNextNode())
    if (PreventsOverlap(*I))
      return false;
  SmallVector<BasicBlock *, 8> Worklist = {PN.getParent()};
  SmallPtrSet<BasicBlock *, 16> VisitedBlocks;
  while (!Worklist.empty()) {
    BasicBlock *BB = Worklist.pop_back_val();
    if (!VisitedBlocks.insert(BB).second)
      continue;
    if (VisitedBlocks.size() > 16 ||
        HBLI->getLoopFor(BB) != HBLI->getLoopFor(PN.getParent()))
      return false;
    for (Instruction &I : *BB) {
      if (&I == &Use)
        break;
      if (PreventsOverlap(I))
        return false;
    }
    if (BB != Use.getParent())
      llvm::append_range(Worklist, successors(BB));
  }

  // HB issues one scalar instruction per cycle, and an FADD result takes
  // three cycles to become available to an FP arithmetic consumer. Require
  // more than that many independent useful requests (four), instead of
  // sinking across a lone load and paying the fallback add for negligible
  // scheduling room. This is an issue-window heuristic, NOT an assumed load
  // latency or an exact cycle model; cache/network latency is not fixed here.
  // In particular, cheap local loads can instead hide the ORIGINAL add's
  // result latency, and sinking can lose even with this request window. Keep
  // the transform opt-in until a reliable profitability distinction is known.
  unsigned IndependentLoads = 0;
  SmallVector<std::pair<Value *, int64_t>, 8> CountedAddresses;
  for (Instruction &I : *Use.getParent()) {
    if (&I == &Use)
      break;
    auto *Later = dyn_cast<LoadInst>(&I);
    if (!Later || !Later->isSimple() ||
        (!Later->getType()->isFloatTy() && !Later->getType()->isIntegerTy(32)))
      continue;
    SmallPtrSet<Value *, 16> Visited;
    if (!isIndependentHBLoadAddress(Later->getPointerOperand(), PN, *DT,
                                    Visited))
      continue;
    // Repeated addresses can become one load during instruction selection.
    // Deduplicate syntactically equivalent constant GEPs as well as identical
    // pointers. Distinct unknown bases may still alias at runtime; this is
    // not a proof of separate cache misses or independent memory banks.
    auto Address = getHBLoadAddress(Later->getPointerOperand(), *DL);
    if (!Address || llvm::is_contained(CountedAddresses, *Address))
      continue;
    // Dead loads or values already consumed before the insertion point do
    // not provide a live request window for the delayed arithmetic.
    bool UsedAfter = llvm::any_of(Later->users(), [&](User *U) {
      auto *UserI = dyn_cast<Instruction>(U);
      return UserI && !isa<PHINode>(UserI) &&
             (UserI == &Use || DT->dominates(&Use, UserI));
    });
    if (UsedAfter) {
      CountedAddresses.push_back(*Address);
      if (++IndependentLoads == 4)
        return true;
    }
  }
  return false;
}

// InstCombine may fold add(phi(load, 0), base) into the load's predecessor.
// On an in-order core this can wait for the load before later independent
// loads have issued. Restore the merge and delay the addition to its sole
// arithmetic consumer. Do not move/speculate the load or change FP grouping.
bool RISCVCodeGenPrepare::visitPHINode(PHINode &PN) {
  if (!HBDelayConditionalFAdd || ST->getCPU() != "hb-rv32" || F.hasOptSize() ||
      F.hasFnAttribute(Attribute::StrictFP) ||
      F.getDenormalMode(APFloat::IEEEsingle()) != DenormalMode::getIEEE() ||
      !PN.getType()->isFloatTy() || PN.getNumIncomingValues() != 2 ||
      !PN.hasOneUse())
    return false;
  auto *Use = dyn_cast<BinaryOperator>(*PN.user_begin());
  if (!Use || Use->getParent() == PN.getParent() || !isa<FPMathOperator>(Use) ||
      !Use->hasNoNaNs() || !Use->hasNoSignedZeros() || !DT->dominates(&PN, Use))
    return false;
  for (unsigned Idx = 0; Idx != 2; ++Idx) {
    auto *Add = dyn_cast<BinaryOperator>(PN.getIncomingValue(Idx));
    Value *Base = PN.getIncomingValue(1 - Idx);
    if (!Add || Add->getOpcode() != Instruction::FAdd || !Add->hasOneUse() ||
        !Add->hasNoNaNs() || !Add->hasNoSignedZeros() ||
        Add->getParent() != PN.getIncomingBlock(Idx) ||
        Add->getParent()->getSingleSuccessor() != PN.getParent() ||
        !DT->dominates(Base, Use))
      continue;
    unsigned BaseIdx = Add->getOperand(0) == Base ? 0 : 1;
    if (Add->getOperand(BaseIdx) != Base)
      continue;
    auto *Load = dyn_cast<LoadInst>(Add->getOperand(1 - BaseIdx));
    if (!Load || Load->getParent() != Add->getParent())
      continue;
    if (!shouldDelayHBConditionalFAdd(PN, *Add, *Load, *Use, Idx))
      continue;
    auto *Loaded =
        PHINode::Create(PN.getType(), 2, "hb.loaded", PN.getIterator());
    Loaded->addIncoming(Load, PN.getIncomingBlock(Idx));
    Loaded->addIncoming(ConstantFP::get(PN.getType(), 0.0),
                        PN.getIncomingBlock(1 - Idx));
    auto *Late = BinaryOperator::CreateFAdd(BaseIdx == 0 ? Base : Loaded,
                                            BaseIdx == 0 ? Loaded : Base,
                                            "hb.late.add", Use->getIterator());
    // On the fallback path the only user already ignores signed zero and
    // forbids NaNs. Other flags are intersected rather than newly promised.
    Late->setFastMathFlags(Add->getFastMathFlags() & Use->getFastMathFlags());
    Late->setDebugLoc(Add->getDebugLoc());
    PN.replaceAllUsesWith(Late);
    PN.eraseFromParent();
    Add->eraseFromParent();
    return true;
  }
  return false;
}

// Try to optimize (i64 (and (zext/sext (i32 X), C1))) if C1 has bit 31 set,
// but bits 63:32 are zero. If we know that bit 31 of X is 0, we can fill
// the upper 32 bits with ones.
bool RISCVCodeGenPrepare::visitAnd(BinaryOperator &BO) {
  if (!ST->is64Bit())
    return false;

  if (!BO.getType()->isIntegerTy(64))
    return false;

  using namespace PatternMatch;

  // Left hand side should be a zext nneg.
  Value *LHSSrc;
  if (!match(BO.getOperand(0), m_NNegZExt(m_Value(LHSSrc))))
    return false;

  if (!LHSSrc->getType()->isIntegerTy(32))
    return false;

  // Right hand side should be a constant.
  Value *RHS = BO.getOperand(1);

  auto *CI = dyn_cast<ConstantInt>(RHS);
  if (!CI)
    return false;
  uint64_t C = CI->getZExtValue();

  // Look for constants that fit in 32 bits but not simm12, and can be made
  // into simm12 by sign extending bit 31. This will allow use of ANDI.
  // TODO: Is worth making simm32?
  if (!isUInt<32>(C) || isInt<12>(C) || !isInt<12>(SignExtend64<32>(C)))
    return false;

  // Sign extend the constant and replace the And operand.
  C = SignExtend64<32>(C);
  BO.setOperand(1, ConstantInt::get(RHS->getType(), C));

  return true;
}

// With EVL tail folding, an AnyOf reduction will generate an i1 vp.merge like
// follows:
//
// loop:
//   %phi = phi <vscale x 4 x i1> [ zeroinitializer, %entry ], [ %rec, %loop ]
//   %cmp = icmp ...
//   %rec = call <vscale x 4 x i1> @llvm.vp.merge(%cmp, i1 true, %phi, %evl)
//   ...
// middle:
//   %res = call i1 @llvm.vector.reduce.or(<vscale x 4 x i1> %rec)
//
// However RVV doesn't have any tail undisturbed mask instructions and so we
// need a convoluted sequence of mask instructions to lower the i1 vp.merge: see
// llvm/test/CodeGen/RISCV/rvv/vpmerge-sdnode.ll.
//
// To avoid that this widens the i1 vp.merge to an i8 vp.merge, which will
// generate a single vmerge.vim:
//
// loop:
//   %phi = phi <vscale x 4 x i8> [ zeroinitializer, %entry ], [ %rec, %loop ]
//   %cmp = icmp ...
//   %rec = call <vscale x 4 x i8> @llvm.vp.merge(%cmp, i8 true, %phi, %evl)
//   %trunc = trunc <vscale x 4 x i8> %rec to <vscale x 4 x i1>
//   ...
// middle:
//   %res = call i1 @llvm.vector.reduce.or(<vscale x 4 x i1> %rec)
//
// The trunc will normally be sunk outside of the loop, but even if there are
// users inside the loop it is still profitable.
bool RISCVCodeGenPrepare::widenVPMerge(IntrinsicInst &II) {
  if (!II.getType()->getScalarType()->isIntegerTy(1))
    return false;

  Value *Mask, *True, *PhiV, *EVL;
  using namespace PatternMatch;
  if (!match(&II,
             m_Intrinsic<Intrinsic::vp_merge>(m_Value(Mask), m_Value(True),
                                              m_Value(PhiV), m_Value(EVL))))
    return false;

  auto *Phi = dyn_cast<PHINode>(PhiV);
  if (!Phi || !Phi->hasOneUse() || Phi->getNumIncomingValues() != 2 ||
      !match(Phi->getIncomingValue(0), m_Zero()) ||
      Phi->getIncomingValue(1) != &II)
    return false;

  Type *WideTy =
      VectorType::get(IntegerType::getInt8Ty(II.getContext()),
                      cast<VectorType>(II.getType())->getElementCount());

  IRBuilder<> Builder(Phi);
  PHINode *WidePhi = Builder.CreatePHI(WideTy, 2);
  WidePhi->addIncoming(ConstantAggregateZero::get(WideTy),
                       Phi->getIncomingBlock(0));
  Builder.SetInsertPoint(&II);
  Value *WideTrue = Builder.CreateZExt(True, WideTy);
  Value *WideMerge = Builder.CreateIntrinsic(Intrinsic::vp_merge, {WideTy},
                                             {Mask, WideTrue, WidePhi, EVL});
  WidePhi->addIncoming(WideMerge, Phi->getIncomingBlock(1));
  Value *Trunc = Builder.CreateTrunc(WideMerge, II.getType());

  II.replaceAllUsesWith(Trunc);

  // Break the cycle and delete the old chain.
  Phi->setIncomingValue(1, Phi->getIncomingValue(0));
  llvm::RecursivelyDeleteTriviallyDeadInstructions(&II);

  return true;
}

// LLVM vector reduction intrinsics return a scalar result, but on RISC-V vector
// reduction instructions write the result in the first element of a vector
// register. So when a reduction in a loop uses a scalar phi, we end up with
// unnecessary scalar moves:
//
// loop:
// vfmv.s.f v10, fa0
// vfredosum.vs v8, v8, v10
// vfmv.f.s fa0, v8
//
// This mainly affects ordered fadd reductions and VP reductions that have a
// scalar start value, since other types of reduction typically use element-wise
// vectorisation in the loop body. This tries to vectorize any scalar phis that
// feed into these reductions:
//
// loop:
// %phi = phi <float> [ ..., %entry ], [ %acc, %loop ]
// %acc = call float @llvm.vector.reduce.fadd.nxv2f32(float %phi,
//                                                    <vscale x 2 x float> %vec)
//
// ->
//
// loop:
// %phi = phi <vscale x 2 x float> [ ..., %entry ], [ %acc.vec, %loop ]
// %phi.scalar = extractelement <vscale x 2 x float> %phi, i64 0
// %acc = call float @llvm.vector.reduce.fadd.nxv2f32(float %x,
//                                                    <vscale x 2 x float> %vec)
// %acc.vec = insertelement <vscale x 2 x float> poison, float %acc.next, i64 0
//
// Which eliminates the scalar -> vector -> scalar crossing during instruction
// selection.
bool RISCVCodeGenPrepare::visitIntrinsicInst(IntrinsicInst &I) {
  if (expandVPStrideLoad(I))
    return true;

  if (widenVPMerge(I))
    return true;

  if (I.getIntrinsicID() != Intrinsic::vector_reduce_fadd &&
      !isa<VPReductionIntrinsic>(&I))
    return false;

  auto *PHI = dyn_cast<PHINode>(I.getOperand(0));
  if (!PHI || !PHI->hasOneUse() ||
      !llvm::is_contained(PHI->incoming_values(), &I))
    return false;

  Type *VecTy = I.getOperand(1)->getType();
  IRBuilder<> Builder(PHI);
  auto *VecPHI = Builder.CreatePHI(VecTy, PHI->getNumIncomingValues());

  for (auto *BB : PHI->blocks()) {
    Builder.SetInsertPoint(BB->getTerminator());
    Value *InsertElt = Builder.CreateInsertElement(
        VecTy, PHI->getIncomingValueForBlock(BB), (uint64_t)0);
    VecPHI->addIncoming(InsertElt, BB);
  }

  Builder.SetInsertPoint(&I);
  I.setOperand(0, Builder.CreateExtractElement(VecPHI, (uint64_t)0));

  PHI->eraseFromParent();

  return true;
}

// Always expand zero strided loads so we match more .vx splat patterns, even if
// we have +optimized-zero-stride-loads. RISCVDAGToDAGISel::Select will convert
// it back to a strided load if it's optimized.
bool RISCVCodeGenPrepare::expandVPStrideLoad(IntrinsicInst &II) {
  Value *BasePtr, *VL;

  using namespace PatternMatch;
  if (!match(&II, m_Intrinsic<Intrinsic::experimental_vp_strided_load>(
                      m_Value(BasePtr), m_Zero(), m_AllOnes(), m_Value(VL))))
    return false;

  // If SEW>XLEN then a splat will get lowered as a zero strided load anyway, so
  // avoid expanding here.
  if (II.getType()->getScalarSizeInBits() > ST->getXLen())
    return false;

  if (!isKnownNonZero(VL, {*DL, DT, nullptr, &II}))
    return false;

  auto *VTy = cast<VectorType>(II.getType());

  IRBuilder<> Builder(&II);
  Type *STy = VTy->getElementType();
  Value *Val = Builder.CreateLoad(STy, BasePtr);
  Value *Res = Builder.CreateIntrinsic(
      Intrinsic::vp_merge, VTy,
      {II.getOperand(2), Builder.CreateVectorSplat(VTy->getElementCount(), Val),
       PoisonValue::get(VTy), VL});

  II.replaceAllUsesWith(Res);
  II.eraseFromParent();
  return true;
}

bool RISCVCodeGenPrepare::run() {
  bool MadeChange = false;
  for (auto &BB : F)
    for (Instruction &I : llvm::make_early_inc_range(BB))
      MadeChange |= visit(I);

  return MadeChange;
}

bool RISCVCodeGenPrepareLegacyPass::runOnFunction(Function &F) {
  if (skipFunction(F))
    return false;

  auto &TPC = getAnalysis<TargetPassConfig>();
  auto &TM = TPC.getTM<RISCVTargetMachine>();
  auto ST = &TM.getSubtarget<RISCVSubtarget>(F);
  auto DT = &getAnalysis<DominatorTreeWrapperPass>().getDomTree();

  RISCVCodeGenPrepare RVCGP(F, DT, ST);
  return RVCGP.run();
}

INITIALIZE_PASS_BEGIN(RISCVCodeGenPrepareLegacyPass, DEBUG_TYPE, PASS_NAME,
                      false, false)
INITIALIZE_PASS_DEPENDENCY(TargetPassConfig)
INITIALIZE_PASS_END(RISCVCodeGenPrepareLegacyPass, DEBUG_TYPE, PASS_NAME, false,
                    false)

char RISCVCodeGenPrepareLegacyPass::ID = 0;

FunctionPass *llvm::createRISCVCodeGenPrepareLegacyPass() {
  return new RISCVCodeGenPrepareLegacyPass();
}

PreservedAnalyses RISCVCodeGenPreparePass::run(Function &F,
                                               FunctionAnalysisManager &FAM) {
  DominatorTree *DT = &FAM.getResult<DominatorTreeAnalysis>(F);
  auto ST = &TM->getSubtarget<RISCVSubtarget>(F);
  bool Changed = RISCVCodeGenPrepare(F, DT, ST).run();
  if (!Changed)
    return PreservedAnalyses::all();

  PreservedAnalyses PA = PreservedAnalyses::none();
  PA.preserveSet<CFGAnalyses>();
  return PA;
}
