#!/bin/bash

LUA_DIR="./tmp/lua51"
pip install hererocks
hererocks $LUA_DIR -l5.1 -rlatest
source $LUA_DIR/bin/activate
lua -v
for i in luacov busted redis-lua inspect; do 
  luarocks install $i;
done
