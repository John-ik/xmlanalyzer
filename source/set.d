module set;

@safe:

import std.container.rbtree;
import std.datetime.date;

struct Set (T)
{
    T[] _payload;

    T[] data () => _payload;

    auto ref T front () => _payload[0];
    void popFront()
    {
        _payload = _payload[1..$];
    }
    bool empty () const => _payload.length == 0;
    size_t length () const => _payload.length;

    this (T value)
    {
        this ~= value;
    }

    this (R)(R range)
    {
        foreach (T value; range)
            _payload ~= value;
    }


    auto opOpAssign(string op: "~")(T value)
    {
        import std.algorithm : canFind;
        if (canFind(_payload, value))
            return this;
        _payload ~= value;
        return this;
    }

    auto opOpAssign(string op: "~")(Set!T values)
    {
        foreach (val; values)
            this ~= val;
        return this;
    }

    deprecated /// До лучших времен
    auto opBinaryRight(string op : "in", R : T)(const R lhs) const
    {
        import std.algorithm : find;
        return find(_payload, lhs);
    }

    auto opBinary(string op : "~", R : T)(R rhs) => Set(_payload ~ rhs);
    auto opBinaryRight(string op : "~", R : T)(R lhs) => Set(lhs ~ _payload);
    auto opBinary(string op : "~", R : T)(Set!R rhs)
    {
        Set!T result;
        result ~= this;
        result ~= rhs;
        return result;
    }

    auto opBinary(string op : "-", R : T)(const R rhs)
    {
        Set!T result;
        foreach (T val; _payload)
            if (val != rhs)
                result ~= val;
        return result;
    }
    auto opBinary(string op : "-", R : typeof(this))(R rhs)
    {
        Set!T result;
        foreach (T l; _payload)
            foreach (T r; rhs)
                if (l != r)
                    result ~= l;
        return result;
    }
    auto opBinaryRight(string op : "-", L : typeof(this))(L lhs)
    {
        Set!T result;
        foreach (T r; _payload)
            foreach (T l; lhs)
                if (l != r)
                    result ~= l;
        return result;
    }

    bool opCast(T : bool)() const => !this.empty;
}