# Chezmoi Dotfiles — Data Flow Diagrams

Mermaid diagrams documenting the init and apply workflows for this dotfiles repository.

## Diagrams

| # | Document | Description |
|---|----------|-------------|
| 1 | [Bootstrap](01-bootstrap.md) | `install.sh` — from bare machine to configured system |
| 2 | [Init Workflow](02-init.md) | `chezmoi init` — config generation, prompts, Codespaces detection |
| 3 | [Apply Workflow](03-apply.md) | `chezmoi apply` — ignore evaluation, file updates, run scripts |
| 4 | [Brewfile Assembly](04-brewfile-assembly.md) | Template composition from fragments + change detection |
| 5 | [Shell Config](05-shell-config.md) | Zsh/Bash inheritance via shared templates |
| 6 | [AWS Config](06-aws-config.md) | Conditional SSO setup with seed-once pattern |
| 7 | [File Map](07-file-map.md) | All source → target mappings by category |
