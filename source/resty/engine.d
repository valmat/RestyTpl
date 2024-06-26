module resty.engine;

import std.stdio;
import std.range  : front, empty;
import std.file   : timeLastModified, exists;
import std.stdint : uint32_t;
import std.traits : isIntegral, isSomeChar, isBoolean;
import std.meta   : allSatisfy;
import luad.all   : LuaState, LuaFunction, LuaTable;
import resty.view : View;

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

enum string libSrcFileName = "deps/resty.p.luac";

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
        
        _lua["template"] = opts.resty_lua_lib.length ?
            _lua.loadFile(opts.resty_lua_lib)(opts.isSafe).front :
            _lua.loadBuffer(import(libSrcFileName))(opts.isSafe).front;


        auto tpl = _lua.get!LuaTable("template");

        //auto tpl = _lua["template"];
        //{
        //    auto tbl = tpl.table();
        //    tbl["xX"] = 1;
        //    tbl.typeName().writeln;

            
        //    tbl["parse"] = (string view, bool plain) {
        //        return "return 'return 5';";
        //    };
        //}
        //tpl["parse"] = (string view, bool plain) {
        //    return "return 'return 5';";
        //};
        //tpl.set("parse", (string view, bool plain) {
        //    return "return 'HA HA HA';";
        //});
        tpl.typeName().writeln;
        tpl.toString().writeln;



        _tplDir = opts.tplDir.fixDir();
        _cplDir = opts.cplDir.fixDir();

        _str_compiler = _lua.loadBuffer(`return template.compile`)().front().fun();
        LuaFunction file_compiler = _lua.loadBuffer(`return template.compile_file`)().front().fun();
        
        switch(codeBools(opts.cache, opts.precomple, opts.checkChanges)) {
            // Precompiles templates stores them to cplDir and caches result to internal memory
            // With check source file changes
            // +cache & +precomple & +checkChanges
            case 0b111:
                _compiler = new RestyCachePrecmpCkChngCompiler(file_compiler, _tplDir, _cplDir);
            break;

            // Precompiles templates stores them to cplDir and caches result to internal memory
            // +cache & +precomple & -checkChanges
            case 0b110:
                _compiler = new RestyCachePrecmpCompiler(file_compiler, _tplDir, _cplDir);
            break;

            // Compiles templates and caches result to internal memory
            // With check source file changes
            // +cache & -precomple & +checkChanges
            case 0b101:
                _compiler = new RestyCacheCkChngCompiler(file_compiler);
            break;

            // Just compiles templates and caches result to internal memory
            // +cache & -precomple & -checkChanges
            case 0b100:
                _compiler = new RestyCacheCompiler(file_compiler);
            break;

            // Precompiles templates and stores them to cplDir
            // With check source file changes
            // -cache & +precomple & +checkChanges
            case 0b011:
                _compiler = new RestyPrecmpCkChngCompiler(file_compiler, _tplDir, _cplDir);
            break;

            // Precompiles templates and stores them to cplDir
            // -cache & +precomple & -checkChanges
            case 0b010:
                _compiler = new RestyPrecmpCompiler(file_compiler, _tplDir, _cplDir);
            break;

            // Just compiles template. Nothing else.
            // -cache & -precomple & +-checkChanges
            default:
                _compiler = new RestyCompiler(file_compiler);
            break;
        }        
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

    void opIndexAssign(T, U...)(T value, U args)
    {
        _lua[args] = value;
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
    size_t lm;
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
        _tplDir   = tplDir;
        _cplDir   = cplDir;
        _cplSfx   = (tplDir.length || tplDir == cplDir) ? cplSfx : [];
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
        auto   lm  = lmFileTime(fileName);
        string key = fileName[_tplDir.length .. $];
        auto   vp  = key in _cache;

        if((vp is null) || ((*vp).lm < lm)) {
            string cplName = _cplDir ~ key ~ _cplSfx;
            auto   lm_cpl  = cplName.exists ? lmFileTime(cplName) : 0;

            View view;
            if((lm_cpl < lm) || ((vp !is null) && ((*vp).lm < lm))  ) {
                view = View(_compiler(fileName).front().fun());
                view.dump_atomic(cplName);
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
                view.dump_atomic(cplName);
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
        auto lm = lmFileTime(fileName);
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
final class RestyPrecmpCkChngCompiler : IRestyCompiler
{
    mixin PrecompCompilerTrait;
public:

    View compile(string fileName)
    {
        string cplName = _cplDir ~ fileName[_tplDir.length .. $] ~ _cplSfx;
        auto lm     = lmFileTime(fileName);
        auto lm_cpl = cplName.exists ? lmFileTime(cplName) : 0;

        if(lm > lm_cpl) {
            auto view = View(_compiler(fileName).front().fun());
            view.dump_atomic(cplName);
            return view;
        }
        return View(_compiler(cplName).front().fun());
    }
}

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
        view.dump_atomic(cplName);
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
size_t lmFileTime(string fileName)
{
    return fileName.timeLastModified.stdTime;
}
string fixDir(string dirName) pure nothrow
{
    if(!dirName.length || dirName[$-1] == '/') {
        return dirName;
    }
    return dirName ~ '/';
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