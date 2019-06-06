{

-- | Generated by Happy (<http://www.haskell.org/happy>)
--
-- TODO
--
-- * Check if BindName is used in all places where a _ can be used instead
--   of an actual name.


module CICminus.Syntax.Parser(exprParser,
                              fileParser) where

import Control.Monad.State

import Data.List
import Data.Maybe

import CICminus.Syntax.Tokens
import CICminus.Syntax.Lexer
import CICminus.Syntax.ParseMonad
import CICminus.Syntax.Position
import CICminus.Syntax.Size
import CICminus.Syntax.Common
import CICminus.Syntax.Alex
import qualified CICminus.Syntax.Concrete as C

import CICminus.Utils.Misc
import CICminus.Utils.Sized

}


%name exprParser Exp
%name fileParser Decls
%tokentype { Token }
%monad { Parser }
%lexer { lexer } { TokEOF }

%right '->'

%token
  'forall'         { TokKeyword KwForall $$ }
  'fun'            { TokKeyword KwFun $$ }
  'prop'           { TokKeyword KwProp $$ }
  'type'           { TokKeyword KwType $$ }
  'assume'         { TokKeyword KwAssume $$ }
  'define'         { TokKeyword KwDefine $$ }
  'eval'           { TokKeyword KwEval $$ }
  'check'          { TokKeyword KwCheck $$ }
  'print'          { TokKeyword KwPrint $$ }
  'data'           { TokKeyword KwData $$ }
  'codata'         { TokKeyword KwCodata $$ }
  'case'           { TokKeyword KwCase $$ }
  'in'             { TokKeyword KwIn $$ }
  'of'             { TokKeyword KwOf $$ }
  'fix'            { TokKeyword KwFix $$ }
  'cofix'          { TokKeyword KwCofix $$ }
  'fixpoint'       { TokKeyword KwFixpoint $$ }
  'cofixpoint'     { TokKeyword KwCofixpoint $$ }
  'rec'            { TokKeyword KwRec $$ }
  'where'          { TokKeyword KwWhere $$ }
  'end'            { TokKeyword KwEnd $$ }
  fixN             { TokFixNumber $$ }
  typeN            { TokTypeNumber $$ }


  '('              { TokSymbol SymbLeftParen $$}
  ')'              { TokSymbol SymbRightParen $$}
  '{'              { TokSymbol SymbLeftBrace $$}
  '}'              { TokSymbol SymbRightBrace $$}
  '.'              { TokSymbol SymbDot $$ }
  ':='             { TokSymbol SymbColonEq $$ }
  ':'              { TokSymbol SymbColon $$ }
  ','              { TokSymbol SymbComma $$ }
  '=>'             { TokSymbol SymbImplies $$ }
  '->'             { TokSymbol SymbArrow $$ }
  '|'              { TokSymbol SymbBar $$ }
  '+'              { TokSymbol SymbPos $$ }
  '-'              { TokSymbol SymbNeg $$ }
  '++'             { TokSymbol SymbSPos $$ }
  '*'              { TokSymbol SymbStar $$ }
  '@'              { TokSymbol SymbNeut $$ }
  '<'              { TokSymbol SymbLAngle $$ }
  '>'              { TokSymbol SymbRAngle $$ }
  '['              { TokSymbol SymbLBracket $$ }
  ']'              { TokSymbol SymbRBracket $$ }
  '_'              { TokKeyword KwMeta $$ }

  ident            { TokIdent $$ }
  identStar        { TokIdentStar $$ }

  number           { TokNumber $$ }

%%

Decls :: { [C.Declaration] }
Decls : DeclsR        { reverse $1 }

DeclsR :: { [C.Declaration] }
DeclsR : Decl '.'          { [$1] }
       | DeclsR Decl '.'   { $2 : $1 }

Decl :: { C.Declaration }
Decl
     : 'define' Name MaybeConstrExp ':=' Exp
       { C.Definition (fuseRange $1 $5) (rangedValue $2) $3 $5 }
     | 'assume' Name ':' ConstrExp
       { C.Assumption (fuseRange $1 $4) (rangedValue $2) $4 }
     | 'data' Name Parameters ':' Exp ':=' Constructors
       { C.Inductive (fuseRange $1 $7) (C.InductiveDef (rangedValue $2) I (ctxFromList (reverse (fst $3))) (reverse (snd $3)) $5 $7) }
     | 'codata' Name Parameters ':' Exp ':=' Constructors
       { C.Inductive (fuseRange $1 $7) (C.InductiveDef (rangedValue $2) CoI (ctxFromList (reverse (fst $3))) (reverse (snd $3)) $5 $7) }
     | 'eval' Exp
       { C.Eval $2 }
     | 'check' Exp MaybeExp
       { C.Check $2 $3 }
     | 'print' Name
       { C.Print (range $2) (rangedValue $2) }
     | 'fixpoint' Fixpoint { C.Cofixpoint $2 }
     | 'cofixpoint' Cofixpoint { C.Cofixpoint $2 }


Parameters :: { ([C.Bind], [Polarity]) }
Parameters : Parameters Par { (fst $2 : fst $1, snd $2 ++ snd $1) }
           | {- empty -}    { ([], []) }

Par :: { (C.Bind, [Polarity]) }
Par : '(' NamesPol ':' Exp ')' { (C.Bind (fuseRange $1 $5) (reverse (fst $2)) $ mkArg $4, reverse (snd $2)) }

NamesPol :: { ([Name], [Polarity]) }
NamesPol : NamesPol BindName Polarity    { (rangedValue $2 : fst $1, $3 : snd $1) }
         | BindName Polarity             { ([rangedValue $1], [$2]) }

Polarity :: { Polarity }
Polarity : '+'            { Pos }
         | '-'            { Neg }
         | '++'           { SPos }
         | '@'            { Neut }
         | {- empty -}    { Neut } -- default polarity

-- For the first constructor, the '|' before its definition is optional
Constructors :: { [C.Constructor] }
Constructors : FirstConstr Constr       { maybe [] return $1 ++ reverse $2 }

FirstConstr :: { Maybe C.Constructor }
FirstConstr : BasicConstr            { Just $1 }
            | {- empty -}            { Nothing }

Constr :: { [C.Constructor] }
Constr : {- empty -}                { [] }
       | Constr '|' BasicConstr    { $3 : $1 }

BasicConstr :: { C.Constructor }
BasicConstr : Name ':' Exp
              { C.Constructor (fuseRange $1 $3) (rangedValue $1) $3 }

TLExp :: { C.ConstrExpr }
TLExp : '{' PureNames '}' '->' Exp  { C.ConstrExpr (fuseRange $1 $3) (fst $2) $5 }


Exp :: { C.Expr }
Exp : 'forall' Binding '.' Exp   { C.Pi (fuseRange $1 $4) (ctxFromList $2) $4 }
    | 'fun' Binding '=>' Exp     { C.Lam (fuseRange $1 $4) (ctxFromList $2) $4 }
    | Exps1 Rest                 {
                                   let r = mkApp $1
                                   in case $2 of
                                        Just e -> mkArrow (fuseRange r e) explicitArg r e -- TODO: add arrows with implicit arguments
                                        Nothing -> r
                                 }
    -- | Exp1 '->' Exp               { mkArrow (fuseRange $1 $3) explicitArg $1 $3 }
    -- | Exps1                      { mkApp $1 }
    | Case                       { C.Case $1 }
    | Fix                        { C.Fix $1 }

BindingArrow :: { [C.Bind] }
BindingArrow :
   Bindings1 '->'     { reverse $1 }

-- Exps :: { [C.Expr] }
-- Exps : Exps Exp          { $2 : $1 }
--      | {- empty -}       { [] }

Exps1 :: { [C.Expr] }
Exps1 : Exp1           { [$1] }
      | Exps1 Exp1     { $2 : $1 }

Exp1 :: { C.Expr }
Exp1 : '(' Exp ')'   { $2 }
     | Sort          { $1 }
     | Name '<' Size '>'          { C.SApp (fuseRange $1 $4) (rangedValue $1) C.UnknownIdent $3 }
     | Name          { C.Ident (range $1) (rangedValue $1) C.UnknownIdent }
     | '_'           { C.Meta (mkRangeLen $1 1) Nothing }
     -- | identStar     {% unlessM starAllowed (fail $ "position type not allowed" ++ show (fst $1)) >> return (C.Ind (mkRangeLen (fst $1) (length (snd $1))) Star (mkName (snd $1)) []) } -- TODO: Parameter list
     | identStar     { let rg = mkRangeLen (fst $1) (length (snd $1))
                       in C.SApp rg (mkName (snd $1)) C.UnknownIdent (C.SizeStar rg) }
     | number        { let (pos, num) = $1
                       in  C.Number (mkRangeLen pos (length (show num))) num }
     -- | Exps1         { mkApp $1 }


Size :: { C.SizeExpr }
Size : Name '+' number  { let (pos, num) = $3
                          in C.SizeExpr (fuseRange $1 pos) (rangedValue $1) num }
     | Name             { C.SizeExpr (range $1) (rangedValue $1) 0 }
     | '*'              { C.SizeStar (range $1) }

Sort :: { C.Expr }
Sort : 'prop'  { C.mkProp (mkRangeLen $1 4) }
     | 'type'  { C.mkType (mkRangeLen $1 4) 0 }
     | typeN   { let (pos, num) = $1
                 in C.mkType (mkRangeLen pos (4 + length (show num))) num }

MaybeExp :: { Maybe C.Expr }
MaybeExp : ':' Exp       { Just $2 }
         | {- empty -}   { Nothing }

MaybeConstrExp :: { Maybe C.ConstrExpr }
MaybeConstrExp : ':' ConstrExp     { Just $2 }
               | {- empty -}       { Nothing }

ConstrExp :: { C.ConstrExpr }
ConstrExp : Constraint Exp  { C.ConstrExpr (snd $1) (fst $1) $2 }

Constraint :: { ([Name], Range) }
Constraint : '{' Names '}' '=>'   { $2 }
           | {- empty -}         { ([], noRange) }

Rest :: { Maybe C.Expr }
Rest : '->' Exp          { Just $2 }
     | {- empty -}       { Nothing }

Case :: { C.CaseExpr }
Case : CaseRet 'case' CaseArg Indices 'of' Branches 'end'
                         { let rg = maybe (fuseRange $2 $7)
                                          (flip fuseRange $7) $1
                           in C.CaseExpr rg (fst $3) (snd $3) $4 $1 $6 }

CaseArg :: { (C.Expr, Name) }
CaseArg : Name ':=' Exp      { ($3, rangedValue $1) }
        | Exp                { ($1, noName) }

CaseRet :: { Maybe C.Expr }
CaseRet : '<' Exp '>'     { Just $2 }
        | {- empty -}     { Nothing }

In :: { Maybe C.IndicesSpec }
In : 'in' Name Pattern
                 { Just $ C.IndicesSpec (fuseRange $1 $3) (rangedValue $2) $3 }
   | {- empty -}
                 { Nothing }

InArgs :: { [C.Bind] }
InArgs : InArgs BindNoType         { $2 : $1 }
       | {- empty -}               { [] }

InContext :: { [C.Bind] }
InContext : '[' Binding ']'        { $2 }
          | {- empty -}            { [] }


Indices :: { Maybe C.IndicesSpec }
Indices : 'in' Name Pattern
                 { Just $ C.IndicesSpec (fuseRange $1 $3) (rangedValue $2) $3 }
        | {- empty -}
                 { Nothing }

Pattern :: { C.Pattern }
Pattern : BindName Pattern     { C.PatternVar (range $1) (rangedValue $1) : $2 }
        | '(' Exp ')' Pattern  { C.PatternDef (fuseRange $1 $3) noName $2 : $4 }
        | '(' BindName ':=' Exp ')' Pattern
             { C.PatternDef (fuseRange $1 $5) (rangedValue $2) $4 : $6 }
        | {- empty -}   { [] }


Branches :: { [C.Branch] }
Branches : BasicBranch Branch2   { $1 : $2 }
         | '|' BasicBranch Branch2 { $2 : $3 }
         | {- empty -}           { [] }


Branch1 :: { Maybe C.Branch }
Branch1 : BasicBranch            { Just $1 }
        | {- empty -}            { Nothing }

Branch2 :: { [C.Branch] }
Branch2 : '|' BasicBranch Branch2    { $2 : $3 }
        | {- empty -}     { [] }

BasicBranch :: { C.Branch }
BasicBranch : Name Pattern '=>' Exp
                             { let rg = fuseRange (range $1) $4
                               in C.Branch rg (rangedValue $1) $2 $4 }


Fix :: { C.FixExpr }
Fix : 'fix' Fixpoint { setRange (fuseRange $1 $2) $2 }
    | 'cofix' Cofixpoint { setRange (fuseRange $1 $2) $2 }
-- Fix :: { C.FixExpr }
-- Fix : 'fix' Name '<' Name '>' Binding ':' Exp ':=' Exp
--                       { C.FixExpr (fuseRange $1 $10) I (rangedValue $2) (C.FixStage (fuseRange $3 $5) (rangedValue $4)) (ctxFromList $6) $8 $10 }
--     | 'fix' Name BindingStruct ':' Exp ':=' Exp
--                       { let (ctx, nm) = $3
--                         in case nm of
--                              Just nm -> C.FixExpr (fuseRange $1 $7) I (rangedValue $2) (C.FixStruct (range nm) (rangedValue nm)) (ctxFromList ctx) $5 $7
--                              Nothing -> C.FixExpr (fuseRange $1 $7) I (rangedValue $2) C.FixPosition (ctxFromList ctx) $5 $7 }
--     | 'cofix' Name '<' Name '>' Binding ':' Exp ':=' Exp
--                       { C.FixExpr (fuseRange $1 $10) I (rangedValue $2) (C.FixStage (fuseRange $3 $5) (rangedValue $4)) (ctxFromList $6) $8 $10 }
--     | 'cofix' Name BindingStruct ':' Exp ':=' Exp
--                       { let (ctx, nm) = $3
--                         in case nm of
--                              Just nm -> C.FixExpr (fuseRange $1 $7) CoI (rangedValue $2) (C.FixStruct (range nm) (rangedValue nm)) (ctxFromList ctx) $5 $7
--                              Nothing -> C.FixExpr (fuseRange $1 $7) CoI (rangedValue $2) C.FixPosition (ctxFromList ctx) $5 $7 }


Fixpoint :: { C.FixExpr }
Fixpoint : Name '<' Name '>' Binding ':' Exp ':=' Exp
                      { C.FixExpr (fuseRange $1 $9) I (rangedValue $1) (C.FixStage (fuseRange $2 $4) (rangedValue $3)) (ctxFromList $5) $7 $9 }
    | Name BindingStruct ':' Exp ':=' Exp
                      { let (ctx, nm) = $2
                        in case nm of
                             Just nm -> C.FixExpr (fuseRange $1 $6) I (rangedValue $1) (C.FixStruct (range nm) (rangedValue nm)) (ctxFromList ctx) $4 $6
                             Nothing -> C.FixExpr (fuseRange $1 $6) I (rangedValue $1) C.FixPosition (ctxFromList ctx) $4 $6 }


Cofixpoint :: { C.FixExpr }
Cofixpoint : Name '<' Name '>' Binding ':' Exp ':=' Exp
                      { C.FixExpr (fuseRange $1 $9) CoI (rangedValue $1) (C.FixStage (fuseRange $2 $4) (rangedValue $3)) (ctxFromList $5) $7 $9 }
    | Name Binding ':' Exp ':=' Exp
                      { C.FixExpr (fuseRange $1 $6) CoI (rangedValue $1) C.FixPosition (ctxFromList $2) $4 $6 }



startPosType :: { () }
startPosType : {- empty -}       {% allowStar }

endPosType :: { () }
endPosType : {- empty -}         {% forbidStar }

-- Bindings :: { [C.Bind] }
-- Bindings : Bindings '(' BasicBind ')'        { $3 : $1 }
--          | Bindings '{' BasicImplBind '}'    { $3 : $1 }
--          | {- empty -}                       { [] }

BindingStruct :: { ([C.Bind], Maybe (Ranged Name)) }
BindingStruct : '{' 'rec' Name '}'
              { ([], Just (setRange (fuseRange $2 $3) $3)) }
              | '{' SimpleBind '}' BindingStruct
              { let (bs, x) = $4
                in (setRange (fuseRange $1 $3) (setImplicit True $2) : bs, x) }
              | '(' SimpleBind ')' BindingStruct
              { let (bs, x) = $4
                in (setRange (fuseRange $1 $3) (setImplicit False $2) : bs, x) }
              | {- empty -}   { ([], Nothing) }

Binding :: { [C.Bind] }
Binding : SimpleBind      { [$1] }
        | Bindings1       { (reverse $1) }

Bindings1 :: { [C.Bind] }
Bindings1 : '(' SimpleBind ')'                { [setRange (fuseRange $1 $3) (setImplicit False $2)] }
          | '{' SimpleBind '}'             { [setRange (fuseRange $1 $3) (setImplicit True $2)] }
          | Bindings1 '(' SimpleBind ')'       { setRange (fuseRange $2 $4) (setImplicit False $3) : $1 }
          | Bindings1 '{' SimpleBind '}'   { setRange (fuseRange $2 $4) (setImplicit True $3) : $1 }
 | {- empty -} { [] }

SimpleBind :: { C.Bind }
SimpleBind : CommaBIdAndAbsurds ':' Exp   { C.Bind (fuseRange (snd $1) $3) (fst $1) (mkArg $3) }


CommaBIdAndAbsurds :: { ([Name], Range) }
CommaBIdAndAbsurds : Exps1 {%
    let getName (C.Ident _ x _) = Just x
        getName (C.Meta _ _)    = Just noName
        getName _               = Nothing

    in
      case partition isJust $ map getName $1 of
        (good, []) -> return $ (map fromJust (reverse good), fuseRanges $1)
        _          -> fail $ "expected sequence of bound identifiers"
    }



BindNoType :: { C.Bind }
BindNoType : Name   { C.BindName (range $1) explicitArg (rangedValue $1) }
           | '(' Name ':=' Exp ')'
                    { C.LetBind (fuseRange $1 $5) (rangedValue $2) $4 (mkArg Nothing) }


-- BasicImplBind :: { C.Bind }
-- -- BasicImplBind : Names ':' Exp   { C.mkBind (fuseRange (snd $1) $3) True (head (fst $1)) $3 }
-- BasicImplBind : Names ':' Exp   { C.Bind (head (fst $1)) $3 }

Name :: { Ranged Name }
Name : ident      { let (p, x) = $1
                    in let ident = if x == "_" then noName else mkName x
                    in mkRanged (mkRangeLen p (size ident)) ident }

PureNames :: { ([Name], Range) }
PureNames : PureNames1              { let ns = reverse $1
                                      in (map rangedValue ns, fuseRanges ns) }

PureNames1 :: { [Ranged Name] }
PureNames1 : Name           { [$1] }
           | Names1 Name    { $2 : $1 }

Names :: { ([Name], Range) }
Names : Names1              { let ns = reverse $1
                              in (map rangedValue ns, fuseRanges ns) }

Names1 :: { [Ranged Name] }
Names1 : BindName           { [$1] }
       | Names1 BindName    { $2 : $1 }

BindName :: { Ranged Name }
BindName : ident            { let (p, x) = $1
                              in let ident = if x == "_" then noName else mkName x
                              in (mkRanged (mkRangeLen p (size ident)) ident) }
         | '_'              { mkRanged (mkRangeLen $1 1) noName }

{

-- Required by Happy.
happyError :: Parser a
happyError = do s <- getLexerInput
                parseErrorAt (lexPos s) "Parser error"

-- Note that mkApp receives arguments in reverse order
mkApp :: [C.Expr] -> C.Expr
mkApp [x] = x
mkApp (x:y:ys) = C.App (fuseRange r x) r explicitArg x
                 where r = mkApp (y:ys)

mkArrow :: Range -> ArgType -> C.Expr -> C.Expr -> C.Expr
mkArrow r arg e1 e2 =
  C.Pi r (ctxSingle (C.Bind (range e1) [noName] (mkArgType e1 arg))) e2

}
