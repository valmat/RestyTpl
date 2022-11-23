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
import std.file : timeLastModified;
import std.stdint : uint32_t;

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
    LuaFunction _str_compiler;
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

        _str_compiler = _lua.loadBuffer(`return template.compile`)().front().fun();
        LuaFunction file_compiler = _lua.loadBuffer(`return template.compile_file`)().front().fun();
        
        _compiler = opts.cache ?
            cast(IRestyCompiler)(new CacheCompiler(file_compiler)) :
            cast(IRestyCompiler)(new SimpleCompiler(file_compiler));
    }

    // TODO : add const
    View compileFile(string fileName)
    {
        return _compiler.compile(fileName);
    }
    View compile(string tpl)
    {
        return View(_str_compiler(tpl).front().fun());
    }
}

interface IRestyCompiler
{
    View compile(string fileName);
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

    View compile(string fileName)
    {
        return View(_compiler(fileName).front().fun());
    }
}

final class CacheCompiler : IRestyCompiler
{
private:
    LuaFunction _compiler;
    View[string] _cache;

public:
    this(LuaFunction compiler)
    {
        _compiler = compiler;
    }

    View compile(string fileName)
    {
        auto vp = fileName in _cache;
        if(vp is null) {
            auto res = View(_compiler(fileName).front().fun());
            _cache[fileName] = res;
            return res;
        }
        return *vp;
    }
}

// With check changes
final class CacheChChCompiler : IRestyCompiler
{
private:
    static struct CacheUnit
    {
        View view;
        uint32_t lm;
    }

    LuaFunction _compiler;
    CacheUnit[string] _cache;

public:
    this(LuaFunction compiler)
    {
        _compiler = compiler;
    }

    View compile(string fileName)
    {
        uint32_t lm = lmFileTime(fileName);
        auto vp = fileName in _cache;
        if((vp is null) || ((*vp).lm < lm)) {
            auto res = View(_compiler(fileName).front().fun());
            _cache[fileName] = CacheUnit(res, lm);
            return res;
        }
        return (*vp).view;
    }
}

private:
uint32_t lmFileTime(string fileName)
{
    return (fileName.timeLastModified.stdTime - uint32_t.max) & size_t(uint32_t.max);
}