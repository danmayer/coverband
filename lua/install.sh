#!/bin/bash

pip install hererocks
hererocks lua51 -l5.1 -rlatest
source lua51/bin/activate
lua -v
for i in luacov busted redis-lua inspect; do 
  luarocks install $i;
done
