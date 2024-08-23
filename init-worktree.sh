#!/usr/bin/env bash

script_dir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

from=$(realpath --relative-to="$(pwd)" "$script_dir")

for f in .vimspector.json .envrc clean.sh .ignore .vscode; do
  ln -v -s "$from/$f" "./$f"
done

# Init direnv
direnv allow

# Update the submodules from something locally
for f in $(grep '^\[submodule "\K.*(?="\]$)' .gitmodules --only-matching --perl-regexp); do
  git submodule update --init --reference "$from/$f" --recursive -- "$f"
done

set -e

# Grab any missing ones
git submodule update --init --recursive

# Generate our compilation command database
# nix develop "$from" --command gen-compile-commands

cmake --preset default \
  -DSLANG_SLANG_LLVM_FLAVOR=USE_SYSTEM_LLVM \
  -DSLANG_EMBED_STDLIB=1 \
  -DSLANG_EMBED_STDLIB_SOURCE=0 \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_COMPILER=clang \
  --fresh
cp build/compile_commands.json .
cmake --preset default \
  -DSLANG_SLANG_LLVM_FLAVOR=USE_SYSTEM_LLVM \
  --fresh \
  -DSLANG_ENABLE_DX_ON_VK=0
mk

