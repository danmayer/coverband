#!/bin/bash

LUA_DIR="$HOME/lua51"
LUA="$LUA_DIR/bin/lua"

if [ ! -f $LUA ]; then
  echo "Installing lua"
  pip install hererocks
  hererocks $LUA_DIR -l5.1 -rlatest
fi
source $LUA_DIR/bin/activate
lua -v
for i in luacov busted redis-lua inspect lua-cjson; do 
  luarocks install $i;
done
