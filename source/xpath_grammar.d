module xpath_grammar;

@safe:

public import pegged.grammar;

/// filename where store last failed ParseTree
immutable XPathGrammarErrorDumpFile = "parseTreeDump.pegged.txt";

/++
Process XPath string to `ParseTree`

If process failed dump it to `XPathGrammarErrorDumpFile` and throw `XPathParserException`
+/
ParseTree parseXPath (string xpath)
{
    if (xpath == "") return ParseTree.init;
    ParseTree a = XPathMini(xpath);
    if (a.successful == false) 
    {
        import std.stdio, std.datetime;
        File(XPathGrammarErrorDumpFile, "w")
            .writefln("Datetime: %s\nXPath: %s\n\n%s",
            std.datetime.Clock.currTime(), xpath, a);
        writefln!"ParseTree dump has written to %s"(XPathGrammarErrorDumpFile);
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
                            /   S? '/' S? RelativeLocationPath?
    AbbreviatedAbsoluteLocationPath <-  S? '//' S? RelativeLocationPath
    RelativeLocationPath    <-  Step S? '//' S? RelativeLocationPath
                            /   Step S? '/'  S? RelativeLocationPath
                            /   Step

    Step    <-  AbbreviatedStep
            /   AxisSpecifier NodeTest Predicate*
    AbbreviatedStep <-  S? '..' S?
                    /   S? '.'  S?

    AxisSpecifier   <-  AxisName S? '::' S?
                    /   AbbreviatedAxisSpecifier

    NodeTest    <-  PiTest
                /   TypeTest S? '(' S? ')' S?
                /   NameTest
    PiTest  <-  S? 'processing-instruction' S? '(' Literal ')' S?
    TypeTest    <- S? ('processing-instruction' / 'comment' / 'text' / 'node') S?
    NameTest    <-  S? ( '*'
                /   Name ) S?

    Predicate   <-  S? '[' S? Expr S? ']' S?
    PrimaryExpr <-  S? '(' S? Expr S? ')' S?
                /   VariableReference
                /   Literal
                /   Number
                /   FunctionCall
    FunctionCall    <-  S? FunctionName S? '(' S? ( Expr ( S? ',' S? Expr )* )? S? ')' S?
    FunctionName    <-  !TypeTest Name

    OrExpr  <-  OrExpr S? 'or' S? AndExpr
            /   AndExpr
    AndExpr <-  AndExpr S? 'and'S? EqualityExpr
            /   EqualityExpr
    EqualityExpr    <-  EqualityExpr S? '=' S? RelationalExpr
                    /   EqualityExpr S? '!=' S? RelationalExpr
                    /   RelationalExpr
    RelationalExpr  <-  RelationalExpr S? '<=' S? AdditiveExpr
                    /   RelationalExpr S? '>=' S? AdditiveExpr
                    /   RelationalExpr S? '<' S?  AdditiveExpr
                    /   RelationalExpr S? '>' S?  AdditiveExpr
                    /   AdditiveExpr
    AdditiveExpr    <-  AdditiveExpr S? '+' S? MultiplicativeExpr
                    /   AdditiveExpr S '-' S MultiplicativeExpr # Пробелы обязательны так как в именах xml разрешены '-'
                    /   MultiplicativeExpr
    MultiplicativeExpr  <-  MultiplicativeExpr S? '*' S? UnaryExpr
                        /   MultiplicativeExpr S? 'div'S? UnaryExpr
                        /   MultiplicativeExpr S? 'mod'S? UnaryExpr
                        /   UnaryExpr
    UnaryExpr   <- '-' UnaryExpr
                /   UnionExpr
    UnionExpr   <-  ( PathExpr S? '|' S? UnionExpr ) / PathExpr
    PathExpr    <-  FilterExpr / LocationPath
    FilterExpr  <-  (FilterExpr Predicate) / PrimaryExpr 

    AbbreviatedAxisSpecifier    <- (S? '@' S?)?
    AxisName    <-  S? (
                    'ancestor-or-self'	
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
                    ) S?

    NameStartChar <- ":" / [A-Z] / "_" / [a-z] / [\xC0-\xD6\xD8-\xF6]
    NameChar <- NameStartChar / "-" / "." / [0-9] / '\xB7'
    Name <~ NameStartChar (NameChar)*

    VariableReference <- S? '$' Name S?
    Literal <~  S? ( 
                quote (!quote .)* quote
            /   doublequote (!doublequote .)* doublequote
                ) S?
    Number  <~  S? (
                '.' digits
            /   digits ('.' digits?)?
                ) S?


    S   <-  (' ' / '\t' / '\n' / '\r')+
`));


unittest
{
    immutable arr = [
        "/nodetest['predicate']",
        "//@attribute",
        "*[0]",
        "*[1 + 1]",
        "*[1 > 2]",
        "node()",
        "text()",
        "comment()",
        "processing-instruction()",
        "processing-instruction('pi')",
        "/ xpath / allow //  spaces / . / .. / node ( ) / * [0 + 1 mod 3 ] / child :: c / @ even-in-attrs "
    ];
    foreach (a; arr)
        parseXPath(a);
}

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