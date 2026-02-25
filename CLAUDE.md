# CLAUDE.md

## Architecture

- **Source directory:** this repo. **Target:** `~` (home). Never edit target files directly.
- **Shared templates:** `.chezmoitemplates/rc-common` (aliases, tool inits) and `profile-common` (PATH/toolchains). Both shells source these via `{{ template "rc-common" "zsh" }}`. Add aliases and shell functions here, not in individual shell rc files.
- **Brew roles:** `dot_Brewfile.d/` has per-role Brewfiles. `chezmoi apply` triggers `brew-bundle` via onchange script. See README for role descriptions.
- **Config template:** `.chezmoi.toml.tmpl` prompts for email, AWS SSO, and brew group selection during `chezmoi init`.

## Conventions

- Commit messages: conventional commits format.
- Scripts in `dot_local/bin/`: use `executable_` prefix (e.g., `executable_get-disk-usage`). Name as `verb-noun` kebab-case. Approved verbs: `get`, `set`, `clean`, `refresh`, `generate`, `promote`, `extract`, `sync`.
- Aliases: short mnemonics (e.g., `c`, `ch`, `la`). Defined in `.chezmoitemplates/rc-common`.
- Shell functions: `snake_case`. Variables: `lower_snake_case`. Constants/env vars: `UPPER_SNAKE_CASE`.

## Common Mistakes

- Chezmoi prefix order matters — see `skills/managing-dotfiles-with-chezmoi/SKILL.md` for the full prefix table.
- OS-conditional ignores go in `.chezmoiignore` using template syntax.

## References

- Chezmoi skill (prefixes, templates, scripts): `skills/managing-dotfiles-with-chezmoi/SKILL.md`
- README: install, brew roles, AWS workflow, naming conventions, glossary
