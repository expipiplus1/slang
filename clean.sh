#!/usr/bin/env bash

git clean \
  -d \
  -x \
  --exclude="*.nix" \
  --exclude="*.md" \
  --exclude=.clang-format \
  --exclude=gdb-pretty.py \
  --exclude=tests \
  --exclude=curses.patch \
  --exclude=clean.sh \
  --exclude=compile_flags.txt \
  --exclude=.vscode \
  --exclude=.mailmap \
  --exclude=.gdb_history \
  "$@"
