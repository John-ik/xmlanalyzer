module xpath;



debug import  std.logger;

import std.algorithm : canFind;
import std.algorithm : map;
import std.meta : staticIndexOf;

@safe
struct ExactPath
{
    bool empty () const => _path.length == 0;
    ushort front () const => _path[0];
    void popFront() {
        _path = _path[1..$];
    }
    size_t length () const => _path.length;
    string toString() const @safe pure
    {
        import std.conv;
        return text(_path);
    }

    this (ushort[] path)
    {
        _path = path;
    }
    
    private:
        ushort[] _path;
}

import set;
import xmldom;
import xpath_grammar;


enum Axes {
    ancestor,
    ancestor_or_self,
    attribute,          // Attribute
    child,
    descendant,
    descendant_or_self,
    following,
    following_sibling,
    namespace,          // Name - string
    parent,
    preceding,
    preceding_sibling,
    self
}

Axes getAxis (ParseTree path)
in(path.name == grammarName~".Step")
{
    if (path.matches[0] == ".")
        return Axes.self;
    if (path.matches[0] == "..")
        return Axes.parent;
    
    ParseTree axisSpecifier = path.find(grammarName~".AxisSpecifier");
    if (axisSpecifier == axisSpecifier.init)
        return Axes.child;
    if (axisSpecifier.matches[0] == "@")
        return Axes.attribute;
    
    with(Axes) final switch ( axisSpecifier.matches[0] )
    {
    case "ancestor-or-self": return ancestor_or_self;
    case "ancestor": return ancestor;
    case "attribute": return attribute;
    case "child": return child;
    case "descendant-or-self": return descendant_or_self;
    case "descendant": return descendant;
    case "following-sibling": return following_sibling;
    case "following": return following;
    case "namespace": return namespace;
    case "parent": return parent;
    case "preceding-sibling": return preceding_sibling;
    case "preceding": return preceding;
    case "self": return self;
    }
}


// getter for all axis (node type)
/// Для множества как параметра
Set!(XMLNode!R) getByAxis (R) (Set!(XMLNode!R) set, Axes axis)
{
    typeof(return) result;
    foreach (node; set)
        result ~= getByAxis(node, axis);
    return result;
}
/// Для одного узла
Set!(XMLNode!R) getByAxis (R) (XMLNode!R node, Axes axis)
{
    typeof(return) result;
    final switch (axis)
    {
    case Axes.ancestor_or_self: 
        result ~= node;
        goto case;
    case Axes.ancestor:
        if (node.type() == EntityType.elementStart && node.name() == "") 
            return result; // Если элемент корневой
        return result ~ getByAxis(node, Axes.parent).getByAxis(Axes.ancestor_or_self);
    case Axes.attribute: return assert(0);
    case Axes.child:
        if (node.type() != EntityType.elementStart) return result;
        return typeof(return)(node.children());
    case Axes.descendant_or_self:
        result ~= node;
        goto case;
    case Axes.descendant:
        if (node.type() != EntityType.elementStart) return result;
        return result ~ getByAxis(node, Axes.child).getByAxis(Axes.descendant_or_self);
    case Axes.following:
    case Axes.following_sibling:
        return assert(0); //TODO: IMPL
    case Axes.namespace:
        return assert(0);
    case Axes.parent: 
        assert(canFind(node.parent().children(), node));
        return typeof(return)(node.parent());
    case Axes.preceding:
    case Axes.preceding_sibling:
        return assert(0); //TODO: IMPL
    case Axes.self: return typeof(return)(node);
    }
}


/// Выполнение проверок nodeTest и Predicates  
/// Дочерние элементы не берутся. Проверяются только nodes
Set!(XMLNode!S) stepNode (S) (Set!(XMLNode!S) nodes, ParseTree path) @safe
in(path.name == grammarName~".Step")
{
    Set!(XMLNode!S) set;
    if (path.matches[0] == ".") 
        set = nodes;
    else if (path.matches[0] == "..")
    {
        set = nodes; // Дочерние элементы не беруться. Родитель уже взят осью в xpath case
    }
    else
    {
        ParseTree nodeTest = find(path, grammarName~".NodeTest");
        foreach (XMLNode!S node; nodes)
        {
            final switch (nodeTest.children[0].name)
            {
            case grammarName~".NameTest":
                with (EntityType)
                    if (node.type() !in [elementStart:0, elementEmpty:0])
                        continue;
                if (nodeTest.matches[0] == "*" || node.name() == nodeTest.matches[0])
                    set ~= node;
                break;
            case grammarName~".TypeTest":
                with (EntityType) final switch (nodeTest.children[0].matches[0])
                {
                case "processing-instruction":
                    if (node.type() == pi) set ~= node; break;
                case "comment":
                    if (node.type() == comment) set ~= node; break;
                case "text":
                    if (node.type() == text) set ~= node; break;
                case "node":
                    set ~= node; break;
                }

                break;
            case grammarName~".PiTest":
                ParseTree piTest = find(nodeTest, grammarName~".PiTest");
                if (node.type() == EntityType.pi && node.name() == piTest.children[0].matches[0][1..$-1])
                    set ~= node;
                break;
            }
        }
    }
    // для предикатов
    return set;
}
///Ditto
Set!(XMLNode!S) stepNode (S) (XMLNode!S node, ParseTree path) => stepNode(Set!(XMLNode)(node), path);

/// Ось атрибутов здесь  
/// Также и проверка
Set!(XMLNode!S.Attribute) stepAttribute (S)(XMLNode!S node, ParseTree path) @safe
in(path.name == grammarName~".Step")
{
    typeof(return) set;
    with (EntityType)
        // http://jmdavisprog.com/docs/dxml/0.4.4/dxml_dom.html#.DOMEntity.attributes
        if (canFind([elementStart, elementEmpty], node.type()) == false)
            return set;

    ParseTree nodeTest = find(path, grammarName~".NodeTest");
    
    if (nodeTest.children[0].name == grammarName~".TypeTest")
        return set;

    foreach(XMLNode!S.Attribute attr; node.attributes())
    {
        if (nodeTest.matches[0] == "*" || attr.name == nodeTest.matches[0])
            set ~= attr;
    }
    // Какие предикаты для аттрибутов или их контекстов. ХЗ
    return set;
}


Set!(XMLNode!S) procPredicate (S) (Set!(XMLNode!S) nodes, ParseTree predicate) @safe
in(path.name == grammarName~".Predicate")
{

}


immutable Composition = "Composition";
/++
Check if ParseTree is composition element (someone element in tree has more then 1 children)
Params:
    
Return: 
Date: Aug 18, 2024
+/
string checkComposotionElem(ParseTree p) @safe pure @nogc nothrow
{
    if (p.children.length == 0) return p.name;
    //TODO: if called func
    if (p.children.length > 1) return Composition;
    return checkComposotionElem(p[0]);
}


ExprTypes getExprType (ParseTree expr) @safe
{
    string of (string name) => grammarName~"."~name;

    with (ExprTypes)
    final switch (expr.name)
    {
    case of("Expr"): return getExprType(expr[0]);
    case of("OrExpr"), of("AndExpr"), of("EqualityExpr"), of("RelationalExpr"):
        return expr.children.length == 1 ? getExprType(expr[0]) : boolean;
    case of("AdditiveExpr"), of("MultiplicativeExpr"):
        return expr.children.length == 1 ? getExprType(expr[0]) : number;
    case of("UnaryExpr"):
        return expr.matches[0] == "-" ? number : getExprType(expr[0]);
    case of("UnionExpr"):
        return expr.children.length == 1 ? getExprType(expr[0]) : nodeset;
    }
    assert(0);
}

/// All types of Expr in XPath
enum ExprTypes {
    undefined,
    nodeset,
    attrset,
    strset,
    boolean,
    number,
    str
}



struct Result (S)
{
    import std.sumtype;
    alias Expr = SumType!(
        EmptyType, /// Empty type
        Set!(XMLNode!S), /// node-set
        Set!(XMLNode!S.Attribute), /// set of attributes
        Set!S,  /// set of texts or namespaces
        bool,   /// boolean as result of XPathExpresion
        double, /// number
        S       /// string
    );
    Expr result;
    alias result this;

    /// Construct from any supported type
    this (T) (T value)
    {
        result = Expr(value);
    }

    /++ 
    Run-time. Get `ExprTypes` of type
    
    | Type              | Return |
    |:------------------|----------:|
    | `Set!(XMLNode!S)` | nodeset  |
    | `Set!(XMLNode!S.Attribute)` | attrset |
    | `Set!S` | strset |
    | `bool` | boolenan |
    | `double` | number |
    | `S` | str |
    | `EmptyType` | undefined |
    ++/
    ExprTypes getType ()
    {
        with (ExprTypes)
        return result.match!(
            (EmptyType _) => undefined,
            (Set!(XMLNode!S) _) => nodeset,
            (Set!(XMLNode!S.Attribute) _) => attrset,
            (Set!S _) => strset,
            (bool _) => boolean,
            (double _) => number,
            (S _) => str
        );
    }

    /// Casting to needed type
    /// Throws: `MatchException` on wrong type
    T to (T) () @safe
    {
        try 
            return result.tryMatch!((T t) => t);
        catch (MatchException e)
        {
            errorf("Result is %s tried cast to %s", getType(), T.stringof);
            throw e;
        }
    }
    alias toNodes  = to!(Set!(XMLNode!S));
    alias toAttrs  = to!(Set!(XMLNode!S.Attribute));
    alias toTexts  = to!(Set!S);
    alias toBool   = to!(bool);
    alias toNumber = to!(double);
    alias toStr    = to!(S);

    /++
    Concat sets 'a' and 'b'
    
    Conditions:
    - Both are sets (`Set!S` or `Set!(XMLNode!S)` or `Set!(XMLNode!S.Attribute)`)  
    - Identical types or a is `EmptyType`

    Throws: `MatchException` if conditions false
    ++/
    auto opBinary(string op : "~")(Result!S operand)
    {
        alias doMatch = tryMatch!(
            (EmptyType a, b) => Result(b),
            (a, EmptyType b) => Result(a),
            (Set!S a, Set!S b) => Result(a ~ b),
            (Set!(XMLNode!S) a, Set!(XMLNode!S) b) => Result(a ~ b),
            (Set!(XMLNode!S.Attribute) a, Set!(XMLNode!S.Attribute) b) => Result(a ~ b),
        );
        return doMatch(this, operand);
    }

    auto opOpAssign (string op : "~")(Result!S operand)
    {
        this.result = this ~ operand;
        return this;
    }

    /// Result hold this type if its empty
    private
    enum EmptyType {
        a = 0
    }
}


unittest 
{
    Result!string r;

    assert(r.getType() == ExprTypes.undefined);
}



import std.exception : basicExceptionCtors;

class PathException : Exception
{
    ///
    mixin basicExceptionCtors;
}

class TypePathException : Exception
{
    import std.algorithm : joiner;
    import std.conv : text;
    import std.format;
    import dxml.dom;
    this(R)(XMLNode!R entity, string file = __FILE__, size_t line = __LINE__) {
        super(format("This must be started element. /%s/<%s>; %s", entity.path.joiner(`/`), entity.name, entity.type),
                file, line);
    }
}

class DifferentResultTypeException : Exception
{
    ///
    mixin basicExceptionCtors;
}

