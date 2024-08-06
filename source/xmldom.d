module xmldom;

// std
import std.algorithm : map, canFind;
import std.array : array;
import std.range : only;
import std.format : format;
import std.typecons : Tuple;


// dxml
import dxml.dom;
import dxml.parser;

// local
import xpath;

public import dxml.parser : EntityType;


struct TextPos2
{
    int opCmp(const TextPos2 other) const @safe pure nothrow @nogc
    {
        if (this.line < other.line) return -1;
        if (this.line > other.line) return 1;
        if (this.col < other.col) return -1;
        if (this.col == other.col) return 0;
        if (this.col > other.col) return 1;
        assert(0);
    }

    this (TextPos pos) @safe pure nothrow
    {
        this._pos = pos;
    }

    this (int line, int col) @safe pure nothrow
    {
        _pos.line = line;
        _pos.col = col;
    }

    TextPos _pos;
    alias _pos this;
}


class XMLNode (S)
{
    alias Attribute = Tuple!(S, "name", S, "value", TextPos2, "pos");

    static
    Attribute toAttribute (DOMEntity!S.Attribute oldAttribute) @safe pure nothrow
    {
        return Attribute(oldAttribute.name, oldAttribute.value, TextPos2(oldAttribute.pos));
    }


    this (DOMEntity!S dom, XMLNode parent = null) @safe
    {
        _type = dom.type();
        _pos = TextPos2(dom.pos());
        _path = dom.path();
        _parent = parent;
        with (EntityType)
        {
            import std : only, canFind;
            if (only(elementStart, elementEnd, elementEmpty, pi).canFind(_type))
                _name = dom.name();
            if (only(elementStart, elementEmpty).canFind(_type))
                _attributes = dom.attributes().map!(toAttribute).array;
            if (only(cdata, comment, pi, text).canFind(_type))
                _text = dom.text();
            if (elementStart == _type)
                foreach (child; dom.children())
                    _children ~= new XMLNode(child, this);
        }
    }


    bool empty () @safe nothrow @nogc
    {
        return _name == "" && _path.length == 0 && _text == "" && _children.length == 0;
    }


    XMLNode get (ExactPath path) @safe
    {
        if (path.length == 1) return this.get(path.front());
        if (path.empty) return this;
        if (this._type != EntityType.elementStart) throw new TypePathException(this);
        ushort index = path.front(); path.popFront();
        return this.get(index).get(path);
    }

    XMLNode get (ushort path) @safe
    {
        if (this.type() != EntityType.elementStart) throw new TypePathException(this);
        if (path >= this.children().length) 
            throw new PathException(format("This length %d less then index %d", this.children().length, path));
        return this.children()[path];
    }

    auto get (string xpath) @safe
    {
        import xpath_grammar;
        ParseTree path = parseXPath(xpath);
        return process!string.xpath(this, path);
    }

    auto opIndex (T) (T path) => this.get(path);


    bool opEquals (const XMLNode o) const @safe
    {
        return this._attributes == o._attributes && this._children is o._children 
                && this._name == o._name && this._parent is o._parent && this._path is o._path
                && this._pos == o._pos && this._text == o._text && this._type == o._type;
    }

    /// Compare XMLNode equals compare their position
    int opCmp (const XMLNode other) const @safe => this.pos().opCmp(other.pos());


    EntityType type() const @safe nothrow @nogc => _type;
    TextPos2 pos() const @safe nothrow @nogc => _pos;
    S[] path() @safe nothrow @nogc => _path;
    ref S name() @safe
    {
        with(EntityType)
        {
            import std.format : format;
            assert(only(elementStart, elementEnd, elementEmpty, pi).canFind(_type),
                    format("name cannot be called with %s", _type));
        }
        return _name;
    }
    ref Attribute[] attributes() @safe
    {
        with(EntityType)
        {
            import std.format : format;
            assert(_type == elementStart || _type == elementEmpty,
                    format("attributes cannot be called with %s", _type));
        }
        return _attributes;
    }
    ref S text() @safe
    {
        with(EntityType)
        {
            import std.format : format;
            assert(only(cdata, comment, pi, text).canFind(_type),
                    format("text cannot be called with %s", _type));
        }
        return _text;
    }
    ref XMLNode[] children() @safe
    {
        import std.format : format;
        assert(_type == EntityType.elementStart,
                format("children cannot be called with %s", _type));
        return _children;
    }
    XMLNode parent() @safe @nogc => _parent;


private:

    EntityType _type;
    TextPos2 _pos;
    S _name;
    S[] _path;
    Attribute[] _attributes;
    S _text;
    XMLNode[] _children;
    XMLNode _parent;
}


XMLNode!S parseDOM (S) (S xmlText) @safe
{
    return new XMLNode!S(dxml.dom.parseDOM(xmlText));
}