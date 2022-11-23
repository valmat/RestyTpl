module resty.view;

import std.conv   : to;
import std.stdio;
import std.range;
import std.algorithm;
import std.array;
import std.typecons;
import std.string;
import std.traits;
import std.math;

import luad.all;
import luad.lmodule;
import luad.lfunction;
import luad.conversions.functions;

struct View
{
private:
    LuaFunction _view;
public:
    this(LuaFunction view) //nothrow
    {
        _view = view;
    }

    string opCall(Args...)(Args args)
    {
        return _view.call!string(args);
    }
    alias call = opCall;

    auto dump(Args...)(Args args)
    {
        return _view.dump(args);
    }
}