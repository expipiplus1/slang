#!/usr/bin/env bash

script_dir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

from=$(realpath --relative-to="$(pwd)" "$script_dir")

for f in .envrc clean.sh .ignore .vscode; do
  ln -v -s "$from/$f" "./$f"
done

# Init direnv
direnv allow

# Update the submodules from something locally
for f in $(grep '^\[submodule "\K.*(?="\]$)' .gitmodules --only-matching --perl-regexp); do
  git submodule update --init --reference "$from/$f" --recursive -- "$f"
done

# Grab any missing ones
git submodule update --init --recursive

# Generate our compilation command database
nix develop "$from" --command gen-compile-commands
