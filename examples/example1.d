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

    auto tplEngn = new Resty(opts);
    string tpl = `<body>{{message}}</html>`;
    auto  data = ["message" : "Hello, World! outside"];

    auto view = tplEngn.compile(tpl);
    view.writeln;
    view(data).writeln;
    tplEngn.compileFile("tpls/tpls/1.tpl")(data).writeln;
    tplEngn.compileFile("tpls/tpls/l2/2.tpl").call(data).writeln;

    

    struct DataMsg{string message;}
    view(DataMsg("Message from D 1")).writeln;

    auto v2 = tplEngn.compile("tpls/tpls/1.tpl");
    v2(DataMsg("Message from D2")).writeln;
}

