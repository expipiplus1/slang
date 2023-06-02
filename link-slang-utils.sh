#!/usr/bin/env bash

script_dir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
them=$(realpath --relative-to="$(pwd)" "$script_dir")

for f in default.nix clean.sh .ignore .vscode; do
  ln -v -s "$them/$f" "./$f"
done

cp -v "$them/.mailmap" .

