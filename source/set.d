module set;

import std.container.rbtree;
import std.datetime.date;

struct Set (T)
{
    deprecated alias ZeroUnit = void[];
    deprecated enum zeroUnit = ZeroUnit.init;
    T[] _payload;
    alias _payload this;

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
        if (value in this)
            return this;
        _payload ~= value;
        return this;
    }

    auto opOpAssign(string op: "~")(Set!T values)
    {
        foreach (val; values[])
            this ~= val;
        return this;
    }

    auto opBinaryRight(string op : "in", R : T)(const R lhs) const
    {
        import std.algorithm : find;
        return find(_payload, lhs);
    }

    auto opBinary(string op : "~", R : T)(const R rhs) const => Set(_payload ~ rhs);
    auto opBinaryRight(string op : "~", R : T)(const R lhs) const => Set(lhs ~ _payload);

    auto opBinary(string op : "-", R : T)(const R rhs) const
    {
        typeof(this) result;
        foreach (T val; _payload)
            if (val != rhs)
                result ~= val;
        return result;
    }
    auto opBinary(string op, R : typeof(this))(const R rhs) const
    {
        typeof(this) result;
        foreach (T l; _payload)
            foreach (T r; rhs)
                if (l != r)
                    result ~= l;
        return result;
    }
    auto opBinaryRight(string op, L : typeof(this))(const L lhs) const
    {
        typeof(this) result;
        foreach (T r; _payload)
            foreach (T l; lhs)
                if (l != r)
                    result ~= l;
        return result;
    }
}