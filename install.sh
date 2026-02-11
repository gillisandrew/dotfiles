#!/bin/bash
# Bootstrap script for GitHub Codespaces and other environments
# GitHub Codespaces automatically runs this when the repo is named "dotfiles"
set -euo pipefail
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply gillisandrew
