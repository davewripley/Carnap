{-# LANGUAGE RankNTypes, FlexibleContexts, DeriveDataTypeable, CPP, JavaScriptFFI #-}
module Lib
    (genericSendJSON, sendJSON, onEnter, onKey, clearInput,
    getListOfElementsByClass, tryParse, treeToElement, genericTreeToUl,
    treeToUl, genericListToUl, listToUl, formToTree, leaves,
    adjustFirstMatching, decodeHtml, syncScroll, reloadPage, initElements,
    loginCheck,errorPopup, genInOutElts, getInOutElts,generateExerciseElts, withLabel,
    formAndLabel,seqAndLabel, folSeqAndLabel, folFormAndLabel,
    message, IOGoal(..), updateWithValue, submissionSource, assignmentKey,
    initialize,makePopper) where

import Data.Aeson
import Data.Maybe (catMaybes)
import qualified Data.ByteString.Lazy as BSL
import Data.Text.Encoding
import Data.Tree as T
import qualified Data.Map as M
import Text.Parsec
import Text.StringLike
import Text.HTML.TagSoup as TS
import Control.Lens
import Control.Lens.Plated (children)
import Control.Monad.State
import Control.Monad.Trans.Maybe (runMaybeT, MaybeT(..))
--The following three imports come from ghcjs-base, and break ghc-mod
#ifdef __GHCJS__
import GHCJS.Types
import GHCJS.Foreign
import GHCJS.Foreign.Callback
import GHCJS.Marshal
#endif
--the import below required to make ghc-mod work properly. GHCJS compiles
--using the generated javascript FFI versions of 2.4.0, but those are
--slightly different from the webkit versions of 2.4.0. In particular,
--Element doesn't export IsElement, although Types does in the webkit
--version---but it's the other way around in the FFI version. This appears
--to be cleaner in 3.0, but there's no documentation for that at all, yet.
import GHCJS.DOM
import GHCJS.DOM.Types
import GHCJS.DOM.Element
import GHCJS.DOM.HTMLInputElement
import qualified GHCJS.DOM.HTMLTextAreaElement as TA (setValue,getValue)
import GHCJS.DOM.Document (createElement, getBody)
import GHCJS.DOM.Node
import GHCJS.DOM.NodeList
import qualified GHCJS.DOM.NamedNodeMap as NM
import GHCJS.DOM.Event
import GHCJS.DOM.KeyboardEvent
import GHCJS.DOM.EventM
import GHCJS.DOM.EventTarget
import GHCJS.DOM.EventTargetClosures (EventName(..))
import Carnap.GHCJS.SharedTypes
import Carnap.Calculi.NaturalDeduction.Syntax (NaturalDeductionCalc(..))
import Carnap.Languages.PurePropositional.Syntax (PureForm)
import Carnap.Languages.PurePropositional.Logic (propCalc)
import Carnap.Languages.PureFirstOrder.Parser (folFormulaParser)
import Carnap.Languages.PureFirstOrder.Logic (folCalc)
import Carnap.Languages.PurePropositional.Parser (purePropFormulaParser, standardLetters)

--------------------------------------------------------
--1. Utility Functions
--------------------------------------------------------

--------------------------------------------------------
--1.1 Events
--------------------------------------------------------

onKey :: [String] -> EventM e KeyboardEvent () ->  EventM e KeyboardEvent ()
onKey keylist action = do kbe      <- event
                          id       <- getKeyIdentifier kbe 
                          -- XXX: keyIdentifier is deprecated and doesn't work in
                          -- firefox; hence the use of `keyString`. But `key`
                          -- doesn't work in some older browsers, so we keep
                          -- this line around.
                          id'      <- liftIO $ keyString kbe
                          if id `elem` keylist || id' `elem` keylist then do action else return ()

onEnter :: EventM e KeyboardEvent () ->  EventM e KeyboardEvent ()
onEnter = onKey ["Enter"]

--------------------------------------------------------
--1.1.2 Common responsive behavior
--------------------------------------------------------

syncScroll e1 e2 = do cup1 <- catchup e1 e2
                      cup2 <- catchup e2 e1
                      addListener e1 scroll cup1 False
                      addListener e2 scroll cup2 False
    where catchup e1 e2 = newListener $ liftIO $ do st <- getScrollTop e1
                                                    setScrollTop e2 st

--------------------------------------------------------
--1.2 DOM Manipulation
--------------------------------------------------------

--------------------------------------------------------
--1.2.1 DOM Data
--------------------------------------------------------
-- data structures for DOM elements

data IOGoal = IOGoal { inputArea :: Element
                     , outputArea :: Element
                     , goalArea :: Element
                     , content :: String
                     , exerciseOptions :: M.Map String String
                     }


clearInput :: (MonadIO m) => HTMLInputElement -> m ()
clearInput i = setValue i (Just "")


maybeNodeListToList mnl = case mnl of 
                            Nothing -> return []
                            Just nl -> do l <- getLength nl
                                          if l > 0 then 
                                              mapM ((fmap . fmap) castToElement . item nl) [0 .. l-1]
                                          else return []

-- XXX: one might also want to include a "mutable lens" or "mutable traversal"
--kind of thing: http://stackoverflow.com/questions/18794745/can-i-make-a-lens-with-a-monad-constraint
getListOfElementsByClass :: IsElement self => self -> String -> IO [Maybe Element]
getListOfElementsByClass elt c = do mnl <- getElementsByClassName elt c
                                    maybeNodeListToList mnl

getListOfElementsByCarnapType :: IsElement self => self -> String -> IO [Maybe Element]
getListOfElementsByCarnapType elt s = do mnl <- querySelectorAll elt ("[data-carnap-type=" ++ s ++ "]")
                                         maybeNodeListToList mnl

tryParse p s = unPack $ parse p "" s 
    where unPack (Right s) = show s
          unPack (Left e)  = show e

treeToElement :: (a -> IO Element) -> (Element -> [Element] -> IO ()) -> Tree a -> IO Element
treeToElement f g (T.Node n []) = f n
treeToElement f g (T.Node n ts) = do r <- f n
                                     elts <- mapM (treeToElement f g) ts
                                     g r elts
                                     return r

genericTreeToUl :: (a -> String) -> Document -> Tree (a, String) -> IO Element
genericTreeToUl sf w t = treeToElement itemize listify t
    where itemize (x,c) = do s@(Just s') <- createElement w (Just "li")
                             setInnerHTML s' (Just $ sf x)
                             setAttribute s' "class" c 
                             return s'
          listify x xs = do o@(Just o') <- createElement w (Just "ul")
                            mapM_ (appendChild o' . Just) xs
                            appendChild x o
                            return ()

treeToUl :: Show a => Document -> Tree (a, String) -> IO Element
treeToUl = genericTreeToUl show

genericListToUl :: (Element -> a -> IO ()) -> Document -> [a] -> IO Element
genericListToUl f doc l = 
        do elts <- mapM wrapIt l
           (Just ul) <- createElement doc (Just "ul")
           mapM_ (appendChild ul) elts
           return ul
    where wrapIt e = do (Just li) <- createElement doc (Just "li")
                        f li e 
                        return (Just li)

listToUl :: Show a => Document -> [a] -> IO Element
listToUl = genericListToUl (\e a -> setInnerHTML e (Just $ show a))

{-
This function supports a pattern where we gather a list of elements that
have a designated input (usually a text area or something) and output
children, and then attach events to them according to the classes of their
parents. 
-}
getInOutElts :: IsElement self => String -> self -> IO [Maybe (Element, Element, [String])]
getInOutElts cls b = do els <- getListOfElementsByClass b cls
                        mapM extract els
        where extract Nothing = return Nothing
              extract (Just el) = 
                do cn <- getClassName el
                   runMaybeT $ do
                        i <- MaybeT $ getFirstElementChild el
                        o <- MaybeT $ getNextElementSibling i
                        return (i ,o ,words cn)

genInOutElts :: IsElement self => Document -> String -> String -> String -> self -> IO [Maybe (Element, Element, M.Map String String)]
genInOutElts w input output ty target = 
        do els <- getListOfElementsByCarnapType target ty
           mapM initialize els
    where initialize Nothing = return Nothing
          initialize (Just el) = do
              Just content <- getInnerHTML el :: IO (Maybe String)
              [Just o, Just i] <- mapM (createElement w . Just) [output,input]
              setAttribute i "class" "input"
              setAttribute o "class" "output"
              setInnerHTML el (Just "")
              opts <- getCarnapDataMap el
              mapM_ (appendChild el . Just) [i,o]
              return $ Just (i, o, M.insert "content" content opts )

generateExerciseElts :: IsElement self => Document -> String -> self -> IO [Maybe IOGoal]
generateExerciseElts w ty target = do els <- getListOfElementsByCarnapType target ty 
                                      mapM initialize els
        where initialize Nothing = return Nothing
              initialize (Just el) = do
                  Just content <- getInnerHTML el
                  setInnerHTML el (Just "")
                  [Just g, Just o, Just i] <- mapM (createElement w . Just) ["div","div","textarea"]
                  setAttribute g "class" "goal"
                  setAttribute i "class" "input"
                  setAttribute o "class" "output"
                  opts <- getCarnapDataMap el
                  mapM_ (appendChild el . Just) [g,i,o]
                  return $ Just (IOGoal i o g content opts)

updateWithValue :: IsEvent ev => (String ->  IO ()) -> EventM HTMLTextAreaElement ev ()
updateWithValue f = 
        do (Just t) <- target :: IsEvent ev' => EventM HTMLTextAreaElement ev' (Maybe HTMLTextAreaElement)
           mv <- TA.getValue t
           case mv of 
               Nothing -> return ()
               Just v -> liftIO $ f v

getCarnapDataMap :: Element -> IO (M.Map String String)
getCarnapDataMap elt = do (Just nnmap) <- getAttributes elt
                          len <- NM.getLength nnmap
                          if len > 0 then do
                                mnodes <- mapM (NM.item nnmap) [0 .. len -1]
                                mnamevals <- mapM toNameVal mnodes
                                return $ M.fromList . catMaybes $ mnamevals
                          else return mempty

    where toNameVal (Just node) = do mn <- getNodeName node
                                     mv <- getNodeValue node
                                     case (mn,mv) of
                                         (Just n, Just v) | "data-carnap-" == take 12 n -> return $ Just (Prelude.drop 12 n,v)
                                         _ -> return Nothing
          toNameVal _ = return Nothing

--------------------------------------------------------
--1.3 Encodings
--------------------------------------------------------

decodeHtml :: (StringLike s, Show s) => s -> s
decodeHtml = TS.fromTagText . head . parseTags

--------------------------------------------------------
--1.4 Optics
--------------------------------------------------------

leaves :: Traversal' (Tree a) (Tree a)
leaves f (T.Node x []) = f (T.Node x [])
leaves f (T.Node x xs) = T.Node <$> pure x <*> traverse (leaves f) xs

adjustFirstMatching :: Traversal' a b -> (b -> Bool) -> (b -> b) -> a -> a
adjustFirstMatching t pred  f x = evalState (traverseOf t adj x) True where
    adj y =  do b <- get
                if b && pred y 
                    then put False >> return (f y)
                    else return y

--------------------------------------------------------
--1.5 Carnap-Specific
--------------------------------------------------------

formToTree :: Plated a => a -> Tree a
formToTree f = T.Node f (map formToTree (children f))

--------------------------------------------------------
--1.6 Boilerplate
--------------------------------------------------------

initElements :: (Document -> HTMLElement -> IO [a]) -> (Document -> a -> IO b) -> IO ()
initElements getter setter = runWebGUI $ \w -> 
            do (Just dom) <- webViewGetDomDocument w
               (Just b) <- getBody dom
               elts <- getter dom b
               case elts of 
                    [] -> return ()
                    _ -> mapM_ (setter dom) elts

loginCheck successMsg serverResponse  
     | serverResponse == "No User" = alert "You need to log in before you can submit anything"
     | serverResponse == "Clash"   = alert "it appears you've already successfully submitted this problem"
     | otherwise      = alert successMsg

errorPopup msg = alert ("Something has gone wrong. Here's the error: " ++ msg)

--------------------------------------------------------
--1.7 Parsing
--------------------------------------------------------
 
formAndLabel :: Monad m => ParsecT String u m (String, PureForm)
formAndLabel = withLabel (purePropFormulaParser standardLetters <* eof)

seqAndLabel = withLabel (ndParseSeq propCalc)

folSeqAndLabel =  withLabel (ndParseSeq folCalc)

folFormAndLabel =  withLabel folFormulaParser

withLabel :: Monad m => ParsecT String u m b -> ParsecT String u m (String, b)
withLabel parser = do label <- many (digit <|> char '.')
                      spaces
                      s <- parser
                      return (label,s)

--------------------------------------------------------
--2. FFI Wrappers
--------------------------------------------------------

#ifdef __GHCJS__

sendJSON :: ToJSON a => a -> (String -> IO ()) -> (String -> IO ()) -> IO ()
sendJSON x succ fail = do cb1 <- asyncCallback1 (cb succ)
                          cb2 <- asyncCallback3 (cb3 fail)
                          jsonCommand (toJSString . decodeUtf8 . BSL.toStrict . encode $ x) cb1 cb2
    where cb f x = do (Just s) <- fromJSVal x 
                      f s
          cb3 f _ x _  = do (Just s) <- fromJSVal x 
                            f s 

genericSendJSON :: ToJSON a => a -> (Value -> IO ()) -> (Value -> IO ()) -> IO ()
genericSendJSON x succ fail = do cb1 <- asyncCallback1 (cb succ)
                                 cb2 <- asyncCallback3 (cb3 fail)
                                 jsonCommand (toJSString . decodeUtf8 . BSL.toStrict . encode $ x) cb1 cb2
    where cb f x = do (Just v) <- fromJSVal x 
                      f v
          cb3 f _ x _  = do (Just v) <- fromJSVal x 
                            f v 

keyString :: KeyboardEvent -> IO String
keyString e = key e >>= return . fromJSString

alert :: String -> IO ()
alert = alert' . toJSString

foreign import javascript unsafe "try {jsonCommand($1,$2,$3)} catch(e) {console.log(e)};" jsonCommand :: JSString -> Callback (JSVal -> IO()) -> Callback (JSVal -> JSVal -> JSVal -> IO()) -> IO ()

foreign import javascript unsafe "$1.key" key :: KeyboardEvent -> IO JSString

foreign import javascript unsafe "location.reload()" reloadPage :: IO ()

foreign import javascript unsafe "alert($1)" alert' :: JSString -> IO ()

foreign import javascript unsafe "window.location.href()" currentUrl :: IO JSString

foreign import javascript unsafe "(function(){try {var v=submission_source;} catch (e) {var v=\"no submission source found\";}; return v})()" submissionQueryJS :: IO JSString

foreign import javascript unsafe "(function(){try {var v=assignment_key;} catch (e) {var v=\"\";}; return v})()" assignmentKeyJS :: IO JSString

foreign import javascript unsafe "try {new Popper($1,$2,{placement:\"right\"});} catch (e) {$2.className=\"manualPopper\"};" makePopper :: Element -> Element -> IO ()

submissionSource = do qr <- submissionQueryJS
                      case fromJSString qr of
                          "book" -> return $ Just Book
                          s -> do return $ Just (Assignment s)

message s = liftIO (alert s)

assignmentKey :: IO String
assignmentKey = do k <- assignmentKeyJS
                   return $ fromJSString k

initialize :: EventName t Event
initialize = EventName $ toJSString "initialize"


#else

initialize :: EventName t Event
initialize = EventName "initialize"

assignmentKey :: IO String
assignmentKey = Prelude.error "assignmentKey requires the GHJS FFI"

submissionSource :: IO (Maybe ProblemSource)
submissionSource = Prelude.error "submissionSource requires the GHCJS FFI"

sendJSON :: ToJSON a => a -> (String -> IO ()) -> (String -> IO ()) -> IO ()
sendJSON = Prelude.error "sendJSON requires the GHCJS FFI"

genericSendJSON :: ToJSON a => a -> (Value -> IO ()) -> (Value -> IO ()) -> IO ()
genericSendJSON = Prelude.error "sendJSON requires the GHCJS FFI"

keyString :: KeyboardEvent -> IO String
keyString = Prelude.error "keyString requires the GHCJS FFI"

alert :: String -> IO ()
alert = Prelude.error "alert requires the GHCJS FFI"

makePopper :: Element -> Element -> IO ()
makePopper = Prelude.error "makePopper requires the GHCJS FFI"

currentUrl = Prelude.error "currentUrl requires the GHCJS FFI"

message s = liftIO (alert s)

reloadPage :: IO ()
reloadPage = Prelude.error "you can't reload the page without the GHCJS FFI"
#endif
