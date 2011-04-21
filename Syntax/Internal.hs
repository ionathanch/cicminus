{-# LANGUAGE TypeSynonymInstances, FlexibleInstances, GADTs, MultiParamTypeClasses,
  FlexibleContexts, FunctionalDependencies, UndecidableInstances
 #-}
{-# LANGUAGE CPP #-}

-- Internal representation of Terms

module Syntax.Internal where

#include "../undefined.h"
import Utils.Impossible

import Data.Function
import Data.Foldable hiding (notElem, concat, foldr, all)
import Data.Monoid

import Syntax.Common
import Syntax.Position
import qualified Syntax.Abstract as A

import Utils.Misc

data Sort
    = Type Int
    | Prop
    deriving(Eq, Show)

instance Ord Sort where
  compare Prop Prop = EQ
  compare Prop (Type _) = LT
  compare (Type _) Prop = GT
  compare (Type m) (Type n) = compare m n

tType :: Int -> Term
tType = Sort . Type
tProp :: Term
tProp = Sort Prop

type MetaId = Int
type Shift = Int
type CxtSize = Int

data Term
    = Sort Sort
    | Pi [Bind] Term
    | Bound Int  -- name is a hint
    | Var Name
    | Lam [Bind] Term
    | App Term [Term]
    -- | Meta MetaId Shift CxtSize
    -- | Constr Name (Name, Int) [Term] [Term]
    -- | Fix Int Name NamedCxt Type Term
    | Ind Name
    deriving(Show)

buildPi :: [Bind] -> Term -> Term
buildPi [] t = t
buildPi bs (Pi bs' t) = Pi (bs ++ bs') t
buildPi bs t = Pi bs t

buildApp :: Term -> [Term] -> Term
buildApp t [] = t
buildApp (App t ts) ts' = App t (ts ++ ts')
buildApp t ts = App t ts

buildLam :: [Bind] -> Term -> Term
buildLam [] t = t
buildLam bs (Lam bs' t) = Lam (bs ++ bs') t
buildLam bs t = Lam bs t

-- | Equality on terms is only used in the reification to terms, to group
-- contiguous bindings with the same type
instance Eq Term where
  (Sort s1) == (Sort s2) = s1 == s2
  (Pi bs1 t1) == (Pi bs2 t2) = length bs1 == length bs2 &&
                               all (uncurry (==)) (zip bs1 bs2) &&
                               t1 == t2
  (Bound n1) == (Bound n2) = n1 == n2
  (Var x1) == (Var x2) = x1 == x2
  (Lam bs1 t1) == (Lam bs2 t2) = length bs1 == length bs2 &&
                                 all (uncurry (==)) (zip bs1 bs2) &&
                                 t1 == t2
  (App f1 ts1) == (App f2 ts2) = length ts1 == length ts2 &&
                                 all (uncurry (==)) (zip ts1 ts2) &&
                                 f1 == f2
  (Ind i1) == (Ind i2) = i1 == i2
  _ == _ = False

type Type = Term

data Bind =
  Bind {
    bindName :: Name,
    bindType :: Type
    }
  | LocalDef {
    bindName :: Name,
    bindDef :: Term,
    bindType ::Type
    }
  deriving(Show)


bind :: Bind -> Type
bind (Bind _ t) = t
-- bind (NoBind t) = t
bind (LocalDef _ _ t) = t

bindNoName :: Type -> Bind
bindNoName t = Bind (Id "") t

instance Eq Bind where
  (Bind _ t1) == (Bind _ t2) = t1 == t2
  -- (NoBind t1) == (NoBind t2) = t1 == t2
  (LocalDef _ t1 t2) == (LocalDef _ t3 t4) = t1 == t3 && t2 == t4


class HasType a where
  getType :: a -> Type


data Global = Definition Type Term
            | Assumption Type
            | Inductive {
              indPars :: [Bind],
              indIndices :: [Bind],
              indSort :: Sort,
              indConstr :: [Name]
              }
            | Constructor {
              constrInd :: Name,
              constrId :: Int,   -- id
              constrPars :: [Bind], -- parameters, should be the same as
                                    -- the indutive type
              constrArgs :: [Bind], -- arguments
              constrIndices :: [Term]
              }
              deriving(Show)

instance HasType Global where
  getType (Definition t _) = t
  getType (Assumption t) = t
  getType i@(Inductive {}) = Pi (indPars i ++ indIndices i) (Sort (indSort i))
  getType c@(Constructor {}) = Pi (constrPars c ++ constrArgs c) ind
    where ind = App (Ind (constrInd c)) (par ++ indices)
          par = map (Var . bindName) (constrPars c)
          indices = constrIndices c


class Lift a where
  lift :: Int -> Int -> a -> a

  lift _ _ = error "Default impl of Lift" -- REMOVE THIS

instance Lift Bind where
  lift k n (Bind x t) = Bind x (lift k n t)
  lift k n (LocalDef x t1 t2) = LocalDef x (lift k n t1) (lift k n t2)

instance Lift Term where
  lift k n t@(Sort _) = t
  lift k n (Pi bs t) = Pi (map (lift k n) bs) (lift k (n + 1) t)
  lift k n t@(Bound m) = if m < n then t else Bound (m + k)
  lift k n t@(Var _) = t
  lift k n (Lam b u) = Lam (fmap (lift k n) b) (lift k (n + 1) u)
  lift k n (App t1 t2) = App (lift k n t1) $ map (lift k n) t2
  -- lift k n t@(Meta i m s) = if m < n then t else Meta i (m+k) s
  -- lift k n (Constr c x ps as) = Constr c x (map (lift k n) ps) (map (lift k n) as)
  -- lift k n (Fix m x bs t e) = Fix m x (liftCxt (flip lift n) k bs) (lift k (n+cxtSize bs) t) (lift k (n+1) e)

class SubstTerm a where
  subst :: Term -> a -> a
  substN :: Int -> Term -> a -> a

  substN = error "Defaul impl of SubstTerm"  -- REMOVE THIS!
  subst = substN 0

instance SubstTerm [Term] where
  substN n r = map (substN n r)

instance SubstTerm [Bind] where
  substN _ _ [] = []
  substN n r (Bind x t:bs) = Bind x (substN n r t) : substN (n + 1) r bs
  substN n r (LocalDef x t1 t2:bs) =
    LocalDef x (substN n r t1) (substN n r t2) : substN (n + 1) r bs

instance SubstTerm Term where
  substN i r t@(Sort _) = t
  substN i r (Pi bs t) = Pi (substN i r bs) (substN (i + len) r t)
                         where len = length bs
  substN i r t@(Bound n) | n < i = t
                         | n == i = lift i 0 r
                         | otherwise = Bound (n - 1)
  substN i r t@(Var _) = t
  substN i r (Lam bs t) = Lam (substN i r bs) (substN (i + len) r t)
                          where len = length bs
  substN i r (App t ts) = App (substN i r t) (substN i r ts)

      -- substN i r t@(Meta _ _ _) = t
      -- substN i r (Constr c x ps as) = Constr c x (map (substN i r) ps) (map (substN i r) as)
      -- substN i r (Fix n x bs t e) = Fix n x (substCxt_ i r bs) (substN (i+cxtSize bs) r t) (substN (i+1) r e)


applyTerms :: [Bind] -> Term -> [Term] -> Term
applyTerms [] body args = App body args
applyTerms binds body [] = Lam binds body
applyTerms (Bind x t:bs) body (a:as) = applyTerms (subst a bs) (substN (length bs) a body) as


flatten :: Term -> Term
flatten t@(Sort _) = t
flatten (Pi bs t) = Pi (bs ++ bs') t'
                    where (bs', t') = findBindsPi t
flatten t@(Bound _) = t
flatten t@(Var _) = t
flatten (Lam bs t) = Lam (bs ++ bs') t'
                     where (bs', t') = findBindsLam t
flatten (App t ts) = App func (args ++ ts)
                     where (func, args) = findArgs t
flatten t@(Ind _) = t

findBindsPi :: Term -> ([Bind], Term)
findBindsPi (Pi bs t) = (bs ++ bs', t')
                        where (bs', t') = findBindsPi t
findBindsPi t = ([], t)

findBindsLam :: Term -> ([Bind], Term)
findBindsLam (Lam bs t) = (bs ++ bs', t')
                          where (bs', t') = findBindsLam t
findBindsLam t = ([], t)

findArgs :: Term -> (Term, [Term])
findArgs (App t ts) = (func, args++ts)
                      where (func, args) = findArgs t
findArgs t = (t, [])
