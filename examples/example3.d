#!/usr/bin/rdmd --shebang= -I./deps -I./submodules -I. -w -debug -L./deps/liblua.a -J.

import std.conv   : to;
import std.stdio;
import std.range;
import std.algorithm;
import std.array;
import std.typecons;
import std.string;
import std.traits;
import std.math;
import std.stdint;


import luad.all;
import luad.lmodule;

import std.stdio;
import std.stdio;
import std.file;


import luad.lfunction;
import luad.conversions.functions;

import resty;

import std.process : thisProcessID, thisThreadID;
import std.traits  : isIntegral, isSomeChar, isBoolean;
import std.meta    : allSatisfy;

void main()
{
    /*{
        RestyOptons opts;
        //opts.resty_lua_lib = "deps/resty.p.luac";

        auto tplEngn = new Resty(opts);
        string tpl = `<body>{{message}}</html>`;
        auto  data = ["message" : "Hello, World! outside"];

        auto view = tplEngn.compile(tpl);
        view.writeln;
        view(data).writeln;
        tplEngn.compileFile("1.tpl")(data).writeln;
        tplEngn.compileFile("1.tpl").call(data).writeln;

        

        struct DataMsg{string message;}
        view(DataMsg("ups1")).writeln;

        auto v2 = tplEngn.compile("1.tpl");
        v2(DataMsg("ups2")).writeln;

        //exists

        auto a = new A(42);
        auto b = new B(42);

        a.get().writeln;
        b.get().writeln;
    }*/
    {
        RestyOptons opts;
        // Do cache compiled templates
        opts.cache  = true;
        // If true, will precompile from tplDir and store to cplDir
        opts.precomple = true;
        // if true will check if file was changed and recompile if necessary
        opts.checkChanges = true;
        // if setted will add as prefix to filepath
        opts.tplDir = "tpls/tpls";
        // if setted and `precomple = true` will store precompiled files
        opts.cplDir = "tpls/cpls";
        // if setted will use this
        //opts.resty_lua_lib = "deps/resty.p.luac";

        auto tplEngn = new Resty(opts);

        struct DataMsg{string message;}
        
        tplEngn.compileFile("1.tpl").call(DataMsg("Tpl 1")).writeln;
        tplEngn.compileFile("l2/2.tpl")(DataMsg("Tpl 2")).writeln;


    }

    //{
    //    //writeln(tuple((new Pid(0, 1)).processID));
    //    writefln("Current process ID: %d, thisThreadID %d , %d", thisProcessID, thisThreadID, size_t.max);
        
    //    size_t procID = thisProcessID();
    //    size_t thrdID = thisThreadID();
    //    size_t procID1 = procID << 46;
    //    size_t thrHash = (procID << 46) | thrdID;
    //    size_t thrHash1 = size_t.max ^ thrHash;

    //    writeln("ProcessID   : ", procID.binstr() , "\t", procID, "\t");
    //    writeln("ProcessID1  : ", procID1.binstr() , "\t", procID1, "\t");
    //    writeln("ThreadID    : ", thrdID.binstr()  , "\t", thrdID,  "\t");
    //    writeln("thrHash     : ", thrHash.binstr()  , "\t", thrHash,  "\t");
    //    writeln("thrHash1    : ", thrHash1.binstr()  , "\t", thrHash1,  "\t");
    //    writeln("size_t.max  : ", size_t.max.binstr()    , "\t", size_t.max,    "\t");
    //    writeln("size_t(1)   : ", size_t(1).binstr()     , "\t", size_t(1),     "\t");

    //    fastHash(thrHash).writeln;
    //    fastHash(thrHash1).writeln;
        
    //    fastHash(size_t.max).writeln;

    //    //foreach(ubyte i; 0..64) {
    //    //    writeln(i, "\t", _i2c(i));
    //    //}

    //    threadHash().writeln;

    //    string fileName = "abcd.html";
    //    const(char)[] tmp_name;
    //    tmp_name.reserve(fileName.length + 16);
    //    //tmp_name
    //    //tmp_name = fileName ~ "." ~ threadHash() ~ ".tmp";
    //    tmp_name = fileName ~ '.' ~ threadHash() ~ ".tmp";

    //    tmp_name.writeln;
    //}

    //{
    //    writeln(0b00000111, "\t", 0b00000111.binstr());
    //    writeln(0b00000101, "\t", 0b00000101.binstr());
    //    writeln(0b00000100, "\t", 0b00000100.binstr());

    //    //pragma(msg, typeof(0b100));
    //    //pragma(msg, typeof(0b100).sizeof);

    //    codeBools(true, false, true, true).binstr.writeln;
    //    codeBools(true, true, true, true).binstr.writeln;
    //    codeBools(true, false, false, true).binstr.writeln;
    //    codeBools(true, false, true, false,true, false, true, false,true, false, true, true).binstr.writeln;
    //}

}

auto codeBools(Args...)(Args args) @nogc pure nothrow
    if(allSatisfy!(isBoolean, Args))
{
    static if(Args.length <= 8) {
        alias ret_t = ubyte;
    } else static if(Args.length <= 16) {
        alias ret_t = ushort;
    } else static if(Args.length <= 32) {
        alias ret_t = uint;
    } else {
        alias ret_t = ulong;
    }
    ret_t res = 0;
    static foreach(size_t i; 0 .. Args.length) {
        res |= args[i] ? (1 << (Args.length - i - 1)) : 0;
    }

    return res;
}



const(char)[11] threadHash() nothrow
{
    size_t procID  = thisProcessID();
    size_t thrdID  = thisThreadID();
    size_t thrHash = size_t.max ^ ((procID << 46) | thrdID);
    return fastHash( size_t.max ^ ((procID << 46) | thrdID) );
}

const(char)[T.sizeof * 8] binstr(T)(T val) @nogc pure nothrow
    if(isIntegral!T || isSomeChar!T)
{
    char[T.sizeof * 8] res;
    enum size_t one = 1;
    foreach(size_t i; 0 .. T.sizeof * 8) {
        res[T.sizeof * 8 - i - 1] = (val & (one << i)) ? '1' : '0';
    }
    return res;
}
const(char)[11] fastHash(size_t val) @nogc pure nothrow
{
    char[11] res;
    enum size_t one = size_t.max >> 58;

    //writeln( binstr( val  ), "\t" , val);

    foreach(size_t i; 0 .. 11) {
        size_t shift = i * 6;
        size_t index = ((one << shift) & val) >> shift;
        //writeln( binstr( index  ), "\t" , index, "\t", index._i2c());
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

class A
{
    int a;
    this(int x)
    {
        a = x;
    }

    int get() const
    {
        return a;
    }
}

class B : A
{
    this(int x)
    {
        super(x);
    }
    
    override int get() const
    {
        return a * a;
    }
}

