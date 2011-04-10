{

module Syntax.Parser where

import Control.Monad.State

import Syntax.Tokens
import Syntax.Lexer
import Syntax.ParseMonad
import Syntax.Position
import Syntax.Name
import Syntax.Alex
import qualified Syntax.Abstract as A

}


%name exprParser Exp
%name fileParser Decls
%tokentype { Token }
%monad { Parser }
%lexer { lexer } { TokEOF }

%token
  'forall'         { TokKeyword KwForall $$ }
  'fun'            { TokKeyword KwFun $$ }
  'prop'           { TokKeyword KwProp $$ }
  'let'            { TokKeyword KwLet $$ }
  'import'         { TokKeyword KwImport $$ }
  'axiom'          { TokKeyword KwAxiom $$ }
  'data'           { TokKeyword KwData $$ }

  '('              { TokSymbol SymbLeftParen $$}
  ')'              { TokSymbol SymbRightParen $$}
  '.'              { TokSymbol SymbDot $$ }
  ':='             { TokSymbol SymbColonEq $$ }
  ':'              { TokSymbol SymbColon $$ }
  ','              { TokSymbol SymbComma $$ }
  '=>'             { TokSymbol SymbImplies $$ }
  '->'             { TokSymbol SymbArrow $$ }
  '|'              { TokSymbol SymbBar $$ }
  typeN            { TokType $$ }
  ident            { TokIdent $$ }

%%

Decls :: { [A.Declaration] }
Decls : DeclsR        { reverse $1 }

DeclsR :: { [A.Declaration] }
DeclsR : Decl '.'          { [$1] }
       | DeclsR Decl '.'   { $2 : $1 }

Decl :: { A.Declaration }
Decl
  : 'let' ident MaybeExp ':=' Exp
         { A.Definition (fuseRange $1 $5) (snd $2) $3 $5 }
  | 'axiom' ident ':' Exp
         { A.Axiom (fuseRange $1 $4) (snd $2) $4 }
  | 'data' ident Telescope ':' Exp ':=' Constructors
         { A.Inductive (fuseRange $1 $7) (snd $2) $3 $5 $7 }

Telescope :: { A.Telescope }
Telescope : Bindings1            { $1 }
          | {- empty -}          { [] }


-- For the first constructor, the '|' before its definition is optional
Constructors :: { [A.Constructor] }
Constructors : Constr1 Constr2       { maybe [] return $1 ++ reverse $2 }

Constr1 :: { Maybe A.Constructor }
Constr1 : BasicConstr            { Just $1 }
        | {- empty -}            { Nothing }

Constr2 :: { [A.Constructor] }
Constr2 : {- empty -}                { [] }
        | Constr2 '|' BasicConstr    { $3 : $1 }

-- Constructors are given id 0 by the parser. The actual id is given by the
-- scope checker.
BasicConstr :: { A.Constructor }
BasicConstr : ident ':' Exp      { let (p,x) = $1
                                   in A.Constructor (fuseRange p $3) x $3 0 }

Exp :: { A.Expr }
Exp : 'forall' Binding ',' Exp   { A.Pi (fuseRange $1 $4) $2 $4 }
    | 'fun' Binding '=>' Exp     { A.Lam (fuseRange $1 $4) $2 $4 }
    | Exp1 Rest                  { case $2 of
                                     Just e -> A.Pi (fuseRange $1 e) [A.NoBind $1] e
                                     Nothing -> $1 }

Exp1 :: { A.Expr }
Exp1 : Exps2             { mkApp $1 }

Exps2 :: { [A.Expr] }
Exps2 : Exp2           { [$1] }
      | Exps2 Exp2     { $2 : $1 }

Exp2 :: { A.Expr }
Exp2 : '(' Exp ')'   { $2 }
     | Sort          { $1 }
     | ident         { A.Var (mkRangeLen (fst $1) (length (snd $1))) (snd $1) }

-- This does not look elegant
Sort :: { A.Expr }
Sort : 'prop'  { A.Sort (mkRangeLen $1 4) A.Prop }
     | typeN   { let (pos, lvl) = $1
                 in  A.Sort (mkRangeLen pos (4 + length (show lvl))) (A.Type lvl) }


MaybeExp :: { Maybe A.Expr }
MaybeExp : ':' Exp       { Just $2 }
         | {- empty -}   { Nothing }

Rest :: { Maybe A.Expr }
Rest : '->' Exp          { Just $2 }
     | {- empty -}       { Nothing }

Binding :: { [A.Bind] }
Binding : BasicBind       { [$1] }
        | Bindings1       { reverse $1 }

Bindings1 :: { [A.Bind] }
Bindings1 : '(' BasicBind ')'             { [$2] }
          | Bindings1 '(' BasicBind ')'   { $3 : $1 }

BasicBind :: { A.Bind }
BasicBind : Names ':' Exp   { A.Bind (fuseRange (snd $1) $3) (fst $1) $3 }

Names :: { ([Name], Range) }
Names : Names1              { let r = reverse $1
                              in (map snd r, fuseRanges $ map fst r) }

Names1 :: { [(Position, Name)] }
Names1 : ident              { [$1] }
       | Names1 ident       { $2 : $1 }

{

-- Required by Happy.
happyError :: Parser a
happyError = do s <- get
                parseErrorAt (lexPos s) "Parser error"

-- Note that mkApp receives arguments in reverse order
mkApp :: [A.Expr] -> A.Expr
mkApp [x] = x
mkApp (x:y:ys) = A.App (fuseRange r x) r x
                 where r = mkApp (y:ys)


}