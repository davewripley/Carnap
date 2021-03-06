{-#LANGUAGE FlexibleContexts, FlexibleInstances, MultiParamTypeClasses #-}
module Carnap.Languages.PurePropositional.Logic.ThomasBolducAndZach
    ( parseThomasBolducAndZachTFL, ThomasBolducAndZachTFL,  thomasBolducAndZachTFLCalc) where

import Data.Map as M (lookup, Map)
import Text.Parsec
import Carnap.Core.Data.Types (Form)
import Carnap.Languages.PurePropositional.Syntax
import Carnap.Languages.PurePropositional.Parser
import Carnap.Calculi.NaturalDeduction.Syntax
import Carnap.Calculi.NaturalDeduction.Parser
import Carnap.Calculi.NaturalDeduction.Checker
import Carnap.Languages.ClassicalSequent.Syntax
import Carnap.Languages.ClassicalSequent.Parser
import Carnap.Languages.PurePropositional.Logic.Rules

{-| A system for propositional logic resembling the basic proof system TFL
from the Calgary Remix of Forall x book
-}

data ThomasBolducAndZachTFL = ConjIntro  | As
                            | ConjElim1  | ConjElim2
                            | DisjIntro1 | DisjIntro2
                            | DisjElim1  | DisjElim2
                            | DisjElim3  | DisjElim4
                            | CondIntro1 | CondIntro2
                            | CondElim
                            | BicoIntro1 | BicoIntro2
                            | BicoIntro3 | BicoIntro4
                            | BicoElim1  | BicoElim2
                            | NegeIntro1 | NegeIntro2
                            | NegeElim   | ContElim 
                            | Indirect1  | Indirect2
                            | DisSyllo1  | DisSyllo2
                            | ModTollens | Reiterate
                            | DoubleNeg  
                            | Lem1       | Lem2
                            | Lem3       | Lem4
                            | DeMorgan1  | DeMorgan2
                            | DeMorgan3  | DeMorgan4
                            | Pr (Maybe [(ClassicalSequentOver PurePropLexicon (Sequent (Form Bool)))])
                            deriving (Eq)
                            --skipping derived rules for now

instance Show ThomasBolducAndZachTFL where
        show ConjIntro  = "∧I"
        show ConjElim1  = "∧E"
        show ConjElim2  = "∧E"
        show NegeIntro1 = "¬I"
        show NegeIntro2 = "¬I"
        show NegeElim   = "¬E"
        show Indirect1  = "IP"
        show Indirect2  = "IP"
        show CondIntro1 = "→I"
        show CondIntro2 = "→I"
        show CondElim   = "→E"
        show ContElim   = "X"
        show DisjElim1  = "∨E"
        show DisjElim2  = "∨E"
        show DisjElim3  = "∨E"
        show DisjElim4  = "∨E"
        show DisjIntro1 = "∨I"
        show DisjIntro2 = "∨I"
        show BicoIntro1 = "↔I"
        show BicoIntro2 = "↔I"
        show BicoIntro3 = "↔I"
        show BicoIntro4 = "↔I"
        show BicoElim1  = "↔E"
        show BicoElim2  = "↔E"
        show As         = "AS"
        show (Pr _)     = "PR"
        show DisSyllo1  = "DS"
        show DisSyllo2  = "DS"
        show ModTollens = "MT"
        show Reiterate  = "R"
        show DoubleNeg  = "DNE"
        show Lem1       = "LEM"
        show Lem2       = "LEM"
        show Lem3       = "LEM"
        show Lem4       = "LEM"
        show DeMorgan1  = "DeM"
        show DeMorgan2  = "DeM"
        show DeMorgan3  = "DeM"
        show DeMorgan4  = "DeM"

instance Inference ThomasBolducAndZachTFL PurePropLexicon (Form Bool) where
        ruleOf ConjIntro  = adjunction
        ruleOf ConjElim1  = simplificationVariations !! 0
        ruleOf ConjElim2  = simplificationVariations !! 1
        ruleOf NegeIntro1 = explicitConstructiveFalsumReductioVariations !! 0
        ruleOf NegeIntro2 = explicitConstructiveFalsumReductioVariations !! 1
        ruleOf NegeElim   = falsumIntroduction
        ruleOf Indirect1  = explicitNonConstructiveFalsumReductioVariations !! 0
        ruleOf Indirect2  = explicitNonConstructiveFalsumReductioVariations !! 1
        ruleOf CondIntro1 = conditionalProofVariations !! 0
        ruleOf CondIntro2 = conditionalProofVariations !! 1
        ruleOf CondElim   = modusPonens
        ruleOf ContElim   = falsumElimination
        ruleOf DisjIntro1 = additionVariations !! 0
        ruleOf DisjIntro2 = additionVariations !! 1 
        ruleOf DisjElim1  = proofByCasesVariations !! 0
        ruleOf DisjElim2  = proofByCasesVariations !! 1
        ruleOf DisjElim3  = proofByCasesVariations !! 2
        ruleOf DisjElim4  = proofByCasesVariations !! 3
        ruleOf BicoIntro1 = biconditionalProofVariations !! 0
        ruleOf BicoIntro2 = biconditionalProofVariations !! 1
        ruleOf BicoIntro3 = biconditionalProofVariations !! 2
        ruleOf BicoIntro4 = biconditionalProofVariations !! 3
        ruleOf BicoElim1  = biconditionalPonensVariations !! 0
        ruleOf BicoElim2  = biconditionalPonensVariations !! 1
        ruleOf As         = axiom
        ruleOf (Pr _)     = axiom
        ruleOf DisSyllo1  = modusTollendoPonensVariations !! 0 
        ruleOf DisSyllo2  = modusTollendoPonensVariations !! 1
        ruleOf ModTollens = modusTollens
        ruleOf Reiterate  = identityRule
        ruleOf DoubleNeg  = doubleNegationElimination
        ruleOf Lem1       = tertiumNonDaturVariations !! 0 
        ruleOf Lem2       = tertiumNonDaturVariations !! 1
        ruleOf Lem3       = tertiumNonDaturVariations !! 2
        ruleOf Lem4       = tertiumNonDaturVariations !! 3
        ruleOf DeMorgan1  = deMorgansLaws !! 0
        ruleOf DeMorgan2  = deMorgansLaws !! 1
        ruleOf DeMorgan3  = deMorgansLaws !! 2
        ruleOf DeMorgan4  = deMorgansLaws !! 3

        indirectInference x
            | x `elem` [ DisjElim1, DisjElim2, DisjElim3, DisjElim4
                       , CondIntro1, CondIntro2 , BicoIntro1, BicoIntro2
                       , BicoIntro3, BicoIntro4] = Just PolyProof
            | x `elem` [ NegeIntro1, NegeIntro2
                       , Indirect1, Indirect2] = Just assumptiveProof
            | x `elem` [Lem1,Lem2,Lem3,Lem4] = Just (PolyTypedProof 2 (ProofType 1 1))
            | otherwise = Nothing

        isAssumption As = True
        isAssumption _  = False

        isPremise (Pr _) = True
        isPremise _  = False

        restriction (Pr prems) = Just (premConstraint prems)
        restriction _ = Nothing

parseThomasBolducAndZachTFL :: RuntimeNaturalDeductionConfig PurePropLexicon (Form Bool) -> Parsec String u [ThomasBolducAndZachTFL]
parseThomasBolducAndZachTFL rtc = do r <- choice (map (try . string) [ "AS","PR","&I","/\\I", "∧I","&E","/\\E","∧E", "~I","-I", "¬I"
                                                                      , "~E","-E", "¬E","IP","->I","→I","→E","->E", "→E", "X"
                                                                      , "vI","\\/I","∨I", "vE","\\/E", "∨E","<->I", "↔I","<->E"
                                                                      , "↔E","DS","MT","R","DNE","LEM","DeM"])
                                     case r of
                                          r | r == "AS"   -> return [As]
                                            | r == "PR" -> return [Pr (problemPremises rtc)]
                                            | r `elem` ["&I","/\\I","∧I"] -> return [ConjIntro]
                                            | r `elem` ["&E","/\\E","∧E"] -> return [ConjElim1, ConjElim2]
                                            | r `elem` ["~I","¬I","-I"]   -> return [NegeIntro1, NegeIntro2]
                                            | r `elem` ["~E","¬E","-E"]   -> return [NegeElim]
                                            | r == "IP" -> return [Indirect1, Indirect2]
                                            | r `elem` ["->I", "→I"] -> return [CondIntro1,CondIntro2]
                                            | r `elem` ["->E","→E"]  -> return [CondElim]
                                            | r == "X"    -> return [ContElim]
                                            | r `elem` ["∨I","vI","\\/I"] -> return [DisjIntro1, DisjIntro2]
                                            | r `elem` ["∨E","vE","\\/E"] -> return [DisjElim1, DisjElim2, DisjElim3, DisjElim4]
                                            | r `elem` ["<->I","↔I"] -> return [BicoIntro1, BicoIntro2, BicoIntro3, BicoIntro4]
                                            | r `elem` ["<->E","↔E"]   -> return [BicoElim1, BicoElim2]
                                            | r == "DS"   -> return [DisSyllo1,DisSyllo2]
                                            | r == "MT"   -> return [ModTollens]
                                            | r == "R"    -> return [Reiterate]
                                            | r == "DNE"  -> return [DoubleNeg]
                                            | r == "LEM"  -> return [Lem1,Lem2,Lem3,Lem4]
                                            | r == "DeM"   -> return [DeMorgan1,DeMorgan2,DeMorgan3,DeMorgan4]

parseThomasBolducAndZachTFLProof :: RuntimeNaturalDeductionConfig PurePropLexicon (Form Bool) -> String -> [DeductionLine ThomasBolducAndZachTFL PurePropLexicon (Form Bool)]
parseThomasBolducAndZachTFLProof rtc = toDeductionFitch (parseThomasBolducAndZachTFL rtc) (purePropFormulaParser thomasBolducZachOpts)

thomasBolducAndZachNotation :: String -> String 
thomasBolducAndZachNotation x = case runParser altParser 0 "" x of
                        Left e -> show e
                        Right s -> s
    where altParser = do s <- try handleAtom <|> fallback
                         rest <- (eof >> return "") <|> altParser
                         return $ s ++ rest
          handleAtom = do c <- oneOf "ABCDEFGHIJKLMNOPQRSTUVWXYZ" <* char '('
                          args <- oneOf "abcdefghijklmnopqrstuvwxyz" `sepBy` char ','
                          char ')'
                          return $ c:args
          fallback = do c <- anyChar 
                        return [c]

thomasBolducAndZachTFLCalc = mkNDCalc 
    { ndRenderer = FitchStyle StandardFitch
    , ndParseProof = parseThomasBolducAndZachTFLProof
    , ndProcessLine = hoProcessLineFitch
    , ndProcessLineMemo = Just hoProcessLineFitchMemo
    , ndParseSeq = parseSeqOver (purePropFormulaParser thomasBolducZachOpts)
    , ndParseForm = purePropFormulaParser thomasBolducZachOpts
    , ndNotation = thomasBolducAndZachNotation
    }
