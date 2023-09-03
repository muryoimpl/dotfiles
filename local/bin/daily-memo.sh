#!/bin/bash

today=$(date "+%Y%m%d")
year=$(date "+%Y")
month=$(date "+%m")
basedir=~/MEGAsync/memo

mkdir -p $basedir/$year

case $1 in
  -y)
     if [[ ! -e $basedir/$year/$year.md ]]; then
       cat - << EOS > "$basedir/$year/$year.md"
# $year
EOS
     fi

     nvim $basedir/$year/$year.md
    ;;
  -m)
    if [[ ! -e $basedir/$year/$year$month.md ]]; then
      cat - << EOS > "$basedir/$year/$year$month.md"
# $year$month
EOS
    fi

    nvim $basedir/$year/$year$month.md
    ;;
  *)
    if [[ ! -e $basedir/$year/$today.md ]]; then
      cat - << EOS > "$basedir/$year/$today.md"
# $today
EOS
    fi

    nvim $basedir/$year/$today.md
esac
