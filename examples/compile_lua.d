#!/usr/bin/rdmd --shebang= -I./deps -I./submodules -I. -w -debug -L./deps/liblua.a

import luad.all   : LuaState, LuaFunction;
import std.getopt : getopt, defaultGetoptPrinter;

int main(string[] args)
{
    string from_file;
    string to_file;
    bool from_string = false;
    {
        auto helpInformation = getopt( args,
            "f|from",  "From data (text)",   &from_file,
            "t|to",    "To data (bytecode)", &to_file,
            "s|str",   "Read from string",   &from_string,
        );
        if (helpInformation.helpWanted || !from_file.length || !to_file.length) {
            defaultGetoptPrinter("Usage:", helpInformation.options);
            return 1;
        }
    }
    
    auto lua = new LuaState;
    lua.openLibs();

    LuaFunction func = from_string ?
        lua.loadBuffer(from_file):
        lua.loadFile(from_file);
    func.dump(to_file);

    return 0;
}

//./compile_lua.d -f 'local a = 5; return a'  -t deps/resty.luac -s
//./compile_lua.d -f ./deps/lua-resty-template/lib/resty/template.lua -t deps/resty.luac