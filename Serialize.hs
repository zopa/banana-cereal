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

serialize :: (TextProtocol p, ToJSON a, Frameworks t)
          => WS.Sink p -> Event t a -> Moment t ()
serialize sink ev = reactimate $ sendSink sink . textData . encode <$> ev

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

-- | Read an Event stream from a channel. If a ByteString read from the Chan
-- cannot be cleanly converted into JSON, it will be suppressed.
readFromChan :: (FromJSON a, Frameworks t)
             => Chan ByteString 
             -> Moment t (Event t a)
readFromChan chan = do
    ev <- liftIO (chanAddHandler chan) >>= fromAddHandler
    return . filterJust $ decode <$> ev

-- | Read an Event stream from a TChan. If a ByteString read from the Chan
-- cannot be cleanly converted into JSON, it will be suppressed.
readFromTChan :: (FromJSON a, Frameworks t)
              => TChan ByteString 
              -> Moment t (Event t a)
readFromTChan chan = do
    ev <- liftIO (tChanAddHandler chan) >>= fromAddHandler
    return . filterJust $ decode <$> ev
