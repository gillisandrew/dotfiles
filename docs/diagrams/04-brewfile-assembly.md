# Brewfile Assembly

The `dot_Brewfile.tmpl` dynamically composes `~/.Brewfile` from fragments based on selected brew groups.

```mermaid
flowchart LR
    subgraph fragments ["dot_Brewfile.d/"]
        Core["core<br/>(always included)"]
        CLI["cli"]
        Dev["dev"]
        Go["go"]
        JS["js"]
        Python["python"]
        Rust["rust"]
        Ops["ops"]
        MacCLI["macos_cli"]
        MacApps["macos_apps"]
        VSCode["vscode"]
        GoVS["go.vscode"]
        JSVS["js.vscode"]
    end

    subgraph selection ["brew.* booleans<br/>(chezmoi.toml)"]
        BG["brew.cli = true<br/>brew.dev = false<br/>brew.go = true<br/>brew.vscode = true<br/>..."]
    end

    subgraph assembly ["dot_Brewfile.tmpl"]
        T1["1. Always include core"]
        T2["2. For each group:<br/>include if brew.&lt;group&gt; = true"]
        T3["3. If brew.vscode = true:<br/>include *.vscode overlays<br/>for enabled groups"]
    end

    subgraph output ["~/.Brewfile"]
        OUT["# core<br/>brew chezmoi, git, gum...<br/># cli<br/>brew atuin, bat, fzf...<br/># go<br/>brew go, gopls<br/># vscode (core)<br/>vscode claude-code...<br/># vscode (go)<br/>vscode go-template"]
    end

    fragments --> assembly
    selection --> assembly
    assembly --> output
```

## Change Detection

Changing brew selections in `chezmoi.toml` triggers automatic package sync on next apply.

```mermaid
sequenceDiagram
    participant User
    participant chezmoi as chezmoi apply
    participant Script as run_onchange_after_<br/>brew-install.sh.tmpl
    participant Brew as brew bundle

    User->>chezmoi: Change brew.cli=false<br/>in chezmoi.toml
    chezmoi->>chezmoi: Render script template
    Note over chezmoi: Comment line changes:<br/>"# brew: cli=false dev=true go=true..."<br/>→ new content hash
    chezmoi->>Script: Hash changed → re-run
    Script->>Brew: brew bundle --global
    Brew-->>Script: Install new packages
    Script->>Brew: brew bundle cleanup --global --force
    Brew-->>Script: Remove deselected packages
```
