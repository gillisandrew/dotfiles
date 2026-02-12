# Runtime Guards and Bootstrap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace chezmoi Go templates in shell configs with runtime shell guards and add full Homebrew bootstrap to install.sh.

**Architecture:** A shared POSIX detection script (`dotfiles-env`) exports `DOTFILES_OS` and `DOTFILES_ENV`. Shell configs source it and use `if` guards instead of Go template conditionals. The Brewfile uses Ruby conditionals for tiering. `install.sh` handles the full bootstrap chain: Homebrew → chezmoi → apply → brew bundle.

**Tech Stack:** chezmoi, POSIX sh, zsh, Homebrew (Ruby DSL for Brewfile)

---

### Task 1: Create the environment detection script

**Files:**
- Create: `dot_local/bin/executable_dotfiles-env`

**Step 1: Create the detection script**

```sh
#!/bin/sh
# Detect dotfiles target environment.
# Source this from shell configs: . "$HOME/.local/bin/dotfiles-env"
#
# Exports:
#   DOTFILES_OS  — "macos" or "linux"
#   DOTFILES_ENV — "macos", "devcontainer", or "remote-linux"

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
```

**Step 2: Verify chezmoi recognizes the file**

Run: `chezmoi managed | grep dotfiles-env`
Expected: `.local/bin/dotfiles-env` appears in managed list

**Step 3: Verify the script runs on this machine**

Run: `sh dot_local/bin/executable_dotfiles-env && echo "OK"`
Expected: `OK` (no errors)

**Step 4: Commit**

```bash
git add dot_local/bin/executable_dotfiles-env
git commit -m "feat: add dotfiles-env environment detection script"
```

---

### Task 2: Convert dot_zshenv from template to plain file

**Files:**
- Delete: `dot_zshenv.tmpl`
- Create: `dot_zshenv`

The current `dot_zshenv.tmpl` has no template syntax, so this is a straight rename plus adding the detection guard for ESPANSO_CONFIG_DIR (macOS-only app).

**Step 1: Rename and rewrite the file**

Delete `dot_zshenv.tmpl`. Create `dot_zshenv`:

```sh
# .zshenv is sourced by every zsh invocation (login, interactive, non-interactive).
# Decision tree:
# - interactive? -> .zshrc
# - login? -> .zprofile
# - otherwise -> .zshenv (minimal, universal env only)
# Example: export LANG="en_US.UTF-8"

. "$HOME/.local/bin/dotfiles-env"

# Use XDG path for espanso config (macOS-only app)
if [ "$DOTFILES_ENV" = "macos" ]; then
  export ESPANSO_CONFIG_DIR="$HOME/.config/espanso"
fi
```

**Step 2: Verify chezmoi output matches expectations**

Run: `chezmoi cat ~/.zshenv`
Expected: The plain shell file (no Go template syntax), with the dotfiles-env source line and guarded ESPANSO_CONFIG_DIR.

**Step 3: Commit**

```bash
git rm dot_zshenv.tmpl
git add dot_zshenv
git commit -m "refactor: convert dot_zshenv from template to runtime guards"
```

---

### Task 3: Convert dot_zprofile from template to plain file

**Files:**
- Delete: `dot_zprofile.tmpl`
- Create: `dot_zprofile`

**Step 1: Rename and rewrite the file**

Delete `dot_zprofile.tmpl`. Create `dot_zprofile` with runtime guards replacing all Go template conditionals:

```sh
## .zprofile: login shell setup
# Runs once for login shells. Put environment and PATH here.
# Good: PATH tweaks, JAVA_HOME, pnpm/go/cargo, EDITOR defaults.
# Avoid: prompt, aliases, completions, or interactive tooling.

. "$HOME/.local/bin/dotfiles-env"

# Homebrew shellenv
if [ "$DOTFILES_OS" = "macos" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Language/toolchain env
export GOPATH="$HOME/.local/share/go"
export GOBIN="$HOME/.local/bin"
export PATH="$PATH:$GOPATH/bin"

if [ "$DOTFILES_ENV" = "macos" ]; then
  export JAVA_HOME=$(/usr/libexec/java_home)
fi

# pnpm
if [ "$DOTFILES_OS" = "macos" ]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
case ":$PATH:" in
	*":$PNPM_HOME:"*) ;;
	*) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Common user bins
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# Preferred editor for local and remote sessions
if [ -n "$SSH_CONNECTION" ]; then
	export EDITOR='vim'
else
	export EDITOR='code'
fi
```

Key changes from template version:
- Sources `dotfiles-env` at top
- Homebrew shellenv now handles both macOS (`/opt/homebrew`) and Linux (`/home/linuxbrew`)
- `JAVA_HOME` guarded by `DOTFILES_ENV = macos`
- PNPM path uses `DOTFILES_OS` if/else (same logic, shell guards instead of template)
- EDITOR block unchanged (already used shell `$SSH_CONNECTION` check)
- Removed the deleted PHP Herd/Helm block (already removed in prior commit)

**Step 2: Verify chezmoi output**

Run: `chezmoi cat ~/.zprofile`
Expected: The plain shell file with runtime guards. No Go template syntax.

**Step 3: Commit**

```bash
git rm dot_zprofile.tmpl
git add dot_zprofile
git commit -m "refactor: convert dot_zprofile from template to runtime guards"
```

---

### Task 4: Convert dot_zshrc from template to plain file

**Files:**
- Delete: `dot_zshrc.tmpl`
- Create: `dot_zshrc`

**Step 1: Rename and rewrite the file**

Delete `dot_zshrc.tmpl`. Create `dot_zshrc`. The only template block is the SSH_AUTH_SOCK conditional and the espansoconfig alias (macOS-only). Everything else is already plain shell.

```sh
## .zshrc: interactive shell config
# Runs for interactive shells only.
# Good: prompt/theme, aliases, functions, completions, keybindings.
# Avoid: PATH/toolchain exports (keep those in .zprofile).

[[ -o interactive ]] || return

. "$HOME/.local/bin/dotfiles-env"

autoload -Uz compinit && compinit

if [ "$DOTFILES_ENV" = "macos" ]; then
  export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
fi

# Common aliases
if [ "$DOTFILES_ENV" = "macos" ]; then
  alias espansoconfig="code \"$HOME/.config/espanso\""
fi
[ "$(command -v curlie)" ] && alias curl="curlie"
[ "$(command -v bat)" ] && alias cat="bat"

extract () {
  if [ -f "$1" ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1     ;;
      *.tar.gz)    tar xzf $1     ;;
      *.bz2)       bunzip2 $1     ;;
      *.rar)       unrar e $1     ;;
      *.gz)        gunzip $1      ;;
      *.tar)       tar xf $1      ;;
      *.tbz2)      tar xjf $1     ;;
      *.tgz)       tar xzf $1     ;;
      *.zip)       unzip $1       ;;
      *.Z)         uncompress $1  ;;
      *.7z)        7z x $1        ;;
      *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
      echo "'$1' is not a valid file"
    fi
}

refresh_github_token() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI (gh) is not installed."
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "No active GitHub CLI authentication session found."
    return 2
  fi

  local env_file="$HOME/.local/env/$1"
  if [ ! -f "$env_file" ]; then
    echo "Environment file '$env_file' not found."
    return 3
  fi

  local new_token
  new_token=$(gh auth token 2>/dev/null)
  if [ -z "$new_token" ]; then
    echo "Failed to retrieve GitHub token."
    return 4
  fi

  local var_name="${2:-GITHUB_TOKEN}"
  sed -i.bak -E "s|^(${var_name}=).*|\1$new_token|" "$env_file"
  echo "$var_name updated in $env_file"

}

export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
export CARAPACE_MATCH=1
# zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'

if [ -z "$CLAUDECODE" ]; then
  [ -z "$DISABLE_CARAPACE" ] && [ "$(command -v carapace)" ] && source <(carapace _carapace zsh)
  # [ -z "$DISABLE_FZF" ] && [ "$(command -v fzf)" ] && source <(fzf --zsh)
  # [ -z "$DISABLE_TV" ] && [ "$(command -v tv)" ] && eval "$(tv init zsh)"
  [ -z "$DISABLE_STARSHIP" ] && [ "$(command -v starship)" ] && eval "$(starship init zsh)"
  # [ -z "$DISABLE_MCFLY" ] && [ "$(command -v mcfly)" ] && eval "$(mcfly init zsh)"
  [ -z "$DISABLE_ATUIN" ] && [ "$(command -v atuin)" ] && eval "$(atuin init zsh)"
  [ -z "$DISABLE_ZOXIDE" ] && [ "$(command -v zoxide)" ] && eval "$(zoxide init zsh --cmd cd)"
fi


curl_harder() {
  local count=0;
  until curl "$@" -O --retry 999 --retry-max-time 0 -C -
  do
    ((count++))
    echo "Reattempting download...${count}"
    sleep 1
  done
}
```

Key changes:
- Sources `dotfiles-env` after the interactive guard
- `SSH_AUTH_SOCK` wrapped in `DOTFILES_ENV = macos` guard
- `espansoconfig` alias wrapped in same guard
- Everything else unchanged (tool inits already use `command -v` guards)

**Step 2: Verify chezmoi output**

Run: `chezmoi cat ~/.zshrc`
Expected: The plain shell file with runtime guards. No Go template syntax.

**Step 3: Commit**

```bash
git rm dot_zshrc.tmpl
git add dot_zshrc
git commit -m "refactor: convert dot_zshrc from template to runtime guards"
```

---

### Task 5: Restructure Brewfile with Ruby guards and move to dot_Brewfile

**Files:**
- Delete: `Brewfile`
- Create: `dot_Brewfile`

**Step 1: Create the tiered Brewfile with Ruby guards**

Delete `Brewfile`. Create `dot_Brewfile`:

```ruby
# Taps
tap "oven-sh/bun"
tap "withgraphite/tap"

# === Core CLI (all environments) ===
brew "atuin"
brew "bat"
brew "chezmoi"
brew "curlie"
brew "fzf"
brew "gh"
brew "git"
brew "gum"
brew "htop"
brew "ripgrep"
brew "starship"
brew "yq"
brew "zoxide"

# === Full CLI (skip in ephemeral devcontainers) ===
unless ENV["DOTFILES_ENV"] == "devcontainer"
  brew "awscli"
  brew "beads"
  brew "fx"
  brew "git-filter-repo"
  brew "gitleaks"
  brew "go"
  brew "jtbl"
  brew "kondo"
  brew "ncdu"
  brew "openssh"
  brew "oras"
  brew "pandoc"
  brew "pre-commit"
  brew "rust"
  brew "tmux"
  brew "uutils-coreutils"
  brew "uv"
  brew "oven-sh/bun/bun"
  brew "withgraphite/tap/graphite"
end

# === macOS only ===
if OS.mac?
  brew "trash"
  brew "yubico-piv-tool"
  brew "zsh-syntax-highlighting"

  # Applications
  cask "anki"
  cask "bitwarden"
  cask "claude"
  cask "docker-desktop"
  cask "espanso"
  cask "figma"
  cask "ghostty"
  cask "logi-options+"
  cask "microsoft-edge"
  cask "microsoft-excel"
  cask "microsoft-onenote"
  cask "microsoft-outlook"
  cask "microsoft-powerpoint"
  cask "microsoft-word"
  cask "nordvpn"
  cask "obsidian"
  cask "onedrive"
  cask "pearcleaner"
  cask "spotify"
  cask "steam"
  cask "temurin"
  cask "visual-studio-code"
  cask "whatsapp"
  cask "windows-app"
  cask "yubico-authenticator"

  # VS Code extensions
  vscode "42crunch.vscode-openapi"
  vscode "anthropic.claude-code"
  vscode "arjun.swagger-viewer"
  vscode "attilabuti.vscode-mjml"
  vscode "bierner.markdown-footnotes"
  vscode "bierner.markdown-mermaid"
  vscode "bierner.markdown-preview-github-styles"
  vscode "bpruitt-goddard.mermaid-markdown-syntax-highlighting"
  vscode "bradlc.vscode-tailwindcss"
  vscode "catppuccin.catppuccin-vsc"
  vscode "charliermarsh.ruff"
  vscode "codeque.codeque"
  vscode "cpylua.language-postcss"
  vscode "davidanson.vscode-markdownlint"
  vscode "dbaeumer.vscode-eslint"
  vscode "dracula-theme.theme-dracula"
  vscode "eamodio.gitlens"
  vscode "editorconfig.editorconfig"
  vscode "esbenp.prettier-vscode"
  vscode "foxundermoon.shell-format"
  vscode "github.codespaces"
  vscode "github.copilot-chat"
  vscode "github.vscode-github-actions"
  vscode "golang.go"
  vscode "humao.rest-client"
  vscode "jebbs.plantuml"
  vscode "jock.svg"
  vscode "ms-azuretools.vscode-containers"
  vscode "ms-dotnettools.vscode-dotnet-runtime"
  vscode "ms-python.debugpy"
  vscode "ms-python.python"
  vscode "ms-python.vscode-pylance"
  vscode "ms-python.vscode-python-envs"
  vscode "ms-toolsai.jupyter"
  vscode "ms-toolsai.jupyter-keymap"
  vscode "ms-toolsai.jupyter-renderers"
  vscode "ms-toolsai.vscode-jupyter-cell-tags"
  vscode "ms-toolsai.vscode-jupyter-slideshow"
  vscode "ms-vscode-remote.remote-containers"
  vscode "ms-vscode-remote.remote-ssh"
  vscode "ms-vscode-remote.remote-ssh-edit"
  vscode "ms-vscode.makefile-tools"
  vscode "ms-vscode.remote-explorer"
  vscode "ms-vscode.remote-server"
  vscode "ms-vsliveshare.vsliveshare"
  vscode "nrwl.angular-console"
  vscode "prisma.prisma"
  vscode "redhat.vscode-commons"
  vscode "redhat.vscode-yaml"
  vscode "richie5um2.vscode-sort-json"
  vscode "rust-lang.rust-analyzer"
  vscode "ryuta46.multi-command"
  vscode "svelte.svelte-vscode"
  vscode "tamasfe.even-better-toml"
  vscode "tauri-apps.tauri-vscode"
  vscode "tomoki1207.pdf"
  vscode "tyriar.sort-lines"
  vscode "vscodevim.vim"
  vscode "william-voyek.vscode-nginx"
  vscode "yzhang.markdown-all-in-one"

  # Go tools
  go "golang.org/x/tools/gopls"
end
```

**Step 2: Verify chezmoi target path**

Run: `chezmoi target-path dot_Brewfile`
Expected: Should resolve to `~/.Brewfile`

**Step 3: Commit**

```bash
git rm Brewfile
git add dot_Brewfile
git commit -m "refactor: add Ruby guards to Brewfile and deploy as ~/.Brewfile"
```

---

### Task 6: Rewrite install.sh with full bootstrap flow

**Files:**
- Modify: `install.sh`

**Step 1: Rewrite install.sh**

```bash
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

# --- Install packages from Brewfile ---
if [ -f "$HOME/.Brewfile" ]; then
  echo "==> Running brew bundle..."
  brew bundle --file="$HOME/.Brewfile" --no-lock
else
  echo "==> No ~/.Brewfile found, skipping brew bundle"
fi

echo "==> Bootstrap complete ($DOTFILES_ENV)"
```

**Step 2: Verify the script is syntactically valid**

Run: `bash -n install.sh`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add install.sh
git commit -m "feat: rewrite install.sh with full Homebrew bootstrap flow"
```

---

### Task 7: Delete run_once_before_install-gum.sh.tmpl

**Files:**
- Delete: `.chezmoiscripts/run_once_before_install-gum.sh.tmpl`

gum is now installed by `brew bundle` during bootstrap. The standalone pre-install script is no longer needed.

**Step 1: Delete the file**

```bash
git rm .chezmoiscripts/run_once_before_install-gum.sh.tmpl
```

**Step 2: Commit**

```bash
git commit -m "chore: remove gum pre-install script (handled by brew bundle)"
```

---

### Task 8: Update .chezmoiignore

**Files:**
- Modify: `.chezmoiignore`

The `.chezmoiignore` needs two updates:
1. Add `docs/` directory (plans shouldn't be deployed to home directory)
2. Keep existing ignore rules intact

**Step 1: Update .chezmoiignore**

Current file:
```
install.sh
.pre-commit-config.yaml
.gitleaks.toml
README.md

{{ if ne .chezmoi.os "darwin" }}
.config/ghostty
.config/zed
.config/espanso
{{ end }}

{{ if not .aws.enabled }}
.aws
.local/bin/refresh-zorg-profiles
{{ end }}
```

Add `docs/` to the top static ignore list:

```
install.sh
.pre-commit-config.yaml
.gitleaks.toml
README.md
docs/

{{ if ne .chezmoi.os "darwin" }}
.config/ghostty
.config/zed
.config/espanso
{{ end }}

{{ if not .aws.enabled }}
.aws
.local/bin/refresh-zorg-profiles
{{ end }}
```

**Step 2: Verify docs/ is ignored by chezmoi**

Run: `chezmoi managed | grep docs`
Expected: No output (docs directory is not managed)

**Step 3: Commit**

```bash
git add .chezmoiignore
git commit -m "chore: ignore docs/ directory in chezmoi"
```

---

### Task 9: Verify full chezmoi diff is clean

**Step 1: Run chezmoi diff to check for unexpected changes**

Run: `chezmoi diff`
Expected: Either empty output or expected changes from the new guard structure. The target files should have the runtime guards instead of resolved template output.

**Step 2: Run chezmoi apply with dry-run**

Run: `chezmoi apply --dry-run --verbose`
Expected: Shows what would change. Verify no unexpected files are created/deleted.

**Step 3: Apply if diff looks correct**

Run: `chezmoi apply`
Expected: Dotfiles updated on disk with runtime guards.
