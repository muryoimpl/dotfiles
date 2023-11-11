#!/bin/bash

today=$(date "+%Y%m%d")
year=$(date "+%Y")
month=$(date "+%m")
basedir=~/local/MEGAsync/memo
filename=$2

mkdir -p $basedir/$year

case $1 in
  -y)
     if [[ ! -e $basedir/$year/$year.md ]]; then
       cat - << EOS > "$basedir/$year/$year.md"
# $year
EOS
     fi

    cd $basedir
    nvim $year/$year.md
    ;;
  -m)
    if [[ ! -e $basedir/$year/$year$month.md ]]; then
      cat - << EOS > "$basedir/$year/$year$month.md"
# $year$month
EOS
    fi

    cd $basedir
    nvim $year/$year$month.md
    ;;

  -n)
    if [[ ! -e $basedir/$year/$filename.md ]]; then
      cat - << EOS > "$basedir/$year/$filename.md"
# $filename
EOS
    fi

    cd $basedir
    nvim $filename.md
    ;;

  *)
    if [[ ! -e $basedir/$year/$today.md ]]; then
      cat - << EOS > "$basedir/$year/$today.md"
# $today
EOS
    fi

    cd $basedir
    nvim $year/$today.md
esac
