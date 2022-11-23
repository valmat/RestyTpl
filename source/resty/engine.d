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
import std.file : timeLastModified, exists;
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

final class Resty
{
private:
    LuaState _lua;
    LuaFunction _str_compiler;
    IRestyCompiler _compiler;
    // if setted will add as prefix to filepath
    string _tplDir;
    // if setted and `precomple = true` will store precompiled files
    string _cplDir;


public:

    this(in RestyOptons opts = RestyOptons())
    {
        _lua = new LuaState;
        _lua.openLibs();
        
        enum libSrc = import("deps/resty.p.luac");
        _lua["template"] = opts.resty_lua_lib.length ?
            _lua.loadFile(opts.resty_lua_lib)(opts.isSafe).front :
            _lua.loadBuffer(import("deps/resty.p.luac"))(opts.isSafe).front;

        _tplDir = opts.tplDir.fixDir();
        _cplDir = opts.cplDir.fixDir();

        _str_compiler = _lua.loadBuffer(`return template.compile`)().front().fun();
        LuaFunction file_compiler = _lua.loadBuffer(`return template.compile_file`)().front().fun();
        
        _compiler = opts.cache ?
            cast(IRestyCompiler)(new CacheCompiler(file_compiler)) :
            cast(IRestyCompiler)(new SimpleCompiler(file_compiler));
    }

    // TODO : add const
    View compileFile(string fileName)
    {
        return _tplDir.length ?
            _compiler.compile(_tplDir ~ fileName) :
            _compiler.compile(fileName);
    }
    View compile(string tpl)
    {
        return View(_str_compiler(tpl).front().fun());
    }
}

private:

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

class PrecompCompiler : IRestyCompiler
{
protected:
    LuaFunction _compiler;
    string _tplDir;
    string _cplDir;
    string _cplSfx;

public:
    this(LuaFunction compiler, string tplDir, string cplDir, string cplSfx = ".bin")
    {
        _compiler = compiler;
        _cplSfx   = (tplDir == cplDir) ? cplSfx : [];
    }

    View compile(string fileName)
    {
        string cplName = _cplDir ~ fileName[_tplDir.length .. $] ~ _cplSfx;
        if(cplName.exists) {
            return View(_compiler(cplName).front().fun());
        }
        auto view = View(_compiler(fileName).front().fun());
        view.dump(cplName);
        return view;
    }
}

final class PrecompCacheCompiler : PrecompCompiler
{
private:
    View[string] _cache;

public:
    this(LuaFunction compiler, string tplDir, string cplDir, string cplSfx = ".bin")
    {
        super(compiler, tplDir, cplDir, cplSfx);
    }

    override View compile(string fileName)
    {
        string key = fileName[_tplDir.length .. $];
        auto vp = key in _cache;
        if(vp is null) {
            string cplName = _cplDir ~ key ~ _cplSfx;

            View view;
            if(!cplName.exists) {
                view = View(_compiler(fileName).front().fun());
                view.dump(cplName);
            } else {
                view = View(_compiler(cplName).front().fun());
            }

            _cache[key] = view;
            return view;
        }
        return *vp;
    }
}

// With check changes
final class PrecompCacheChChCompiler : PrecompCompiler
{
private:
    TimedView[string] _cache;

public:
    this(LuaFunction compiler, string tplDir, string cplDir, string cplSfx = ".bin")
    {
        super(compiler, tplDir, cplDir, cplSfx);
    }

    override View compile(string fileName)
    {
        uint32_t lm = lmFileTime(fileName);
        string key = fileName[_tplDir.length .. $];
        auto vp = key in _cache;

        if((vp is null) || ((*vp).lm < lm)) {
            string cplName = _cplDir ~ key ~ _cplSfx;

            View view;
            if(!cplName.exists || ((vp !is null) && ((*vp).lm < lm))  ) {
                view = View(_compiler(fileName).front().fun());
                view.dump(cplName);
            } else {
                view = View(_compiler(cplName).front().fun());
            }

            _cache[key] = TimedView(view, lm);
            return view;
        }
        return (*vp).view;
    }
}

struct CacheCheck
{
    View view;
    bool changed = false;
}
struct TimedView
{
    View view;
    uint32_t lm;
}

interface ICacheCompiler
{
    CacheCheck compile(string fileName);
}

final class CacheCompiler : ICacheCompiler
{
private:
    LuaFunction _compiler;
    View[string] _cache;

public:
    this(LuaFunction compiler)
    {
        _compiler = compiler;
    }

    CacheCheck compile(string fileName)
    {
        auto vp = fileName in _cache;
        if(vp is null) {
            auto view = View(_compiler(fileName).front().fun());
            _cache[fileName] = view;
            return CacheCheck(view, true);
        }
        return CacheCheck(*vp);
    }
}

// With check changes
final class CacheChChCompiler : ICacheCompiler
{
private:
    LuaFunction _compiler;
    TimedView[string] _cache;

public:
    this(LuaFunction compiler)
    {
        _compiler = compiler;
    }

    CacheCheck compile(string fileName)
    {
        uint32_t lm = lmFileTime(fileName);
        auto vp = fileName in _cache;
        if((vp is null) || ((*vp).lm < lm)) {
            auto view = View(_compiler(fileName).front().fun());
            _cache[fileName] = TimedView(view, lm);
            return CacheCheck(view, true);
        }
        return CacheCheck((*vp).view);
    }
}

private:
uint32_t lmFileTime(string fileName)
{
    return (fileName.timeLastModified.stdTime - uint32_t.max) & size_t(uint32_t.max);
}
string fixDir(string dirName) pure nothrow
{
    if(!dirName.length || dirName[$-1] == '/') {
        return dirName;
    }
    return dirName ~ '/';
}