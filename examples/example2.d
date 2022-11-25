#!/usr/bin/rdmd --shebang= -I./deps -I./submodules -I. -w -debug -L./deps/liblua.a -J.

import std.stdio;
import std.range;
import std.algorithm;
import std.array;
import std.typecons;
import std.string;
import resty;

void main()
{
    RestyOptons opts;
    // Do cache compiled templates
    opts.cache  = false;
    // If true, will precompile from tplDir and store to cplDir
    opts.precomple = false;
    // if true will check if file was changed and recompile if necessary
    opts.checkChanges = true;
    // if setted will add as prefix to filepath
    opts.tplDir = "tpls/tpls";
    // if setted and `precomple = true` will store precompiled files
    opts.cplDir = "tpls/cpls";
    // if setted will use this
    //opts.resty_lua_lib = "deps/resty.p.luac";
    opts.resty_lua_lib = "../deps/template.patched.lua";

    auto tplEngn = new Resty(opts);

    struct DataMsg{string message;}
    
    tplEngn.compileFile("1.tpl").call(DataMsg("Tpl 1")).writeln;
    tplEngn.compileFile("l2/2.tpl")(DataMsg("Tpl 2")).writeln;

    auto view = tplEngn.compileFile("3.tpl");

    struct DataMsg3
    {
        string message;
        string[size_t] values;
        string[] keywords = ["one", "two", "three"];

        auto iota1(int f, int t) {
            int i = f;
            return () {
                if(i < t) {
                    return nullable(i++);
                }
                return Nullable!int();
            };
        }
        auto iota2 = &iota!(int,int,int);

        auto range1 = iota(1, 5).map!`a*a`;

    }

    view(DataMsg3("Message from D 3", [11:"one", 22:"two", 33:"three"])).writeln;

}