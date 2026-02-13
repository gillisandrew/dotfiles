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

### All Prefixes

| Prefix | Effect |
|--------|--------|
| `dot_` | Adds `.` to target name (`dot_zshrc` → `.zshrc`) |
| `private_` | Remove group/world permissions (0600 file, 0700 dir) |
| `executable_` | Add executable permissions (0755) |
| `readonly_` | Remove write permissions (0444) |
| `empty_` | Ensure file exists, even if empty |
| `create_` | Create file with contents only if it doesn't already exist (never overwrite) |
| `modify_` | Treat contents as script that modifies existing file (see below) |
| `remove_` | Remove the target file/symlink if it exists |
| `exact_` | On directories: remove anything inside not managed by chezmoi |
| `encrypted_` | Encrypt file in source state |
| `symlink_` | Create a symlink instead of regular file (contents = link target) |
| `literal_` | Stop parsing further prefixes (for filenames containing `_`) |
| `external_` | On directories: ignore attribute prefixes in children |
| `run_` | Treat contents as a script to run |
| `once_` | Only run script if not run successfully before (by hash) |
| `onchange_` | Re-run script when contents change (by hash + filename) |
| `before_` | Run script before updating destination |
| `after_` | Run script after updating destination |

### Prefix Order by Target Type

**Prefix order matters.** Each target type has a specific allowed prefix sequence:

| Target Type | Allowed Prefixes (in order) | Suffix |
|-------------|----------------------------|--------|
| **Directory** | `remove_`, `external_`, `exact_`, `private_`, `readonly_`, `dot_` | none |
| **Regular file** | `encrypted_`, `private_`, `readonly_`, `empty_`, `executable_`, `dot_` | `.tmpl` |
| **Create file** | `create_`, `encrypted_`, `private_`, `readonly_`, `empty_`, `executable_`, `dot_` | `.tmpl` |
| **Modify file** | `modify_`, `encrypted_`, `private_`, `readonly_`, `executable_`, `dot_` | `.tmpl` |
| **Remove** | `remove_`, `dot_` | none |
| **Script** | `run_`, `once_` or `onchange_`, `before_` or `after_` | `.tmpl` |
| **Symlink** | `symlink_`, `dot_` | `.tmpl` |

**Examples:**
- `encrypted_private_dot_env.tmpl` → `~/.env` (decrypted, mode 0600, templated)
- `create_dot_config/app/settings.json` → only created if missing
- `exact_dot_config/nvim/` → deletes unmanaged files inside `~/.config/nvim/`
- `symlink_dot_config/nvim.tmpl` → `~/.config/nvim` as symlink (target from template)
- `remove_dot_old-config` → deletes `~/.old-config` if it exists
- `run_onchange_before_install.sh.tmpl` → runs before apply, re-runs on content change

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

Scripts live in `.chezmoiscripts/` (or source root). Prefix format: `run_` + (`once_` or `onchange_`) + (`before_` or `after_`).

| Prefix Combo | Runs | Timing |
|--------------|------|--------|
| `run_once_before_` | Once (by hash) | Before applying files |
| `run_once_after_` | Once (by hash) | After applying files |
| `run_onchange_before_` | When content changes | Before applying files |
| `run_onchange_after_` | When content changes | After applying files |

Default timing is `before_` if neither `before_` nor `after_` is specified.

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
