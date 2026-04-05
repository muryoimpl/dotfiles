#!/bin/bash
if [ "$(uname)" = "Darwin" ]; then
  afplay ~/.claude/pin3.mp3
elif [ "$(uname)" = "Linux" ]; then
  mpg123 -q ~/.claude/pin3.mp3
else
  echo "Unsupported OS for sound notification."
fi
