#!/bin/bash

today=$(date "+%Y%m%d")
year=$(date "+%Y")
basedir=~/local/MEGAsync/memo

mkdir -p $basedir/$year

if [[ ! -e $basedir/$year/$today.md ]]; then
  cat - << EOS > "$basedir/$year/$today.md"
# $today
EOS
fi

vim $basedir/$year/$today.md
