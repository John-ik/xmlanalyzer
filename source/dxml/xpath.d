module dxml.xpath;

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
import dxml.dom;
import dxml.xpath_grammar;


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



public static import std.sumtype;
alias match = std.sumtype.match;
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
            alias TypeFromAxes = DOMEntity!R.Attribute;
        else static if (axis == Axes.namespace)
            alias TypeFromAxes = R;
        else
            alias TypeFromAxes = DOMEntity!R;
    }
    
    alias Expr = std.sumtype.SumType!(
        R, /// namespace or (text for [somenode="text content this node"])
        DOMEntity!R.Attribute, /// attribute
        DOMEntity!R, /// node of DOM
    );
    
    private Set!Expr toExprSet (T)(Set!T set)
    {
        typeof(return) result;
        foreach (e; set)
            result ~= Expr(e);
        return result;
    }

    private DOMEntity!(R)[] stack;
    private DOMEntity!R parent() {
        // scope(exit) stack = stack[0..$-1];
        return stack[$-1];
    }
    private void push(DOMEntity!R value) { stack ~= value; }


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


    Set!(DOMEntity!R.Attribute) stepAttribute (DOMEntity!R node, ParseTree path)
    in(path.name == grammarName~".Step")
    {
        typeof(return) set;
        info(node);
        with (EntityType)
            // http://jmdavisprog.com/docs/dxml/0.4.4/dxml_dom.html#.DOMEntity.attributes
            if (canFind([elementStart, elementEmpty], node.type()) == false)
                return set;

        ParseTree nodeTest = find(path, grammarName~".NodeTest");
        
        if (nodeTest.children[0].name == grammarName~".TypeTest")
            return set;

        foreach(DOMEntity!R.Attribute attr; node.attributes())
        {
            if (nodeTest.matches[0] == "*" || attr.name == nodeTest.matches[0])
                set ~= attr;
        }
        infof("WHY? %s", set);
        // Какие нафиг предикаты для аттрибутов или их контекстов. ХЗ
        return set;
    }

    Set!(DOMEntity!R) stepNode (DOMEntity!R node, ParseTree path)
    in(path.name == grammarName~".Step")
    {
        Set!(DOMEntity!R) set;
        if (path.matches[0] == ".") 
            set ~= node;
        else if (path.matches[0] == "..")
        {
            set ~= parent(); stack = stack[0..$-1];
        }
        else
        {
            if (node.type() != EntityType.elementStart) return set;
            ParseTree nodeTest = find(path, grammarName~".NodeTest");
            foreach (DOMEntity!R child; node.children())
            {
                final switch (nodeTest.children[0].name)
                {
                case grammarName~".NameTest":
                    with (EntityType)
                        if (child.type() !in [elementStart:0, elementEnd:0, elementEmpty:0, pi:0])
                            continue;
                    if (nodeTest.matches[0] == "*" || child.name() == nodeTest.matches[0])
                        set ~= child;
                    break;
                case grammarName~".TypeTest":
                    with (EntityType) final switch (nodeTest.children[0].matches[0])
                    {
                    case "processing-instruction":
                        if (child.type() == pi) set ~= child; break;
                    case "comment":
                        if (child.type() == comment) set ~= child; break;
                    case "text":
                        if (child.type() == text) set ~= child; break;
                    case "node":
                        set ~= child; break;
                    }

                    break;
                }
            }
        }
        // для предикатов
        return set;
    }


    Set!(Expr) xpath (DOMEntity!R node, ParseTree path)
    {
        typeof(return) set;
        debug { import std.stdio : writefln; try { writefln("\n\t%s\t%s\n%s", node.name(), stack.length ? stack[$-1].name() : "", path); } catch (Error) {} }
        
        switch (path.name)
        {
        case grammarName:
            return xpath(node, path.children[0]);
        case grammarName~".LocationPath":
            return xpath(node, path.children[0]);
        case grammarName~".AbsoluteLocationPath":
            push(node);
            return xpath(node, path.children[0]);
        case grammarName~".AbbreviatedAbsoluteLocationPath":
            push(node);
            return xpath(getByAxis!(Axes.descendant_or_self)(node), path.children[0]);
        case grammarName~".RelativeLocationPath":
            push(node);
            ParseTree steper = path.find(grammarName~".Step");
            if (path.matches.length > 1 && path.matches[1] == "//")
                return xpath(stepNode(node, steper).getByAxis!(Axes.descendant_or_self)(), path.children[$-1]);
            else
            {
                if (path.children.length > 1)
                    return xpath(stepNode(node, steper), path.children[$-1]);
                return xpath(node, path.children[$-1]);
            }
        case grammarName~".Step":
            Axes resultAxis = getAxis(path);
            info(resultAxis);
            if (resultAxis == Axes.namespace)
                return cast(noreturn) assert(1); //TODO: IMPL
            if (resultAxis == Axes.attribute)
                return toExprSet(stepAttribute(node, path));
            return toExprSet(stepNode(node, path)); 
        default:
            debug error(path.name);
            return set;
        }
        
        return set;
    }

    Set!(Expr) xpath (Set!(DOMEntity!R) nodes, ParseTree path)
    {
        typeof(return) set;
        foreach (node; nodes[])
        {
            set ~= xpath(node, path);
        }
        return set;
    }


    // getter for all axis (node type)
    /// Для множества как параметра
    Set!(DOMEntity!R) getByAxis(Axes axis) (Set!(DOMEntity!R) set)
    {
        typeof(return) result;
        foreach (node; set)
            result ~= getByAxis!(axis)(node);
        return result;
    }
    /// Весь стек кроме текущего элемента.
    Set!(DOMEntity!R) getByAxis(Axes axis : Axes.ancestor)(DOMEntity!R node) => stack - node;
    /// Весь стек и текущий элемент. Возможно он уже включен
    Set!(DOMEntity!R) getByAxis(Axes axis : Axes.ancestor_or_self)(DOMEntity!R node) => stack ~ node;
    /// Просто дети
    Set!(DOMEntity!R) getByAxis(Axes axis : Axes.child)(DOMEntity!R node) => typeof(this)(node.children());
    /// Все потомки
    Set!(DOMEntity!R) getByAxis(Axes axis : Axes.descendant)(DOMEntity!R node)
    {
        typeof(return) result;
        if (node.type() != EntityType.elementStart) return result;
        foreach (child; node.children())
            result ~= getByAxis!(Axes.descendant_or_self)(child);
        return result;
    }
    /// Все потомки и текущий элемент
    Set!(DOMEntity!R) getByAxis(Axes axis : Axes.descendant_or_self)(DOMEntity!R node)
    {
        typeof(return) result;
        result ~= node;
        if (node.type() != EntityType.elementStart) return result;
        foreach (child; node.children())
            result ~= getByAxis!(Axes.descendant_or_self)(child);
        return result;
    }
    /// Родитель
    Set!(DOMEntity!R) getByAxis(Axes axis : Axes.parent)(DOMEntity!R node)
    out(res; node in getByAxis!(Axes.child)(res))
    {
        return typeof(stack[$-1]);
    }
    /// Текущий элеметн
    Set!(DOMEntity!R) getByAxis(Axes axis : Axes.self)(DOMEntity!R node) => typeof(this)(node);
}


import std.exception : basicExceptionCtors;

class PathException : Exception
{
    ///
    mixin basicExceptionCtors;
}

class TypeException : Exception
{
    import std.algorithm : joiner;
    import std.conv : text;
    import dxml.dom;
    this(R)(DOMEntity!R entity, string file = __FILE__, size_t line = __LINE__) {
        super(text(i"This must be started element. /$(entity.path.joiner(`/`))/<$(entity.name)>; $(entity.type)"), file, line);
    }
}

