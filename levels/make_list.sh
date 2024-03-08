#!/bin/bash

echo return { >list.lua
for level in level*.lua; do
	echo "    \"${level%%.lua}\"," >>list.lua
done
echo } >>list.lua
