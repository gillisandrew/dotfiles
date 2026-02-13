#!/bin/bash
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

# --- Apply dotfiles ---
echo "==> Applying dotfiles..."
chezmoi init --apply gillisandrew

# --- Install packages from Brewfile.d ---
BREWFILE_DIR="$HOME/.Brewfile.d"
if [ -d "$BREWFILE_DIR" ]; then
  if [ "$DOTFILES_ENV" = "devcontainer" ]; then
    echo "==> Installing core packages (devcontainer)..."
    brew bundle --file="$BREWFILE_DIR/core"
  else
    echo "==> Installing all package roles..."
    for f in "$BREWFILE_DIR"/*; do
      [ -f "$f" ] && brew bundle --file="$f"
    done
  fi
else
  echo "==> No ~/.Brewfile.d/ found, skipping brew bundle"
fi

echo "==> Bootstrap complete ($DOTFILES_ENV)"
