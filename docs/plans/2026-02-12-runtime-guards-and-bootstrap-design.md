# Runtime Guards and Bootstrap Redesign

## Goal

Replace chezmoi Go templates in shell config files with runtime shell guards for environment detection. Add Homebrew installation to `install.sh` for consistent bootstrapping across macOS, devcontainers, and remote Linux.

## Environments

Three target environments, detected at runtime:

| Environment      | Detection                                                        | Example                        |
| ---------------- | ---------------------------------------------------------------- | ------------------------------ |
| `macos`          | `uname -s` = Darwin                                             | Local MacBook                  |
| `devcontainer`   | `$REMOTE_CONTAINERS`, `$CODESPACES`, or `/.dockerenv` exists    | VS Code devcontainer, Codespaces |
| `remote-linux`   | Linux and none of the container signals                          | SSH to a bare server           |

## 1. Environment Detection Script

New file: `dot_local/bin/executable_dotfiles-env`

```bash
#!/bin/sh
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

- POSIX sh for portability (sourceable from any shell or script)
- Lives at `~/.local/bin/dotfiles-env`
- Shell configs source it: `. "$HOME/.local/bin/dotfiles-env"`

## 2. Shell Config Conversions

These files drop their `.tmpl` suffix and use runtime guards instead of Go template conditionals.

### dot_zprofile (was dot_zprofile.tmpl)

| Current template block                          | Becomes                                                  |
| ------------------------------------------------ | -------------------------------------------------------- |
| `{{ if eq .chezmoi.os "darwin" }}` brew shellenv  | `if [ "$DOTFILES_ENV" = "macos" ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi` |
| `{{ if eq .chezmoi.os "darwin" }}` JAVA_HOME      | Same macos guard                                         |
| `{{ if eq .chezmoi.os "darwin" }}` PNPM path      | `if/else` on `$DOTFILES_OS` for path differences         |
| EDITOR via SSH_TTY check                         | Already a runtime guard — no change                      |

### dot_zshrc (was dot_zshrc.tmpl)

| Current template block                          | Becomes                                        |
| ------------------------------------------------ | ---------------------------------------------- |
| SSH agent socket (macOS)                         | `if [ "$DOTFILES_ENV" = "macos" ]` guard       |
| `espansoconfig` alias (macOS)                    | Same guard                                     |
| Tool inits (starship, atuin, zoxide, carapace)   | Already use `command -v` guards — no change    |

### dot_zshenv (was dot_zshenv.tmpl)

| Current template block                          | Becomes                                        |
| ------------------------------------------------ | ---------------------------------------------- |
| `ESPANSO_CONFIG_DIR` (macOS)                     | `if [ "$DOTFILES_ENV" = "macos" ]` guard       |

## 3. Files That Stay as Templates

These files need chezmoi data variables or aren't shell scripts:

- `dot_gitconfig.tmpl` — needs `.email`, macOS-specific signing/editor
- `private_dot_ssh/config.tmpl` — needs macOS-specific IdentityFile path
- `dot_aws/modify_private_config.tmpl` — needs `.aws.*` data
- `executable_refresh-zorg-profiles.tmpl` — needs `.aws.*` data
- `.chezmoiscripts/run_once_after_setup-aws-sso.sh.tmpl` — needs `.aws.enabled`
- `.chezmoiscripts/run_onchange_after_restart-espanso.sh.tmpl` — needs chezmoi hash functions

## 4. install.sh Bootstrap Script

Single entry point for any fresh environment. Sequential, idempotent flow:

```
1. Detect environment (inline — dotfiles-env doesn't exist yet)
2. Install Homebrew (skip if `brew` already on PATH)
   - Sets NONINTERACTIVE=1 for CI/Codespaces
3. Install chezmoi via `brew install chezmoi`
4. Run `chezmoi init --apply gillisandrew`
   - Lays down all dotfiles including Brewfile at ~/.Brewfile
5. Export DOTFILES_ENV, run `brew bundle --file=~/.Brewfile --no-lock`
   - Ruby guards in Brewfile adapt to the detected environment
```

Replaces the current one-liner. Safe to re-run — each step checks before acting.

## 5. Brewfile with Ruby Guards

Rename: `Brewfile` → `dot_Brewfile` (chezmoi places it at `~/.Brewfile`)

Three tiers using Ruby conditionals:

```ruby
# === Core CLI (all environments) ===
brew "atuin"
brew "bat"
brew "chezmoi"
brew "fzf"
brew "gh"
brew "git"
brew "gum"
brew "ripgrep"
brew "starship"
brew "zoxide"
# ...

# === Full CLI (macOS + remote Linux, skip devcontainers) ===
unless ENV["DOTFILES_ENV"] == "devcontainer"
  brew "awscli"
  brew "go"
  brew "rust"
  brew "uv"
  # ...
end

# === macOS only (casks, VS Code extensions, macOS CLI) ===
if OS.mac?
  brew "zsh-syntax-highlighting"
  brew "trash"
  # ...

  cask "claude"
  cask "ghostty"
  cask "visual-studio-code"
  # ... all casks

  vscode "anthropic.claude-code"
  # ... all vscode extensions
end
```

## 6. Chezmoi Script Cleanup

| Script                                    | Action  | Reason                                          |
| ----------------------------------------- | ------- | ----------------------------------------------- |
| `run_once_before_install-gum.sh.tmpl`     | Remove  | gum installed by `brew bundle` during bootstrap |
| `run_once_after_setup-aws-sso.sh.tmpl`    | Keep    | Post-apply AWS prompt, needs `.aws.enabled`     |
| `run_onchange_after_restart-espanso.sh.tmpl` | Keep | Triggers on config changes, uses chezmoi hashes |

Update `.chezmoiignore` to ensure `dot_Brewfile` lands on all environments.

## 7. File Changes Summary

| File                                       | Change                                |
| ------------------------------------------ | ------------------------------------- |
| `dot_local/bin/executable_dotfiles-env`    | **New** — environment detection       |
| `dot_zprofile.tmpl` → `dot_zprofile`       | Drop template, add runtime guards     |
| `dot_zshrc.tmpl` → `dot_zshrc`            | Drop template, add runtime guards     |
| `dot_zshenv.tmpl` → `dot_zshenv`          | Drop template, add runtime guards     |
| `install.sh`                               | Rewrite with full bootstrap flow      |
| `Brewfile` → `dot_Brewfile`               | Add Ruby guards, three-tier structure |
| `run_once_before_install-gum.sh.tmpl`      | Delete                                |
| `.chezmoiignore`                           | Update for Brewfile path change       |
