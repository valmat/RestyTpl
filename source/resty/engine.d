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

/*///////////////////////////////////////////
// Precompiles templates stores them to cplDir and caches result to internal memory
// With check source file changes
// +cache & +precomple & +checkChanges
RestyCachePrecmpCkChngCompiler

// Precompiles templates stores them to cplDir and caches result to internal memory
// +cache & +precomple & -checkChanges
RestyCachePrecmpCompiler

// Compiles templates and caches result to internal memory
// With check source file changes
// +cache & -precomple & +checkChanges
RestyCacheCkChngCompiler

// Just compiles templates and caches result to internal memory
// +cache & -precomple & -checkChanges
RestyCacheCompiler

// Precompiles templates and stores them to cplDir
// With check source file changes
// -cache & +precomple & +checkChanges
//...
RestyPrecmpCkChngCompiler

// Precompiles templates and stores them to cplDir
// -cache & +precomple & -checkChanges
RestyPrecmpCompiler

// Just compiles template. Nothing else.
// -cache & -precomple & +-checkChanges
RestyCompiler
///////////////////////////////////////////*/

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
            cast(IRestyCompiler)(new RestyCacheCompiler(file_compiler)) :
            cast(IRestyCompiler)(new RestyCompiler(file_compiler));

    //cache
    //precomple
    //checkChanges


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

struct TimedView
{
    View view;
    uint32_t lm;
}

mixin template PrecompCompilerTrait()
{
private:
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
}


// Precompiles templates stores them to cplDir and caches result to internal memory
// With check source file changes
// +cache & +precomple & +checkChanges
final class RestyCachePrecmpCkChngCompiler : IRestyCompiler
{
private:
    TimedView[string] _cache;
    mixin PrecompCompilerTrait;
public:
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

// Precompiles templates stores them to cplDir and caches result to internal memory
// +cache & +precomple & -checkChanges
final class RestyCachePrecmpCompiler : IRestyCompiler
{
private:
    View[string] _cache;
    mixin PrecompCompilerTrait;
public:

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

// Compiles templates and caches result to internal memory
// With check source file changes
// +cache & -precomple & +checkChanges
final class RestyCacheCkChngCompiler : IRestyCompiler
{
private:
    LuaFunction _compiler;
    TimedView[string] _cache;

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
            auto view = View(_compiler(fileName).front().fun());
            _cache[fileName] = TimedView(view, lm);
            return view;
        }
        return (*vp).view;
    }
}



// Just compiles templates and caches result to internal memory
// +cache & -precomple & -checkChanges
final class RestyCacheCompiler : IRestyCompiler
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
            auto view = View(_compiler(fileName).front().fun());
            _cache[fileName] = view;
            return view;
        }
        return *vp;
    }
}

// Precompiles templates and stores them to cplDir
// With check source file changes
// -cache & +precomple & +checkChanges
//...

// Precompiles templates and stores them to cplDir
// -cache & +precomple & -checkChanges
final class RestyPrecmpCompiler : IRestyCompiler
{
    mixin PrecompCompilerTrait;
public:

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

// Just compiles template. Nothing else.
// -cache & -precomple & +-checkChanges
final class RestyCompiler : IRestyCompiler
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