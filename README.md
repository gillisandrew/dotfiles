# dotfiles

Chezmoi-managed dotfiles for macOS, GitHub Codespaces, and Linux hosts.

## Install

**New machine (one-liner):**

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply gillisandrew
```

On first run, chezmoi will prompt for:

| Prompt | Default | Notes |
|--------|---------|-------|
| Git email | *(none)* | Used in `.gitconfig` |
| Enable AWS SSO config | `true` | Set `false` to skip all AWS setup |
| AWS SSO session name | `zorg` | Only if AWS enabled |
| AWS SSO start URL | `https://<session>.awsapps.com/start` | Derived from session name |
| AWS SSO region | `us-east-1` | Only if AWS enabled |
| AWS SSO role name | `AdministratorAccess` | Only if AWS enabled |

To change answers later, edit `~/.config/chezmoi/chezmoi.toml` and run `chezmoi apply`.

**Full bootstrap** (Homebrew + chezmoi + packages):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gillisandrew/dotfiles/main/install.sh)"
```

`install.sh` installs Homebrew, chezmoi, applies dotfiles, seeds brew groups, and runs `brew bundle`.

**GitHub Codespaces:** Automatic — GitHub clones repos named `dotfiles` and runs `install.sh`. Only core packages are installed; AWS is disabled; email is read from `GIT_AUTHOR_EMAIL`.

## Brew groups

Packages in `~/.Brewfile` are organized into opt-in groups. The file `~/.config/brew-groups` controls which groups are installed (one group name per line). The `core` group is always included regardless.

| Group | Description |
|-------|-------------|
| `core` | Essential CLI tools (atuin, bat, fzf, gh, starship, etc.) |
| `dev` | Language toolchains and dev CLIs (go, rust, uv, bun, etc.) |
| `ops` | Cloud and infrastructure tools (awscli, pandoc, ncdu, etc.) |
| `macos_cli` | macOS-specific CLI tools (trash, yubico-piv-tool, etc.) |
| `macos_apps` | macOS desktop applications (casks) |
| `go_tools` | Go development tools (gopls) |

In devcontainers, only `core` is installed regardless of the config file.

**Managing groups:**

```bash
# Interactive picker (uses gum if available, plain text fallback)
brew-groups

# Pick groups and immediately install
brew-groups --apply

# Or edit directly
echo -e "core\ndev\nops" > ~/.config/brew-groups
brew bundle --file=~/.Brewfile
```

## Shell setup

Both **zsh** and **bash** get full configuration. Login env (PATH, toolchains, Homebrew) lives in `.zprofile` / `.profile`. Interactive config (prompt, aliases, functions, tool inits) lives in `.zshrc` / `.bashrc`. A shared `dotfiles-env` script detects the environment (`macos`, `devcontainer`, or `remote-linux`).

Bash uses the standard `.bash_profile` → `.profile` + `.bashrc` sourcing chain, so bash-based environments (Codespaces) get the same setup as zsh.

All tool initializations (starship, atuin, zoxide, carapace) are guarded with `command -v` checks — missing tools are silently skipped.

## AWS SSO workflow

The `~/.aws/config` file is **not** stored statically — it's generated at runtime to keep account IDs out of version control.

1. `chezmoi apply` seeds `~/.aws/config` with the SSO session block (from template data)
2. Run `refresh-zorg-profiles` to authenticate and populate account profiles
3. The modify script preserves the populated file on subsequent `chezmoi apply` runs

To re-generate profiles (e.g. after accounts are added/removed), just run `refresh-zorg-profiles` again.

## Scripts (`~/.local/bin/`)

| Command | Description |
|---------|-------------|
| `brew-groups` | Interactive brew group picker. `--apply` to install after selecting. |
| `clean-deps` | Remove build artifacts (`node_modules`, `dist`, `.venv`, etc.). Dry-run by default; `--force` to delete. |
| `clean-package-cache` | Purge caches for npm, pip, uv, go, cargo, terraform, and more. Dry-run by default; `--force` to execute. |
| `dotfiles-env` | Detect environment (`DOTFILES_OS`, `DOTFILES_ENV`). Sourced by shell configs. |
| `refresh-zorg-profiles` | Log into AWS SSO, enumerate org accounts, and regenerate `~/.aws/config`. |
| `starship-claude` | Starship status line integration for Claude Code sessions. |

Scripts use [gum](https://github.com/charmbracelet/gum) for styled output, spinners, and prompts when available, with plain-text fallbacks.

## Naming conventions

### Approved verbs

| Verb | Meaning | Use when... |
|------|---------|-------------|
| `get` | Query and display information (read-only) | Fetching status, printing reports |
| `set` | Write or configure a value | Updating a setting or state |
| `clean` | Remove generated artifacts or caches | Freeing disk space, resetting build state |
| `refresh` | Regenerate from an upstream source of truth | Token rotation, SSO profile sync |
| `generate` | Produce new output from input | Transforming files, creating derived content |
| `promote` | Move to a higher-priority state | Draft-to-published workflows |
| `extract` | Unpack a compressed archive | Decompressing tarballs, zips |
| `sync` | Bidirectional reconciliation | *(reserved for future use)* |

### Command names

| Context | Convention | Examples |
|---------|-----------|----------|
| Scripts in `~/.local/bin/` | `verb-noun` in `kebab-case` | `clean-deps`, `brew-groups` |
| Inline shell functions | `verb_noun` in `snake_case` | `refresh_github_token()`, `extract()` |
| Aliases | short mnemonic | `espansoconfig` |

### Chezmoi source files

| Attribute | Convention | Examples |
|-----------|-----------|----------|
| Prefixes | Per chezmoi spec | `dot_`, `private_`, `executable_`, `modify_`, `run_once_after_` |
| Suffixes | `.tmpl` for templates | `dot_zshrc.tmpl`, `modify_private_config.tmpl` |

### Shell code (inside scripts)

| Element | Convention | Examples |
|---------|-----------|----------|
| Functions | `snake_case` | `process_file()`, `create_temp_config()` |
| Local variables | `lower_snake_case` | `temp_config`, `access_token` |
| Constants / env vars | `UPPER_SNAKE_CASE` | `AWS_SSO_SESSION`, `DRY_RUN` |
| Exported vars | `UPPER_SNAKE_CASE` | `ESPANSO_CONFIG_DIR`, `EDITOR` |

### Chezmoi template data

| Key | Convention | Examples |
|-----|-----------|----------|
| Top-level | `lower_snake_case` | `email`, `codespaces` |
| Nested sections | `[data.<group>]` | `[data.aws]` |
| Section keys | `lower_snake_case` | `sso_session`, `sso_start_url` |

## Glossary

| Term | Meaning |
|------|---------|
| **source directory** | `~/.local/share/chezmoi` — the git repo. Files here use chezmoi naming prefixes. |
| **target directory** | `~` (home) — where chezmoi writes managed files. |
| **template** (`.tmpl`) | A file processed by chezmoi's Go template engine before writing. Has access to `.chezmoi.*` and `[data]` variables. |
| **modify script** (`modify_`) | A script that receives the current file contents on stdin and outputs the desired contents. Used when chezmoi should seed a file but not overwrite later changes. |
| **run script** (`run_`) | A script executed during `chezmoi apply`. Variants: `run_once_` (first time only), `run_onchange_` (when content hash changes). |
| **`before_` / `after_`** | Ordering attributes for run scripts. `run_once_after_` runs after file updates; `run_onchange_before_` runs before. |
| **`private_`** | Chezmoi prefix that sets file/directory permissions to `0600`/`0700`. |
| **`executable_`** | Chezmoi prefix that sets the executable bit (`0755`). |
| **`dot_`** | Chezmoi prefix that maps to a leading `.` in the target name. |
| **`promptStringOnce`** | Chezmoi template function that prompts the user once during `chezmoi init` and caches the answer in `chezmoi.toml`. |
| **`.chezmoiscripts/`** | Directory for lifecycle scripts that don't create corresponding directories in the target. |
| **`.chezmoiignore`** | Patterns for files in the source that chezmoi should not manage. Supports templates for conditional ignoring. |
| **`gum`** | [charmbracelet/gum](https://github.com/charmbracelet/gum) — a CLI tool for styled output, spinners, confirmation prompts, and tables. All scripts fall back to plain text when gum is absent. |

## Daily workflow

```bash
# Edit a dotfile (opens the source copy)
chezmoi edit ~/.zshrc

# Preview what would change
chezmoi diff

# Apply changes to home directory
chezmoi apply

# Commit and push
chezmoi cd
git add -A && git commit -m "update zshrc" && git push
```

## Pull updates on another machine

```bash
chezmoi update
```
