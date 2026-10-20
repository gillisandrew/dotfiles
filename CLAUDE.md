# CLAUDE.md

## Architecture

- **Source directory:** this repo. **Target:** `~` (home). Never edit target files directly.
- **Shared templates:** `.chezmoitemplates/rc-common` (aliases, tool inits) and `profile-common` (PATH/toolchains). Both shells source these via `{{ template "rc-common" "zsh" }}`. Add aliases and shell functions here, not in individual shell rc files.
- **Config template:** `.chezmoi.toml.tmpl` prompts for email, AWS SSO, and Sentry DSN during `chezmoi init`.

## Conventions

- Commit messages: conventional commits format.
- Scripts in `dot_local/bin/`: use `executable_` prefix (e.g., `executable_get-disk-usage`). Name as `verb-noun` kebab-case. Approved verbs: `get`, `set`, `clean`, `refresh`, `generate`, `promote`, `extract`, `sync`.
- Aliases: short mnemonics (e.g., `c`, `ch`, `la`). Defined in `.chezmoitemplates/rc-common`.
- Shell functions: `snake_case`. Variables: `lower_snake_case`. Constants/env vars: `UPPER_SNAKE_CASE`.

## Common Mistakes

- Chezmoi prefix order matters — see the `kit:managing-dotfiles-with-chezmoi` skill for the full prefix table.
- OS-conditional ignores go in `.chezmoiignore` using template syntax.

## References

- Chezmoi skill (prefixes, templates, scripts): `kit:managing-dotfiles-with-chezmoi`, from the `claude-kit` plugin (github.com/gillisandrew/claude-kit)
- README: install, AWS workflow, naming conventions, glossary
