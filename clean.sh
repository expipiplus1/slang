#!/usr/bin/env bash

git clean \
  -d \
  -x \
  --exclude="*.nix" \
  --exclude="*.md" \
  --exclude=.clang-format \
  --exclude=gdb-pretty.py \
  --exclude=tests \
  --exclude=hidden-llvm.patch \
  --exclude=clean.sh \
  --exclude=compile_flags.txt \
  --exclude=compile_commands.json \
  --exclude=.cache \
  --exclude=.vscode \
  --exclude=.mailmap \
  --exclude=.gdb_history \
  --exclude=vkd3d-proton.cache \
  --exclude=.ignore \
  "$@"
