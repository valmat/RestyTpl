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

import std.file    : rename, mkdir;
import std.path    : dirName;
import std.process : thisProcessID, thisThreadID;
import std.traits  : isIntegral, isSomeChar;

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
    void dump(string fileName)
    {
        fileName.dirName().mkdir();
        return _view.dump(fileName);
    }    
    void dump_atomic(string fileName)
    {
        const(char)[] tmp_name;
        tmp_name.reserve(fileName.length + 16);
        tmp_name = fileName ~ '.' ~ threadHash() ~ ".tmp";
        _view.dump(cast(string)tmp_name);
        rename(tmp_name, fileName);
    }    
}

private:

const(char)[11] threadHash() nothrow
{
    size_t procID  = thisProcessID();
    size_t thrdID  = thisThreadID();
    return fastHash( size_t.max ^ ((procID << 46) | thrdID) );
}

const(char)[11] fastHash(size_t val) @nogc pure nothrow
{
    char[11] res;
    enum size_t one = size_t.max >> 58;
    foreach(size_t i; 0 .. 11) {
        size_t shift = i * 6;
        size_t index = ((one << shift) & val) >> shift;
        res[i] = index._i2c();
    }
    return res;
}

char _i2c(T)(T c) nothrow pure @nogc
    if(isIntegral!T || isSomeChar!T)
{
    switch(c) {
        case 0: return '-';

        case 1: .. case 10:
            return cast(char)(c + 48 - 1);

        case 11: .. case 36:
            return cast(char)(c - 10 + 65 - 1);

        case 37: .. case 62:
            return cast(char)(c - 36 + 97 - 1);

        case 63: return '~';
        default: return 0;
    }
}