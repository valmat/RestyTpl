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


class Resty
{
//private:
public:
    LuaState _lua;
    LuaFunction _compiler;

public:

    this()
    {
        _lua = new LuaState;
        _lua.openLibs();
        enum libSrc = import("deps/resty.p.luac");
        _lua["template"] = _lua.loadBuffer(libSrc)(true).front;
        
        //_lua.doString(`
        //    print(template, "<---")
        //    print(template.render, "<---")
        //    for key,value in pairs(template) 
        //    do
        //       print(key, value)
        //    end
        //`);
        //auto render = _lua.loadBuffer(`return template.render`)().front;
        //render.writeln(" :: template.render");
        //pragma(msg,"type render ", typeof(render));
        //_lua.doString(`
        //    template.render([[
        //    <!DOCTYPE html>
        //    <html>
        //    <body>
        //      <h1>{{message}}</h1>
        //    </body>
        //    </html>
        //]], { message = "Hello, World!" })`); 
        //auto compile = _lua.loadBuffer(`return template.compile`)().front;
        //compile.writeln(" :: template.compile");
        //pragma(msg,"type compile ", typeof(compile));

        _compiler = _lua.loadBuffer(`return template.compile`)().front().fun();
    }

    View compile(string tpl)
    {
        return View(_compiler(tpl).front().fun());
    }
}