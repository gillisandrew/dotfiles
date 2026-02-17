#!/usr/bin/env zsh
set -euo pipefail
CHEZMOI_DIR="$HOME/.usr/local/chezmoi"
git clone https://github.com/gillisandrew/dotfiles.git "$CHEZMOI_DIR" --depth=1

$CHEZMOI_DIR/install.sh
