#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
FILE="$(basename -- $1)"
mv "$1" "$DIR/.dotfiles/$FILE"
ln -s "$DIR/.dotfiles/$FILE" "$1"