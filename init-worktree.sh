#!/usr/bin/env bash

script_dir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

"$script_dir"/link-slang-utils.sh
git submodule update --init --recursive
nix-shell --run gen-compile-commands
