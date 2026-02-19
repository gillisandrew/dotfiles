#!/usr/bin/env bash
# Bootstrap script for dotfiles environments.
# Installs Homebrew, chezmoi, applies dotfiles, and runs brew bundle.
# Safe to re-run — each step is idempotent.
set -euo pipefail

# --- Environment detection (inline — dotfiles-env not on disk yet) ---
case "$(uname -s)" in
  Darwin) DOTFILES_OS="macos" ;;
  *)      DOTFILES_OS="linux" ;;
esac

if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${CODESPACES:-}" ] || [ -f /.dockerenv ]; then
  DOTFILES_ENV="devcontainer"
elif [ "$DOTFILES_OS" = "linux" ]; then
  DOTFILES_ENV="remote-linux"
else
  DOTFILES_ENV="macos"
fi

export DOTFILES_OS DOTFILES_ENV

echo "==> Environment: $DOTFILES_ENV ($DOTFILES_OS)"

# --- Install Homebrew ---
if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for remainder of this script
  if [ "$DOTFILES_OS" = "macos" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
else
  echo "==> Homebrew already installed"
fi

# --- Install chezmoi ---
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "==> Installing chezmoi..."
  HOMEBREW_NO_ENV_HINTS=1 brew install chezmoi
else
  echo "==> chezmoi already installed"
fi

# --- Devcontainer: fix ZDOTDIR so zsh loads $HOME/.zshrc ---
if [ "$DOTFILES_ENV" = "devcontainer" ] && [ -f /etc/zsh/zshenv ]; then
  if ! grep -q 'ZDOTDIR="\$HOME"' /etc/zsh/zshenv 2>/dev/null; then
    echo "==> Patching /etc/zsh/zshenv for devcontainer ZDOTDIR..."
    sudo tee -a /etc/zsh/zshenv >/dev/null <<'ZSHENV'

# Point ZDOTDIR to $HOME so zsh finds our dotfiles (.zshenv, .zprofile, .zshrc)
export ZDOTDIR="$HOME"
ZSHENV
  fi
fi

# --- Apply dotfiles ---
# chezmoi init prompts for brew group selection, applies all dotfiles,
# then runs brew bundle --global + cleanup via run_onchange_after_brew-install.sh
echo "==> Applying dotfiles..."
# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
chezmoi init --apply "--source=$script_dir"

echo "==> Bootstrap complete ($DOTFILES_ENV)"
