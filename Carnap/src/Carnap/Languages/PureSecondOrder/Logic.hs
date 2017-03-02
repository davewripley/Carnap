{-#LANGUAGE GADTs, FlexibleContexts, PatternSynonyms, TypeSynonymInstances, FlexibleInstances, MultiParamTypeClasses #-}
module Carnap.Languages.PureSecondOrder.Logic where

import Carnap.Core.Data.Util (scopeHeight,mapover)
import Carnap.Core.Data.AbstractSyntaxDataTypes
import Carnap.Core.Data.AbstractSyntaxClasses
import Carnap.Core.Unification.Unification
import Carnap.Languages.PureSecondOrder.Syntax
import Carnap.Languages.ClassicalSequent.Syntax
import Carnap.Languages.Util.GenericConnectives
import Carnap.Languages.Util.LanguageClasses
import Carnap.Languages.PureFirstOrder.Logic (FOLogic(..))
import Carnap.Languages.PureSecondOrder.Parser
import Carnap.Languages.ClassicalSequent.Parser
import Carnap.Calculi.NaturalDeduction.Syntax
import Carnap.Calculi.NaturalDeduction.Parser
import Data.List (intercalate)
import Data.Typeable (Typeable)
import Text.Parsec

---------------------------------------
--  1.Second Order Sequent Calculus  --
---------------------------------------

type MSOLSequentCalc = ClassicalSequentOver MonadicallySOLLex

pattern SeqQuant q        = FX (Lx2 (Lx1 (Lx1 (Lx2 (Bind q)))))
pattern SeqSOMQuant q     = FX (Lx2 (Lx3 (Bind q)))
pattern SeqAbst a         = FX (Lx2 (Lx4 (Abstract a)))
-- pattern SeqSV n           = FX (Lx2 (Lx1 (Lx1 (Lx4 (StaticVar n)))))
-- pattern SeqVar c a        = FX (Lx2 (Lx1 (Lx4 (Function c a))))
-- pattern SeqV s            = SeqVar (Var s) AZero

seqv :: String -> MSOLSequentCalc (Term Int)
seqv x = liftToSequent $ SOV x

seqsov :: String -> MSOLSequentCalc (Form (Int -> Bool))
seqsov x = liftToSequent $ SOMVar x

instance ParsableLex (Form Bool) MonadicallySOLLex where
        langParser = msolFormulaParser

instance CopulaSchema MSOLSequentCalc where 

    appSchema (SeqQuant (All x)) (LLam f) e = 
        schematize (All x) (show (f $ seqv x) : e)
    appSchema (SeqQuant (Some x)) (LLam f) e = 
        schematize (Some x) (show (f $ seqv x) : e)
    appSchema (SeqSOMQuant (SOAll x)) (LLam f) e = 
        schematize (SOAll x) (show (f $ seqsov x) : e)
    appSchema (SeqSOMQuant (SOSome x)) (LLam f) e = 
        schematize (SOSome x) (show (f $ seqsov x) : e)
    appSchema (SeqAbst (SOLam v)) (LLam f) e = 
        schematize (SOLam v) (show (f $ seqv v) : e)
    appSchema x y e = schematize x (show y : e)

    lamSchema f [] = "λβ_" ++ show h ++ "." ++ show (f $ liftToSequent $ SOSV (-1 * h))
        where h = scopeHeight (LLam f)
    lamSchema f (x:xs) = "(λβ_" ++ show h ++ "." ++ show (f $ liftToSequent $ SOSV (-1 * h)) ++ intercalate " " (x:xs) ++ ")"
        where h = scopeHeight (LLam f)

data MSOLogic = ABS | APP | SOUI | SOEG | SOUD | SOED1 | SOED2 | FO FOLogic
              deriving Show

ss :: MonadicallySOL (Form Bool) -> MSOLSequentCalc Succedent
ss = SS . liftToSequent

sa :: MonadicallySOL (Form Bool) -> MSOLSequentCalc Antecedent
sa = SA . liftToSequent

tau :: MonadicallySOL (Term Int)
tau = SOT 1

phiS = SOPhi 1 AZero AZero

apply l t = SOMApp SOApp :!$: l :!$: t

-- | produces a schematic formula abstracting n terms from a given formula
lambdaScheme :: Int -> MonadicallySOL (Form Bool)
lambdaScheme n = ls' n n
        where v n = SOV $ "v_" ++ show n
              phi n | n < 1 = SOPhi 1 AOne AOne
                    | n > 0 = case incBody (phi (n - 1))  of
                                  Just p' -> mapover bump p' :!$: v 0 
                                  Nothing -> error "trouble in lambdaScheme algorithm"
              ls' n m | n < 1 = SOMApp SOApp :!$: incLam 0 (mapover bump (phi m) :!$: v 0) (v 0) :!$: SOT 0
                      | n > 0 = SOMApp SOApp :!$: incLam n (ls' (n - 1) m) (v n) :!$: SOT n
              bump (SOV s) = SOV $ "v_" ++ show (((read $ drop 2 s) :: Int) + 1)
              bump x = x

-- | produces an n-ary schematic predicate with n schematic terms for
-- arguments
predScheme :: Int -> MonadicallySOL (Form Bool)
predScheme n = phi n :!$: SOT n
        where phi n | n < 1 = SOPhi 1 AOne AOne
                    | n > 0 = case incBody (phi (n - 1)) of
                                   Just p' -> p' :!$: SOT (n - 1)
                                   Nothing -> error "trouble in predScheme algorithm"

instance Inference MSOLogic MonadicallySOLLex where
        premisesOf ABS    = [ GammaV 1 :|-: ss (predScheme 0)]
        premisesOf APP    = [ GammaV 1 :|-: ss (lambdaScheme 0)]
        premisesOf SOUI   = [ GammaV 1 :|-: ss (SOMBind (SOAll "v") (\x -> SOMCtx 1 :!$: x))]
        premisesOf SOEG   = [ GammaV 1 :|-: ss (SOMCtx 1 :!$: SOMScheme 1)]
        premisesOf SOUD   = [ GammaV 1 :|-: ss (SOMCtx 1 :!$: SOMScheme 1)]
        premisesOf SOED1  = [ GammaV 1 :+: sa (SOMCtx 1 :!$: SOMScheme 1) :|-: ss phiS
                            , GammaV 2 :|-: ss (SOMBind (SOSome "v") (\x -> SOMCtx 1 :!$: x))
                            ]
        premisesOf SOED1  = [ GammaV 1 :+: sa (SOMCtx 1 :!$: SOMScheme 1) :|-: ss phiS
                            , GammaV 2 :|-: ss (SOMBind (SOSome "v") (\x -> SOMCtx 1 :!$: x))
                            ]
        premisesOf SOED2  = [ GammaV 1 :|-: ss phiS
                            , GammaV 2 :|-: ss (SOMBind (SOSome "v") (\x -> SOMCtx 1 :!$: x))
                            ]
        premisesOf (FO x) = map liftSequent (premisesOf x)

        conclusionOf ABS    = GammaV 1 :|-: ss (lambdaScheme 0)
        conclusionOf APP    = GammaV 1 :|-: ss (predScheme 0)
        conclusionOf SOUI   = GammaV 1 :|-: ss (SOMCtx 1 :!$: SOMScheme 1)
        conclusionOf SOEG   = GammaV 1 :|-: ss (SOMBind (SOSome "v") (\x -> SOMCtx 1 :!$: x))
        conclusionOf SOUD   = GammaV 1 :|-: ss (SOMBind (SOAll "v") (\x -> SOMCtx 1 :!$: x))
        conclusionOf SOED1  = GammaV 1 :+: GammaV 2 :|-: ss phiS
        conclusionOf SOED2  = GammaV 1 :+: GammaV 2 :|-: ss phiS
        conclusionOf (FO x) = liftSequent (conclusionOf x)

        restriction SOUD     = Just (mpredicateEigenConstraint 
                                        (liftToSequent $ SOMScheme 1) 
                                        (ss (SOMBind (SOAll "v") (\x -> SOMCtx 1 :!$: x)))  
                                        (GammaV 1))

        restriction SOED1    = Just (mpredicateEigenConstraint
                                        (liftToSequent $ SOMScheme 1)
                                        (ss (SOMBind (SOSome "v") (\x -> SOMCtx 1 :!$: x))
                                            :-: ss phiS)
                                        (GammaV 1 :+: GammaV 2))
        restriction (FO UD)  = Just (eigenConstraint stau 
                                        (ss $ SOBind (All "v") phi) 
                                        (GammaV 1))
            where phi x = SOPhi 1 AOne AOne :!$: x
                  stau = liftToSequent tau

        restriction (FO ED1) = Just (eigenConstraint stau 
                                        ((ss $ SOBind (Some "v") phi) :-: ss phiS) 
                                        (GammaV 1 :+: GammaV 2))
            where phi x = SOPhi 1 AOne AOne :!$: x
                  
                  stau = liftToSequent tau
        restriction _ = Nothing

-- TODO unify the different kinds of eigenconstrants using a prism for the
-- case deconstruction below.
mpredicateEigenConstraint c suc ant sub
    | c' `occursIn` ant' = Just $ "The predicate " ++ show c' ++ " appears not to be fresh, given that this line relies on " ++ show ant'
    | c' `occursIn` suc' = Just $ "The predicate " ++ show c' ++ " appears not to be fresh in the other premise " ++ show suc'
    | otherwise = Nothing
                    -- case fromSequent c' of
                    --   SOPred _ _ -> Nothing
                    --   _ -> Just $ "the expression " ++ show c' ++ " appears not to be a predicate."

    where c'   = applySub sub c
          ant' = applySub sub ant
          suc' = applySub sub suc
          -- XXX : this is not the most efficient way of checking
          -- imaginable.
          occursIn x y = not $ (subst x (static 0) y) =* y

eigenConstraint c suc ant sub
    | c' `occursIn` ant' = Just $ "The constant " ++ show c' ++ " appears not to be fresh, given that this line relies on " ++ show ant'
    | c' `occursIn` suc' = Just $ "The constant " ++ show c' ++ " appears not to be fresh in the other premise " ++ show suc'
    | otherwise = case fromSequent c' of 
                          SOC _ -> Nothing
                          SOT _ -> Nothing
                          _ -> Just $ "The term " ++ show c' ++ " is not a constant"
    where c' = applySub sub c
          ant' = applySub sub ant
          suc' = applySub sub suc
          -- XXX : this is not the most efficient way of checking
          -- imaginable.
          occursIn x y = not $ (subst x (static 0) y) =* y

-- XXX Skipping derived rules for now.
parseMSOLogic :: Parsec String u [MSOLogic]
parseMSOLogic = do r <- choice (map (try . string) 
                            [ "AS","PR","MP","MTP","MT","DD","DNE"
                            , "DNI", "DN", "S", "ADJ",  "ADD" , "BC"
                            , "CB",  "CD", "ID", "UI", "UD", "EG", "ED"
                            , "D-", "QN","ABS","APP"])
                   case r of "AS"   -> return [FO AX]
                             "PR"   -> return [FO AX]
                             "MP"   -> return [FO MP]
                             "MT"   -> return [FO MT]
                             "DD"   -> return [FO DD]
                             "DNE"  -> return [FO DNE]
                             "DNI"  -> return [FO DNI]
                             "DN"   -> return [FO DNE, FO DNI]
                             "CD"   -> return [FO CP1, FO CP2]
                             "ID"   -> return [FO ID1, FO ID2,FO ID3,FO ID4]
                             "ADJ"  -> return [FO ADJ]
                             "S"    -> return [FO S1,FO S2]
                             "ADD"  -> return [FO ADD1, FO ADD2]
                             "MTP"  -> return [FO MTP1, FO MTP2]
                             "BC"   -> return [FO BC1, FO BC2]
                             "CB"   -> return [FO CB]
                             "UI"   -> return [FO UI, SOUI]
                             "UD"   -> return [SOUD, FO UD]
                             "EG"   -> return [FO EG, SOEG]
                             "ED"   -> return [FO ED1,FO ED2, SOED1, SOED2]
                             "QN"   -> return [FO QN1, FO QN2, FO QN3,FO QN4]
                             "ABS"  -> return [ABS]
                             "APP"  -> return [APP]

parseMSOLProof :: String -> [DeductionLine MSOLogic MonadicallySOLLex (Form Bool)]
parseMSOLProof = toDeduction (parseMSOLogic) msolFormulaParser

msolSeqParser = seqFormulaParser :: Parsec String u (MSOLSequentCalc Sequent)