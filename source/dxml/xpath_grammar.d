module dxml.xpath_grammar;

@safe:

public import pegged.grammar;

ParseTree parseXPath (string xpath)
{
    if (xpath == "") return ParseTree.init;
    ParseTree a = XPathMini(xpath);
    if (a.successful == false) 
    {
        import std.stdio, std.datetime;
        File("parseTreeDump.pegged.txt", "w")
            .writefln("Datetime: %s\nXPath: %s\n\n%s",
            std.datetime.Clock.currTime(), xpath, a);
        throw new XPathParserException(a.failMsg);
    }
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
    XPath <- Expr spacing eoi
    Expr <- OrExpr # the most general grammatical construct

    LocationPath    <- (AbsoluteLocationPath / RelativeLocationPath)
    AbsoluteLocationPath    <-  AbbreviatedAbsoluteLocationPath
                            /   '/' RelativeLocationPath?
    AbbreviatedAbsoluteLocationPath <-  '//' RelativeLocationPath
    RelativeLocationPath    <-  Step '//' RelativeLocationPath
                            /   Step '/' RelativeLocationPath
                            /   Step

    Step    <-  AbbreviatedStep
            /   AxisSpecifier NodeTest Predicate*
    AbbreviatedStep <-  '..'
                    /   '.'

    AxisSpecifier   <-  AxisName '::'
                    /   AbbreviatedAxisSpecifier

    NodeTest    <-  PiTest
                /   TypeTest '()'
                /   NameTest
    PiTest  <-  'processing-instruction' '(' Literal ')'
    TypeTest    <- 'processing-instruction' / 'comment' / 'text' / 'node'
    NameTest    <-  '*'
                /   Name

    Predicate   <-  '[' Expr ']'
    PrimaryExpr <-  '(' Expr ')'
    #            /   VariableReference # //XXX: WHAT is this???
                /   Literal
                /   Number
                /   FunctionCall
    FunctionCall    <-  FunctionName '(' ( Expr ( ',' Expr )* )? ')'
    FunctionName    <-  !TypeTest Name

    OrExpr  <-  # AndExpr # Я пока пропущу
            /   UnionExpr
    UnionExpr   <-  ( PathExpr '|' UnionExpr ) / PathExpr
    PathExpr    <-  LocationPath

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

    Literal <~  quote (!quote .)* quote
            /   doublequote (!doublequote .)* doublequote
    Number  <~  '.' digits
            /   digits ('.' digits?)?
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