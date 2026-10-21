# Complete File Map

All managed targets grouped by category.

```mermaid
flowchart LR
    subgraph source ["Source (chezmoi)"]
        direction TB
        S1["Shell Configs"]
        S2["Git Configs"]
        S4["SSH Config"]
        S5["AWS Config"]
        S6["App Configs"]
        S7["Utility Scripts"]
        S8["Run Scripts"]
        S9["Claude Code"]
    end

    subgraph target ["Target (~/)"]
        direction TB
        T1[".zshenv, .zprofile, .zshrc<br/>.bash_profile, .profile, .bashrc"]
        T2[".gitconfig, .gitignore,<br/>.gitattributes"]
        T4[".ssh/config,<br/>.ssh/BW-*.pub"]
        T5[".aws/config"]
        T6[".config/atuin/config.toml<br/>.config/espanso/**<br/>.config/gh/config.yml<br/>.config/ghostty/config"]
        T7[".local/bin/dotfiles-env<br/>.local/bin/dotfiles-motd-fast<br/>.local/bin/refresh-zorg-profiles<br/>...7 more scripts"]
        T8["(no files — side effects only)<br/>brew bundle, mise install,<br/>pre-commit install, Claude MCP servers"]
        T9[".claude/settings.json (merged)<br/>.claude/CLAUDE.md"]
    end

    S1 --> T1
    S2 --> T2
    S4 --> T4
    S5 --> T5
    S6 --> T6
    S7 --> T7
    S8 --> T8
    S9 --> T9
```
