#/usr/bin/env bash

cd "$(dirname "$0")"

if [ ! -d "LuaD" ]; then
    git clone -b valmat "https://github.com/valmat/LuaD.git"
    exit 1;
fi

make -j`nproc`