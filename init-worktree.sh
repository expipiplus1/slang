#!/usr/bin/env bash

script_dir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

them=$(realpath --relative-to="$(pwd)" "$script_dir")

for f in clean.sh .ignore .vscode; do
  ln -v -s "$them/$f" "./$f"
done

for f in flake.nix flake.lock; do
  cp -v "$them/$f" "./$f"
done

git submodule update --init --recursive
nix-shell --run gen-compile-commands
