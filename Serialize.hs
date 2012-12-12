module Reactive.Banana.Serialize where

import Network.WebSockets as WS
import Reactive.Banana
import Reactive.Banana.Frameworks
import Data.Aeson
import Data.Aeson.Types
import Data.ByteString.Lazy hiding (split)
import Control.Concurrent
import Control.Concurrent.STM
import Control.Monad

serialize :: ToJSON a => WS.Sink ByteString -> Event t a -> Moment t ()
serialize sink ev = reactimate $ sendSink sink . transform <$> ev
  where
    transform = fromLazyByteString . encode

tChanAddHandler :: TChan a -> IO (AddHandler a)
tChanAddHandler chan = do
    (addHandler, runHandler) <- newAddHandler
    forkIO $ forever $ atomically (readTChan chan) >>= runHandler
    return addHandler

chanAddHandler :: Chan a -> IO (AddHandler a)
chanAddHandler chan = do
    (addHandler, runHandler) <- newAddHandler
    forkIO $ forever $ (readChan chan) >>= runHandler
    return addHandler


readFromChan :: (FromJSON a, Frameworks t)
             => Chan a 
             -> Moment t (Event t ParseError, Event t a)
readFromChan chan = do
    ev <- chanAddHandler chan >>= fromAddHandler
    return . split $ eitherFromJSON <$> ev

readFromTChan :: FromJSON a => Chan a 
              -> Moment t ( Event t ParseError, Event t a)
readFromTChan chan = do
    ev <- tChanAddHandler chan >>= fromAddHandler
    return . split $ eitherFromJSON <$> ev

eitherFromJSON :: FromJSON a => Either ParseError a
eitherFromJSON j = 
  case (fromJSON j) of
    Error msg -> Left msg
    Success v -> Right v

type ParseError = String
