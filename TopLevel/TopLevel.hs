{- cicminus
 - Copyright 2011 by Jorge Luis Sacchini
 -
 - This file is part of cicminus.
 -
 - cicminus is free software: you can redistribute it and/or modify it under the
 - terms of the GNU General Public License as published by the Free Software
 - Foundation, either version 3 of the License, or (at your option) any later
 - version.

 - cicminus is distributed in the hope that it will be useful, but WITHOUT ANY
 - WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 - FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 - details.
 -
 - You should have received a copy of the GNU General Public License along with
 - cicminus. If not, see <http://www.gnu.org/licenses/>.
 -}

{-# LANGUAGE GeneralizedNewtypeDeriving, FlexibleInstances, MultiParamTypeClasses,
    UndecidableInstances
  #-}

module TopLevel.TopLevel where

import Prelude hiding (catch)
import Control.Applicative
import Control.Monad
import Control.Monad.State
import Control.Monad.Reader

import qualified Syntax.Abstract as A
import Syntax.ParseMonad
import Syntax.Parser
import Syntax.Scope

import qualified System.Console.Haskeline as H
import System.Console.Haskeline.MonadException

import Kernel.TCM
import Kernel.TypeChecking

import qualified Utils.MonadUndo as U

-- TODO:
-- add top-level state: for simplicity, we consider -- for the moment -- the top-level
--                      state as part of TCState. There is less separation of concerns
--                      but it is simpler since we do not need to deal with two StateT
-- add undo: that is relatively easy, just change StateT to UndoT. We need to write
--           the MonadException transformer
newtype TopM a = TopM { unTop :: H.InputT (U.StateT TCState IO) a }
                 deriving(Monad, Functor, Applicative, MonadIO, MonadException)

instance MonadState TCState TopM where
  get = TopM $ lift get
  put x = TopM $ lift (put x)

instance MonadTCM (ReaderT TCEnv TopM)

-- problems with haskeline-0.7
-- see http://stackoverflow.com/questions/11617335/error-installing-scion-browser
instance MonadException m => MonadException (StateT s m) where
  controlIO f = StateT $ \s -> controlIO $ \(RunIO run) -> let
                  run' = RunIO (fmap (StateT . const) . run . flip runStateT s)
                  in fmap (flip runStateT s) $ f run'

runTop :: TopM a -> IO a
runTop m = fst <$> runStateT (H.runInputT settings (unTop m)) initialTCState
  where
    settings = H.defaultSettings { H.historyFile = Just "/home/jorge/.cicminus-history"
                                 , H.autoAddHistory = True }

liftTop :: TCM () -> TopM ()
liftTop x = TopM (lift (runReaderT x initialTCEnv)) `catch` f
            where
              f :: TypeError -> TopM ()
              f err = outputStrLn (show err)

liftTopM :: TCM a -> TopM a
liftTopM = TopM . lift . flip runReaderT initialTCEnv

catchTypeError :: TopM () -> TopM ()
catchTypeError x = x `catch` f
                   where
                     f :: TypeError -> TopM ()
                     f err = outputStrLn (show err)

getInputLine = TopM . H.getInputLine
getInputChar = TopM . H.getInputChar
outPutStr    = TopM . H.outputStr
outputStrLn  = TopM . H.outputStrLn

-- undo, redo :: TopM ()
-- undo = TopM $ U.undo >> return ()
-- redo = TopM $ U.redo >> return ()


runCommand :: (MonadTCM tcm) => String -> tcm ()
runCommand ss =
  case parse fileParser ss of
    ParseOk ts -> typeCheckFile ts
      -- do r <- runTCM $ typeCheckFile ts
      --    case r of
      --      Left err -> putStrLn $ "Error!!!! " ++ show err
      --      Right _ -> return ()
    ParseFail err -> liftIO $ putStrLn $ "Error (Main.hs): " ++ show err

typeCheckDecl :: (MonadTCM tcm) => A.Declaration -> tcm ()
typeCheckDecl d = do d' <- scope d
                     gs <- inferDecl d'
                     forM_ gs (uncurry addGlobal)

typeCheckFile :: (MonadTCM tcm) => [A.Declaration] -> tcm ()
typeCheckFile ds =
  do forM_ ds typeCheckDecl
