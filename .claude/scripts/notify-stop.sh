#!/bin/bash
if [ "$(uname)" = "Darwin" ]; then
  afplay /System/Library/Sounds/Glass.aiff
elif [ "$(uname)" = "Linux" ]; then
  mpg123 ~/.claude/success.mp3
else
  echo "Unsupported OS for sound notification."
fi
