#!/bin/bash
n=${1##*level}
love . -w ${n%%.tmx}
