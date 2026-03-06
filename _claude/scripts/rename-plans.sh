!/bin/bash

for f in ~/.claude/plans/*.md ./plans/*.md; do
  [ -f "$f" ] || continue
  dir=$(dirname "$f")
  base=$(basename "$f")
  # 既に prefix つきならスキップ
  [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]] && continue
  ts=$(date -r "$f" +"%Y%m%d-%H%M")
  mkdir -p "$dir/done/"
  mv "$f" "$dir/done/$ts-$base"
done
