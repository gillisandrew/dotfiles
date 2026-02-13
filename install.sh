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
  brew install chezmoi
else
  echo "==> chezmoi already installed"
fi

# --- Apply dotfiles ---
echo "==> Applying dotfiles..."
chezmoi init --apply gillisandrew

# --- Seed brew-groups config ---
BREW_GROUPS_FILE="$HOME/.config/brew-groups"
if [ ! -f "$BREW_GROUPS_FILE" ]; then
  mkdir -p "$HOME/.config"
  if [ "$DOTFILES_ENV" = "devcontainer" ]; then
    echo "==> Seeding brew-groups: core only (devcontainer)"
    : > "$BREW_GROUPS_FILE"
  else
    echo "==> Seeding brew-groups: all groups"
    cat > "$BREW_GROUPS_FILE" <<'GROUPS'
core
dev
ops
macos_cli
macos_apps
go_tools
GROUPS
  fi
else
  echo "==> brew-groups already configured"
fi

# --- Install packages from Brewfile ---
if [ -f "$HOME/.Brewfile" ]; then
  echo "==> Running brew bundle..."
  brew bundle --file="$HOME/.Brewfile"
else
  echo "==> No ~/.Brewfile found, skipping brew bundle"
fi

echo "==> Bootstrap complete ($DOTFILES_ENV)"
