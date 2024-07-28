module xmldom;

import dxml.dom;
import dxml.parser;
import xpath;


struct TextPos2 
{
    int opCmp(const TextPos2 other) const
    {
        if (this.line < other.line) return -1;
        if (this.line > other.line) return 1;
        if (this.col < other.col) return -1;
        if (this.col == other.col) return 0;
        if (this.col > other.col) return 1;
        assert(0);
    }

    this (TextPos pos)
    {
        this._pos = pos;
    }

    TextPos _pos;
    alias _pos this;
}

class XMLNode (S)
{
    alias Attribute = DOMEntity!S.Attribute;


    this (DOMEntity!S dom, XMLNode parent = null)
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
                _attributes = dom.attributes();
            if (only(cdata, comment, pi, text).canFind(_type))
                _text = dom.text();
            if (elementEmpty == _type)
                foreach (child; dom.children())
                    _children ~= XMLNode(child, this);
        }
    }


    XMLNode get (ExactPath path)
    {

    }
    XMLNode get (ushort path)
    {
        
    }

    auto opIndex (T) (T path) => this.get(path);


    /// Compare XMLNode equals compare their position
    int opCmp (const XMLNode other) const => this.pos().opCmp(other.pos());


    EntityType type() const @safe pure nothrow @nogc => _type;
    TextPos2 pos() const @safe pure nothrow @nogc => _pos;
    S[] path() const @safe pure nothrow @nogc => _path;
    S name()
    {
        with(EntityType)
        {
            import std.format : format;
            assert(only(elementStart, elementEnd, elementEmpty, pi).canFind(_type),
                    format("name cannot be called with %s", _type));
        }
        return _name;
    }
    Attribute[] attributes()
    {
        with(EntityType)
        {
            import std.format : format;
            assert(_type == elementStart || _type == elementEmpty,
                    format("attributes cannot be called with %s", _type));
        }
        return _attributes;
    }
    S text()
    {
        with(EntityType)
        {
            import std.format : format;
            assert(only(cdata, comment, pi, text).canFind(_type),
                    format("text cannot be called with %s", _type));
        }
        return _text;
    }
    XMLNode[] children() 
    {
        import std.format : format;
        assert(_type == EntityType.elementStart,
                format("children cannot be called with %s", _type));
        return _children;
    }
    XMLNode parent() => _parent;


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