module xpath;

@safe:

debug import  std.logger;

import std.algorithm : canFind;
import std.algorithm : map;
import std.meta : staticIndexOf;

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



public import std.sumtype;
/++
Implementation for xpath finder.

Implemented
- NodeTest for 
    + type: pi, comment, node, text
    + name, * - match any name of tag
- absolute path child by child

Date: Jun 19, 2024
+/
template process (R)
{
    template TypeFromAxes(Axes axis)
    {
        static if (axis == Axes.attribute)
            alias TypeFromAxes = XMLNode!R.Attribute;
        else static if (axis == Axes.namespace)
            alias TypeFromAxes = R;
        else
            alias TypeFromAxes = XMLNode!R;
    }
    
    alias Expr = std.sumtype.SumType!(
        R, /// namespace or (text for [somenode="text content this node"])
        XMLNode!R.Attribute, /// attribute
        XMLNode!R, /// node of DOM
    );
    

    Set!T to (T) (Set!Expr set)
    {
        typeof(return) result;
        foreach (e; set)
            result ~= e.tryMatch!( (T t) => t );
        return result;
    }
    alias toAttrs = to!(XMLNode!R.Attribute);
    alias toNodes = to!(XMLNode!R);
    alias toTexts = to!(R);

    private Set!Expr toExprSet (T)(Set!T set)
    {
        typeof(return) result;
        foreach (e; set)
            result ~= Expr(e);
        return result;
    }

    deprecated
    private XMLNode!(R)[] stack;
    deprecated    private XMLNode!R parent() {
        // scope(exit) stack = stack[0..$-1];
        return stack[$-1];
    }
    deprecated
    private void push(XMLNode!R value) { stack ~= value; }


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

    /// Ось атрибутов здесь  
    /// Также и проверка
    Set!(XMLNode!R.Attribute) stepAttribute (XMLNode!R node, ParseTree path)
    in(path.name == grammarName~".Step")
    {
        typeof(return) set;
        with (EntityType)
            // http://jmdavisprog.com/docs/dxml/0.4.4/dxml_dom.html#.XMLNode.attributes
            if (canFind([elementStart, elementEmpty], node.type()) == false)
                return set;

        ParseTree nodeTest = find(path, grammarName~".NodeTest");
        
        if (nodeTest.children[0].name == grammarName~".TypeTest")
            return set;

        foreach(XMLNode!R.Attribute attr; node.attributes())
        {
            if (nodeTest.matches[0] == "*" || attr.name == nodeTest.matches[0])
                set ~= attr;
        }
        // Какие нафиг предикаты для аттрибутов или их контекстов. ХЗ
        return set;
    }

    /// Выполнение проверок nodeTest и Predicates  
    /// Дочерние элементы не берутся. Проверяются только nodes
    Set!(XMLNode!R) stepNode (Set!(XMLNode!R) nodes, ParseTree path)
    in(path.name == grammarName~".Step")
    {
        Set!(XMLNode!R) set;
        if (path.matches[0] == ".") 
            set = nodes;
        else if (path.matches[0] == "..")
        {
            set = nodes; // Дочерние элементы не беруться. Родитель уже взят осью в xpath case
        }
        else
        {
            ParseTree nodeTest = find(path, grammarName~".NodeTest");
            foreach (XMLNode!R node; nodes)
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
    Set!(XMLNode!R) stepNode (XMLNode!R node, ParseTree path) => stepNode(Set!(XMLNode!R)(node), path);



    Set!(Expr) xpath (XMLNode!R node, ParseTree path)
    {
        typeof(return) set;
        // debug { import std.stdio : writefln; try { writefln("\n\t%s\n%s", node.name(), path); } catch (Error) {} }
        
        switch (path.name)
        {
        case grammarName:
            return xpath(node, path.children[0]);
        case grammarName~".XPath":
            return xpath(node, path.children[0]);
        case grammarName~".Expr":
            return xpath(node, path.children[0]);
        case grammarName~".OrExpr":
            //TODO:
            return xpath(node, path.children[0]);
        case grammarName~".UnionExpr":
            if (path.children.length == 2)
                return xpath(node, path.children[0]) ~ xpath(node, path.children[1]);
            return xpath(node, path.children[0]);
        case grammarName~".PathExpr":
            return xpath(node, path.children[0]);
        case grammarName~".LocationPath":
            return xpath(node, path.children[0]);
        case grammarName~".AbsoluteLocationPath":
            return xpath(node, path.children[0]);
        case grammarName~".AbbreviatedAbsoluteLocationPath":
            return xpath(getByAxis(node, Axes.descendant_or_self), path.children[0]);
        case grammarName~".RelativeLocationPath":
            if (path.children.length > 1)
            {
                ParseTree steper = path.find(grammarName~".Step");
                // info(getAxis(steper));
                auto byAxis = getByAxis(node, getAxis(steper));
                // infof("%(>- %s\v\n%)", byAxis);
                auto byStep = stepNode(byAxis, steper);
                // infof("%(>- %s\v\n%)", byStep);
                if (path.matches[1] == "//")
                    byStep = byStep.getByAxis(Axes.descendant_or_self);
                // infof("%(>- %s\v\n%)", byStep);
                return xpath(byStep, path.children[$-1]);
            }
            return xpath(node, path.children[$-1]); // goto last step
        case grammarName~".Step":
            Axes resultAxis = getAxis(path);
            if (resultAxis == Axes.namespace)
                return assert(0); //TODO: IMPL
            if (resultAxis == Axes.attribute)
                return toExprSet(stepAttribute(node, path));
            return node.getByAxis(resultAxis).stepNode(path).toExprSet();
        default:
            debug error(path);
            return set;
        }
        
        return set;
    }

    Set!(Expr) xpath (Set!(XMLNode!R) nodes, ParseTree path)
    {
        typeof(return) set;
        foreach (node; nodes)
        {
            set ~= xpath(node, path);
        }
        return set;
    }


    // getter for all axis (node type)
    /// Для множества как параметра
    Set!(XMLNode!R) getByAxis(Set!(XMLNode!R) set, Axes axis)
    {
        typeof(return) result;
        foreach (node; set)
            result ~= getByAxis(node, axis);
        return result;
    }
    /// Для одного узла
    Set!(XMLNode!R) getByAxis(XMLNode!R node, Axes axis)
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
    // Set!(XMLNode!R) getByAxis(Axes axis : Axes.ancestor)(XMLNode!R node) => stack - node;
    // /// Весь стек и текущий элемент. Возможно он уже включен
    // Set!(XMLNode!R) getByAxis(Axes axis : Axes.ancestor_or_self)(XMLNode!R node) => stack ~ node;
    // /// Просто дети
    // Set!(XMLNode!R) getByAxis(Axes axis : Axes.child)(XMLNode!R node) => typeof(this)(node.children());
    // /// Все потомки
    // Set!(XMLNode!R) getByAxis(Axes axis : Axes.descendant)(XMLNode!R node)
    // {
    //     typeof(return) result;
    //     if (node.type() != EntityType.elementStart) return result;
    //     foreach (child; node.children())
    //         result ~= getByAxis!(Axes.descendant_or_self)(child);
    //     return result;
    // }
    // /// Все потомки и текущий элемент
    // Set!(XMLNode!R) getByAxis(Axes axis : Axes.descendant_or_self)(XMLNode!R node)
    // {
    //     typeof(return) result;
    //     result ~= node;
    //     if (node.type() != EntityType.elementStart) return result;
    //     foreach (child; node.children())
    //         result ~= getByAxis!(Axes.descendant_or_self)(child);
    //     return result;
    // }
    // /// Родитель
    // Set!(XMLNode!R) getByAxis(Axes axis : Axes.parent)(XMLNode!R node)
    // out(res; node in getByAxis!(Axes.child)(res))
    // {
    //     return typeof(stack[$-1]);
    // }
    // /// Текущий элеметн
    // Set!(XMLNode!R) getByAxis(Axes axis : Axes.self)(XMLNode!R node) => typeof(this)(node);
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

