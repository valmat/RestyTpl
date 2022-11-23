module resty.engine;

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

import resty.view;

struct RestyOptons
{
    // Is safe templates
    bool isSafe = true;
    
    // Do cache compiled templates
    bool cache  = false;

    // If true, will precompile from tplDir and store to cplDir
    bool precomple = false;

    // if true will check if file was changed and recompile if necessary
    bool checkChanges = false;

    // if setted will add as prefix to filepath
    string tplDir;

    // if setted and `precomple = true` will store precompiled files
    string cplDir;

    // if setted will use this
    string resty_lua_lib;
}

class Resty
{
protected:
    LuaState _lua;
    IRestyCompiler _compiler;

public:

    this(in RestyOptons opts = RestyOptons())
    {
        _lua = new LuaState;
        _lua.openLibs();
        enum libSrc = import("deps/resty.p.luac");
        _lua["template"] = opts.resty_lua_lib.length ?
            _lua.loadFile(opts.resty_lua_lib)(opts.isSafe).front :
            _lua.loadBuffer(import("deps/resty.p.luac"))(opts.isSafe).front;

        LuaFunction fun_compiler = _lua.loadBuffer(`return template.compile`)().front().fun();
        
        _compiler = new SimpleCompiler(fun_compiler);
    }

    // TODO : add const
    View compile(string tpl)
    {
        return _compiler.compile(tpl);
    }
}

interface IRestyCompiler
{
    View compile(string tpl);
}

final class SimpleCompiler : IRestyCompiler
{
private:
    LuaFunction _compiler;

public:
    this(LuaFunction compiler)
    {
        _compiler = compiler;
    }

    View compile(string tpl)
    {
        return View(_compiler(tpl).front().fun());
    }
}