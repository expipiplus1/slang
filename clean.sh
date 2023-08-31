#!/usr/bin/env bash

the_usual_stuff=$(cat <<EOF
Makefile
bin/.*
build/.*
downloads/.*
external/slang-glslang/.*
external/slang-llvm/.*
intermediate/.*
prelude/slang-[a-z-]\+-prelude.h.cpp
source/slang/[a-z]\+.meta.slang.h
source/slang/slang-generated-[a-z-]\+.h
EOF
)

clean()
{
  git clean \
    -d \
    -x \
    --exclude="*.md" \
    --exclude="*.nix" \
    --exclude=.cache \
    --exclude=.clang-format \
    --exclude=.clangd \
    --exclude=.direnv \
    --exclude=.envrc \
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
}

if [ "$*" == -n ]; then
  echo "Would remove the usual stuff"
  # shellcheck disable=SC2001
  clean "$@" | grep --invert-match --line-regexp --file <(echo "$the_usual_stuff" | sed 's/^/Would remove /' )
else
  clean "$@"
fi
