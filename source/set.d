module set;

import std.container.rbtree;

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
        foreach (val; values[])
        {
            this ~= val;
        }
        return this;
    }
}