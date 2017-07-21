{-#LANGUAGE FlexibleContexts, FlexibleInstances, MultiParamTypeClasses #-}
module Carnap.Languages.PurePropositional.Logic.Hardegree
    (parseHardegreeSL,  parseHardegreeSLProof, HardegreeSL, hardegreeSLCalc) where

import Data.Map as M (lookup, Map)
import Text.Parsec
import Carnap.Core.Data.AbstractSyntaxDataTypes (Form)
import Carnap.Languages.PurePropositional.Syntax
import Carnap.Languages.PurePropositional.Parser
import Carnap.Calculi.NaturalDeduction.Syntax
import Carnap.Calculi.NaturalDeduction.Parser
import Carnap.Calculi.NaturalDeduction.Checker
import Carnap.Languages.ClassicalSequent.Syntax
import Carnap.Languages.ClassicalSequent.Parser
import Carnap.Languages.PurePropositional.Logic.Rules

--A system for propositional logic resembling the proof system from Gary
--Hardegree's Modal Logic

data HardegreeSL = AndI | AndO1 | AndO2 | AndNI | AndNO
                 | OrI1 | OrI2  | OrO1  | OrO2  | OrNI  | OrNO
                 | IfI1 | IfI2  | IfO1  | IfO2  | IfNI  | IfNO
                 | IffI | IffO1 | IffO2 | IffNI | IffNO
                 | FalI | FalO  | FalNI | CD1   | CD2   | DD    
                 | ID1  | ID2   | ID3   | ID4   | AndD  | DN1 | DN2
                 | OrID Int 
                 | SepCases Int
                 | Pr | As
               deriving (Eq)

instance Show HardegreeSL where
         show Pr     = "PR"
         show As     = "As"
         show AndI   = "&I"  
         show AndO1  = "&O"
         show AndO2  = "&O"
         show AndNI  = "~&I" 
         show AndNO  = "~&O"
         show OrI1   = "∨I"
         show OrI2   = "∨I"
         show OrO1   = "∨O"
         show OrO2   = "∨O"
         show OrNI   = "~∨I" 
         show OrNO   = "~∨O"
         show IfI1   = "→I"
         show IfI2   = "→I"
         show IfO1   = "→O"
         show IfO2   = "→O"
         show IfNI   = "~→I" 
         show IfNO   = "~→O"
         show IffI   = "↔I"
         show IffO1  = "↔O"
         show IffO2  = "↔O"
         show IffNI  = "~↔I" 
         show IffNO  = "~↔O"
         show FalI   = "⊥I"
         show FalO   = "⊥O"
         show DN1    = "DN"
         show DN2    = "DN"
         show CD1    = "CD"
         show CD2    = "CD"
         show DD     = "DD"
         show ID1    = "ID"
         show ID2    = "ID"
         show ID3    = "ID"
         show ID4    = "ID"
         show AndD   = "&D"
         show (OrID n) = "∨ID" ++ show n
         show (SepCases n) = "SC" ++ show n

instance Inference HardegreeSL PurePropLexicon where
         ruleOf Pr       = axiom
         ruleOf As       = axiom
         ruleOf AndI     = adjunction
         ruleOf AndO1    = simplificationVariations !! 0
         ruleOf AndO2    = simplificationVariations !! 1
         ruleOf AndNI    = negatedConjunctionVariations !! 1
         ruleOf AndNO    = negatedConjunctionVariations !! 0
         ruleOf OrI1     = additionVariations !! 0
         ruleOf OrI2     = additionVariations !! 1
         ruleOf OrO1     = modusTollendoPonensVariations !! 0
         ruleOf OrO2     = modusTollendoPonensVariations !! 1
         ruleOf OrNI     = deMorgansNegatedOr !! 1
         ruleOf OrNO     = deMorgansNegatedOr !! 0
         ruleOf IfI1     = materialConditionalVariations !! 0
         ruleOf IfI2     = materialConditionalVariations !! 1
         ruleOf IfO1     = modusPonens
         ruleOf IfO2     = modusTollens
         ruleOf IfNI     = negatedConditionalVariations !! 1
         ruleOf IfNO     = negatedConditionalVariations !! 0
         ruleOf IffI     = conditionalToBiconditional
         ruleOf IffO1    = biconditionalToConditionalVariations !! 0
         ruleOf IffO2    = biconditionalToConditionalVariations !! 1
         ruleOf IffNI    = negatedBiconditionalVariations !! 1
         ruleOf IffNO    = negatedBiconditionalVariations !! 0
         ruleOf FalI     = falsumIntroduction
         ruleOf FalO     = falsumElimination
         ruleOf DN1      = doubleNegationIntroduction
         ruleOf DN2      = doubleNegationElimination
         ruleOf CD1      = explicitConditionalProofVariations !! 0
         ruleOf CD2      = explicitConditionalProofVariations !! 2
         ruleOf DD       = identityRule
         ruleOf ID1      = explicitConstructiveFalsumReductioVariations !! 0
         ruleOf ID2      = explicitConstructiveFalsumReductioVariations !! 1
         ruleOf ID3      = explicitNonConstructiveFalsumReductioVariations !! 0
         ruleOf ID4      = explicitNonConstructiveFalsumReductioVariations !! 1
         ruleOf AndD     = adjunction
         ruleOf (OrID n) = eliminationOfCases n
         ruleOf (SepCases n) = separationOfCases n

         -- TODO fix this up so that these rules use ProofTypes with variable
         -- arities.
         indirectInference (SepCases n) = Just (TypedProof (ProofType 0 n))
         indirectInference (OrID n) = Just (TypedProof (ProofType n 1))
         indirectInference (AndD) = Just doubleProof
         indirectInference x 
            | x `elem` [ID1,ID2,ID3,ID4,CD1,CD2] = Just assumptiveProof
            | otherwise = Nothing

         isAssumption As = True
         isAssumption _ = False

parseHardegreeSL :: Map String DerivedRule -> Parsec String u [HardegreeSL]
parseHardegreeSL ders = do r <- choice (map (try . string) ["AS","PR","&I","&O","~&I","~&O","->I","->O","~->I","~->O","→I","→O","~→I","~→O","!?I"
                                                           ,"!?O","vID","\\/ID","vI","vO","~vI","~vO","\\/I","\\/O","~\\/I","~\\/O","<->I","<->O","~<->I"
                                                           ,"~<->O","↔I","↔O","~↔I","~↔O","ID","&D","SC","DN"
                                                           ])
                           case r of
                             "AS"    -> return [As]
                             "PR"    -> return [Pr]
                             "&I"    -> return [AndI]
                             "&O"    -> return [AndO1,AndO2]
                             "~&I"   -> return [AndNI]
                             "~&O"   -> return [AndNO]
                             "->I"   -> return [IfI1,IfO2]
                             "->O"   -> return [IfO1,IfO2]
                             "~->I"  -> return [IfNI]
                             "~->O"  -> return [IfNO]
                             "→I"    -> return [IfO1,IffO2]           
                             "→O"    -> return [IfI1,IfO2]          
                             "~→I"   -> return [IfNI]
                             "~→O"   -> return [IfNO]
                             "!?I"   -> return [FalI]
                             "!?O"   -> return [FalO]
                             "vI"    -> return [OrI1, OrI2]
                             "vO"    -> return [OrO1, OrO2]
                             "~vI"   -> return [OrNI]
                             "~vO"   -> return [OrNO]
                             "\\/I"  -> return [OrI1, OrI2] 
                             "\\/O"  -> return [OrO1, OrO2]
                             "~\\/I" -> return [OrNI]
                             "~\\/O" -> return [OrNO]
                             "<->I"  -> return [IffI]       
                             "<->O"  -> return [IffO1,IffO2]
                             "~<->I" -> return [IffNI]       
                             "~<->O" -> return [IffNO]
                             "↔I"    -> return [IffI]       
                             "↔O"    -> return [IffO1,IffO2]
                             "~↔I"   -> return [IffNI]       
                             "~↔O"   -> return [IffNO]
                             "ID"    -> return [ID1,ID2,ID3,ID4]
                             "DN"    -> return [DN1,DN2]
                             "&D"    -> return [AndD]
                             "SC"    -> do ds <- many1 digit
                                           return [SepCases (read ds)]
                             "\\/ID" -> do ds <- many1 digit
                                           return [OrID (read ds)]
                             "vID"   -> do ds <- many1 digit
                                           return [OrID (read ds)]
parseHardegreeSLProof :: Map String DerivedRule -> String -> [DeductionLine HardegreeSL PurePropLexicon (Form Bool)]
parseHardegreeSLProof ders = toDeductionHardegree (parseHardegreeSL ders) (purePropFormulaParser (standardLetters {hasBooleanConstants = True}))

hardegreeSLCalc = NaturalDeductionCalc 
    { ndRenderer = MontegueStyle
    , ndParseProof = parseHardegreeSLProof
    , ndProcessLine = processLineHardegree
    , ndProcessLineMemo = Nothing
    , ndParseSeq = propSeqParser
    }
