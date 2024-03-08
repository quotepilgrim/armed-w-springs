#!/bin/bash

echo return { >list.lua
for n in $(seq 1 $1); do
	echo "    \"level$n\"," >>list.lua
done
echo } >>list.lua
