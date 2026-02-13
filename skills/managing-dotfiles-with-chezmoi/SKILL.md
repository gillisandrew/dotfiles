---
name: managing-dotfiles-with-chezmoi
description: Use when editing, adding, or templating dotfiles managed by chezmoi, or when the user's home directory files live in ~/.local/share/chezmoi
---

# Managing Dotfiles with chezmoi

## Overview

chezmoi manages dotfiles by maintaining a **source state** (`~/.local/share/chezmoi/`) that gets applied to the home directory. Source files use naming conventions to control permissions, templating, and behavior.

## Key Commands

| Command | Purpose |
|---------|---------|
| `chezmoi cd` | Open shell in source directory |
| `chezmoi edit <file>` | Edit source version of a target file |
| `chezmoi diff` | Preview changes before applying |
| `chezmoi apply` | Apply source state to home directory |
| `chezmoi apply -v --dry-run` | Preview what `apply` would do |
| `chezmoi add <file>` | Start tracking a new file |
| `chezmoi re-add <file>` | Update source from manually-edited target |
| `chezmoi managed` | List all managed files |
| `chezmoi update` | `git pull` + `apply` (sync from remote) |
| `chezmoi data` | Show template data (debug templates) |

## Source File Naming

Prefixes and suffixes map source paths to target paths with attributes:

| Prefix/Suffix | Effect | Example |
|---------------|--------|---------|
| `dot_` | Adds `.` to target name | `dot_zshrc` → `.zshrc` |
| `private_` | Mode 0600 (file) or 0700 (dir) | `private_dot_ssh/` → `.ssh/` |
| `executable_` | Mode 0755 | `executable_script` → `script` |
| `readonly_` | Mode 0444 | `readonly_config` → `config` |
| `empty_` | Create empty file | `empty_dot_hushlogin` → `.hushlogin` |
| `modify_` | Modify script (see below) | `modify_config` modifies `config` |
| `.tmpl` suffix | Process as Go template | `dot_zshrc.tmpl` → `.zshrc` |

**Combine prefixes** in order: `private_dot_ssh/config.tmpl` → `~/.ssh/config` (mode 0600 from parent dir, templated).

**Critical:** `private_` on a directory makes its **contents** private. You don't need `private_` on files inside a `private_` directory.

## Templates

Templates use Go text/template syntax with chezmoi extensions.

**Available data:** `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.homeDir`, plus custom data from `.chezmoi.toml.tmpl`.

**OS conditionals:**
```
{{- if eq .chezmoi.os "darwin" }}
macos-specific content
{{- else }}
other content
{{- end }}
```

**Custom template data** (`.chezmoi.toml.tmpl`):
```
{{- $email = promptStringOnce . "email" "Git email" -}}
{{- $awsEnabled = promptBoolOnce . "aws.enabled" "Enable AWS?" true -}}
```
- `promptStringOnce`/`promptBoolOnce`: prompts on first `chezmoi init`, caches in `~/.config/chezmoi/chezmoi.toml`
- 4th param is default value
- Access in templates as `.email`, `.aws.enabled`

**Shared templates** live in `.chezmoitemplates/` and are invoked with:
```
{{ template "rc-common" "zsh" }}
```

## Script Types

Scripts live in `.chezmoiscripts/` (or source root).

| Prefix | Runs | Use case |
|--------|------|----------|
| `run_once_` | Once ever (by script hash) | Initial setup |
| `run_onchange_` | When script content changes | Homebrew bundle |
| `run_once_after_` | Once, after apply | Post-install setup |

**Triggering on external file changes** - use `.tmpl` suffix and embed file content in a comment so the script hash changes when the referenced file changes:
```bash
# File: .chezmoiscripts/run_onchange_brew-bundle-core.sh.tmpl
#!/bin/bash
# hash: {{ include "dot_Brewfile.d/core" | sha256sum }}
brew bundle --file=~/.Brewfile.d/core
```

## Modify Scripts

A `modify_` script receives the **current file contents on stdin** and writes the **new contents to stdout**. This preserves external changes while seeding defaults.

Pattern: check if file has content → preserve it; otherwise seed defaults.

```bash
contents="$(cat)"
if [ -n "$contents" ]; then
  printf '%s\n' "$contents"
else
  cat <<'EOF'
seed content here
EOF
fi
```

Modify scripts can also be `.tmpl` — template expansion happens first, then execution.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Editing target (`~/.zshrc`) directly | Use `chezmoi edit ~/.zshrc` or edit source then `chezmoi apply` |
| Adding `private_` prefix to files inside `private_` dir | Only the directory needs `private_` |
| Forgetting `-` in template tags causing extra whitespace | Use `{{-` and `-}}` to trim whitespace |
| Not quoting template data in TOML | Always use `{{ $var \| quote }}` in `.chezmoi.toml.tmpl` |
| `run_once_` script that needs to re-run | Use `run_onchange_` with content hash instead |

## Workflow: Adding a New Dotfile

1. `chezmoi add ~/.config/foo/config` — creates source file with correct naming
2. If templating needed: rename to `.tmpl`, add template logic
3. `chezmoi diff` — verify changes look right
4. `chezmoi apply -v` — apply and confirm
