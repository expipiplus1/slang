#!/usr/bin/env bash

git clean \
  -d \
  -x \
  --exclude="*.md" \
  --exclude="*.nix" \
  --exclude=.cache \
  --exclude=.clang-format \
  --exclude=.clangd \
  --exclude=.gdb_history \
  --exclude=.ignore \
  --exclude=.mailmap \
  --exclude=.vscode \
  --exclude=clean.sh \
  --exclude=compile_commands.json \
  --exclude=compile_flags.txt \
  --exclude=gdb-pretty.py \
  --exclude=hidden-llvm.patch \
  --exclude=tests \
  --exclude=vkd3d-proton.cache \
  "$@"
