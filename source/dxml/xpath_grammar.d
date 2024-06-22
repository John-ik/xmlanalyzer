module dxml.xpath_grammar;

public import pegged.grammar;

ParseTree parseXPath (string xpath)
{
    ParseTree a = XPathMini(xpath);
    if (a.successful == false) throw new XPathParserException(a.failMsg);
    return a;
}
enum grammarName = "XPathMini";
ParseTree find (ParseTree node, string nodeName)
{
    foreach (ParseTree child; node.children)
    {
        if (child.name == nodeName)
            return child;
    }
    return ParseTree.init;
}

mixin(grammar(`
XPathMini:
    LocationPath    <- (AbsoluteLocationPath
                    /   RelativeLocationPath
                    ) eoi
    AbsoluteLocationPath    <-  AbbreviatedAbsoluteLocationPath
                            /   '/' RelativeLocationPath?
    AbbreviatedAbsoluteLocationPath <-  '//' RelativeLocationPath
    RelativeLocationPath    <-  Step '//' RelativeLocationPath
                            /   Step '/' RelativeLocationPath
                            /   Step

    Step    <-  AbbreviatedStep
            |   AxisSpecifier NodeTest # Predicate*
    AbbreviatedStep <-  '..'
                    /   '.'
    AxisSpecifier   <-  AbbreviatedAxisSpecifier
                    |   AxisName '::'
    NodeTest    <-  NameTest
                |   TypeTest
    TypeTest    <- ('processing-instruction' / 'comment' / 'text' / 'node') '()'
    NameTest    <-  Name
                |   '*'

    AbbreviatedAxisSpecifier    <- '@'?
    AxisName    <-  'ancestor-or-self'	
                /   'ancestor'	
                /   'attribute'	
                /   'child'	
                /   'descendant-or-self'	
                /   'descendant'	
                /   'following-sibling'	
                /   'following'	
                /   'namespace'	
                /   'parent'	
                /   'preceding-sibling'	
                /   'preceding'	
                /   'self'

    NameStartChar <- ":" / [A-Z] / "_" / [a-z] / [\xC0-\xD6\xD8-\xF6]
    NameChar <- NameStartChar / "-" / "." / [0-9] / '\xB7'
    Name <~ NameStartChar (NameChar)*
`));

/*
mixin(grammar(`
XPathFull:
    LocationPath    <- RelativeLocationPath
                    |  AbsoluteLocationPath
    AbsoluteLocationPath    <- '/' RelativeLocationPath?
                            |  AbbreviatedAbsoluteLocationPath
    RelativeLocationPath    <- Step
                            | RelativeLocationPath '/' Step
                            | AbbreviatedRelativeLocationPath
    Step    <-  AxisSpecifier NodeTest Predicate*
            |   AbbreviatedStep
    AxisSpecifier   <-  AxisName '::'
                    |   AbbreviatedAxisSpecifier
    AxisName    <-  'ancestor'
                |   'ancestor-or-self'
                |   'attribute'
                |   'child'
                |   'descendant'
                |   'descendant-or-self'
                |   'following'
                |   'following-sibling'
                |   'namespace'
                |   'parent'
                |   'preceding'
                |   'preceding-sibling'
                |   'self'
    NodeTest    <-  NameTest
                |   NodeType '(' ')'
                |   'processing-instruction' '(' Literal ')'
    Predicate   <-  '[' PredicateExpr ']'
    PredicateExpr   <-  Expr
    AbbreviatedAbsoluteLocationPath <-  '//' RelativeLocationPath
    AbbreviatedRelativeLocationPath <-  RelativeLocationPath '//' Step
    AbbreviatedStep <-  '.'
                    |   '..'
    AbbreviatedAxisSpecifier    <-  '@'?
    Expr    <-  OrExpr
    PrimaryExpr <-  VariableReference
                |   '(' Expr ')'
                |   Literal
                |   Number
                |   FunctionCall
    FunctionCall    <-  FunctionName '(' ( Argument ( ',' Argument )* )? ')'
    Argument    <-  Expr
    UnionExpr   <-  PathExpr
                |   UnionExpr '|' PathExpr
    PathExpr    <-  LocationPath
                |   FilterExpr
                |   FilterExpr '//' RelativeLocationPath
                |   FilterExpr '/' RelativeLocationPath
    FilterExpr  <-  PrimaryExpr
                |   FilterExpr Predicate
    OrExpr  <-  AndExpr
            |   OrExpr 'or' AndExpr
    AndExpr <-  EqualityExpr
            |   AndExpr 'and' EqualityExpr
    EqualityExpr    <-  RelationalExpr
                    |   EqualityExpr '=' RelationalExpr
                    |   EqualityExpr '!=' RelationalExpr
    RelationalExpr  <-  AdditiveExpr
                    |   RelationalExpr '<' AdditiveExpr
                    |   RelationalExpr '>' AdditiveExpr
                    |   RelationalExpr '<=' AdditiveExpr
                    |   RelationalExpr '>=' AdditiveExpr
    AdditiveExpr    <-  MultiplicativeExpr	
                    |   AdditiveExpr '+' MultiplicativeExpr	
                    |   AdditiveExpr '-' MultiplicativeExpr	
    MultiplicativeExpr  <-  UnaryExpr	
                        |   MultiplicativeExpr MultiplyOperator UnaryExpr	
                        |   MultiplicativeExpr 'div' UnaryExpr	
                        |   MultiplicativeExpr 'mod' UnaryExpr	
    UnaryExpr   <-  UnionExpr	
                |   '-' UnaryExpr

    NameTest    <- '*'
                |   NCName ':' '*'
                |   QName
`));
*/

import std.exception : basicExceptionCtors;
class XPathParserException : Exception {
    mixin basicExceptionCtors;
}