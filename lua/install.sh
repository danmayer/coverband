#!/bin/bash

LUA_DIR="$HOME/lua51"
BUSTED="$LUA_DIR/bin/busted"

if [ -f "$BUSTED" ]
then
  echo "$BUSTED already exists"
  exit 0
fi

pip install hererocks
hererocks $LUA_DIR -l5.1 -rlatest
source $LUA_DIR/bin/activate
lua -v
for i in luacov busted redis-lua inspect lua-cjson; do 
  luarocks install $i;
done
