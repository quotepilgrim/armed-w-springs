#!/bin/bash

echo "return {" >list.lua

count=1

while [ -f "level$count.lua" ]; do
	echo "   \"level$count\"," >>list.lua
	count=$((count+1))
done

echo "}" >>list.lua
