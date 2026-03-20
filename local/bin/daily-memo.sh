#!/bin/bash

today=$(date "+%Y%m%d")
tomorrow=$(date '+%Y%m%d' --date 'tomorrow')
year=$(date "+%Y")
month=$(date "+%m")
basedir=~/local/memo
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
    $EDITOR $year/$year.md
    ;;
# ----------------------
  -m)
    if [[ ! -e $basedir/$year/$year$month.md ]]; then
      cat - << EOS > "$basedir/$year/$year$month.md"
# $year$month
EOS
    fi

    cd $basedir
    $EDITOR $year/$year$month.md
    ;;

# ----------------------
  -n)
    if [[ ! -e $basedir/$year/$filename.md ]]; then
      cat - << EOS > "$basedir/$year/$filename.md"
# $filename
EOS
    fi

    cd $basedir
    $EDITOR $filename.md
    ;;

# ----------------------

  -d)
    cd $basedir
    $EDITOR .
    ;;

# ----------------------

  *)
    if [[ ! -e $basedir/$year/$today.md ]]; then
      cat - << EOS > "$basedir/$year/$today.md"
# $today

## 日報

\`\`\`
$(date '+%m月%d日(%a)')
- やったこと
  - hi
  -
- やること
  - hi
- 詰まっていること・気づき
  - hi
- 一言コメント
  - hi


\`\`\`

## その他


EOS
    fi
    if [[ ! -e $basedir/$year/$tomorrow.md ]]; then
      cat - << EOS > "$basedir/$year/$tomorrow.md"
# $tomorrow

## 日報

\`\`\`
$(date '+%m月%d日(%a)' --date 'tomorrow')
- やったこと
  - hi
  -
- やること
  - hi
- 詰まっていること・気づき
  - hi
- 一言コメント
  - hi


\`\`\`

## その他


EOS
    fi

    cd $basedir
    $EDITOR $year/$today.md
esac
