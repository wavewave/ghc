module PprColour where
import Data.Maybe (fromMaybe)
import Util (OverridingBool(..), split)

-- | A colour\/style for use with 'coloured'.
newtype PprColour = PprColour String

-- | Allow colours to be combined (e.g. bold + red);
--   In case of conflict, right side takes precedence.
instance Monoid PprColour where
  mempty = PprColour mempty
  PprColour s1 `mappend` PprColour s2 = PprColour (s1 `mappend` s2)

colCustom :: String -> PprColour
colCustom s = PprColour ("\27[" ++ s ++ "m")

colReset :: PprColour
colReset = colCustom "0"

colBold :: PprColour
colBold = colCustom ";1"

colBlackFg :: PprColour
colBlackFg = colCustom "30"

colRedFg :: PprColour
colRedFg = colCustom "31"

colGreenFg :: PprColour
colGreenFg = colCustom "32"

colYellowFg :: PprColour
colYellowFg = colCustom "33"

colBlueFg :: PprColour
colBlueFg = colCustom "34"

colMagentaFg :: PprColour
colMagentaFg = colCustom "35"

colCyanFg :: PprColour
colCyanFg = colCustom "36"

colWhiteFg :: PprColour
colWhiteFg = colCustom "37"

data Scheme =
  Scheme
  { sMessage :: PprColour
  , sWarning :: PprColour
  , sError   :: PprColour
  , sFatal   :: PprColour
  , sMargin  :: PprColour
  }

defaultScheme :: Scheme
defaultScheme =
  Scheme
  { sMessage = colBold
  , sWarning = colBold `mappend` colMagentaFg
  , sError   = colBold `mappend` colRedFg
  , sFatal   = colBold `mappend` colRedFg
  , sMargin  = colBold `mappend` colBlueFg
  }

-- | Parse the colour scheme from a string (presumably from the @GHC_COLORS@
-- environment variable).
parseScheme :: String -> (OverridingBool, Scheme) -> (OverridingBool, Scheme)
parseScheme "always" (_, cs) = (Always, cs)
parseScheme "auto"   (_, cs) = (Auto,   cs)
parseScheme "never"  (_, cs) = (Never,  cs)
parseScheme input    (b, cs) =
  ( b
  , Scheme
    { sMessage = fromMaybe (sMessage cs) (lookup "message" table)
    , sWarning = fromMaybe (sWarning cs) (lookup "warning" table)
    , sError   = fromMaybe (sError cs)   (lookup "error"   table)
    , sFatal   = fromMaybe (sFatal cs)   (lookup "fatal"   table)
    , sMargin  = fromMaybe (sMargin cs)  (lookup "margin"  table)
    }
  )
  where
    table = do
      w <- split ':' input
      let (k, v') = break (== '=') w
      case v' of
        '=' : v -> return (k, colCustom v)
        _ -> []
