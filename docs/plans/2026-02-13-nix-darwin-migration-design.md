# Migration: chezmoi to nix-darwin + home-manager

## Summary

Replace chezmoi with nix-darwin (macOS system management) and home-manager (user config), using the [bgub/nix-macos-starter](https://github.com/bgub/nix-macos-starter) as a starting point. Language toolchains move to per-project flakes loaded via nix-direnv.

## Decisions

- **macOS:** nix-darwin + home-manager (as a darwin module)
- **Linux/devcontainers:** standalone home-manager (shared `home/` modules)
- **Language toolchains:** per-project `flake.nix` + nix-direnv, not system-level. Use `nix flake init --template` from FlakeHub dev-templates.
- **Homebrew:** core casks (GUI apps) + minimal brews only. CLI tools migrate to nixpkgs.
- **Scripts:** migrate `starship-claude` only. Others revisited later.
- **Shell:** zsh only. Drop bash support, command-not-found handler, shell-init caching.
- **AWS:** custom nix options for SSO config, set per-host.
- **chezmoi:** kept in Brewfile during transition.

## Repository Structure

```
~/.config/nix/
├── flake.nix
├── flake.lock
├── darwin/
│   ├── default.nix                 # nix settings, shell, PATH, nix-homebrew
│   ├── homebrew.nix                # Core casks + minimal brews
│   └── settings.nix                # macOS defaults
├── home/
│   ├── default.nix                 # Imports all home modules
│   ├── shell.nix                   # Zsh, starship, atuin, zoxide, fzf, direnv
│   ├── git.nix                     # Git config, aliases, attributes, ignore
│   ├── ssh.nix                     # SSH config, identities, multiplexing
│   ├── packages.nix                # Always-on CLI tools (bat, ripgrep, gh, etc.)
│   ├── ghostty.nix                 # Terminal config + themes
│   ├── espanso.nix                 # Text expansion
│   ├── atuin.nix                   # Shell history
│   ├── vscode.nix                  # Profiles and extensions
│   ├── aws.nix                     # Custom options for AWS SSO config
│   └── scripts/
│       └── starship-claude         # Claude Code starship module
├── hosts/
│   └── AG-MACBOOK-1/
│       └── configuration.nix       # Hostname, user, host-specific overrides
└── lib/
    └── options.nix                 # Custom option declarations
```

## Flake Configuration

### Inputs

- `nixpkgs` (unstable)
- `nix-darwin`
- `home-manager`
- `nix-homebrew`

### Outputs

- `darwinConfigurations."AG-MACBOOK-1"` — full macOS: system + home-manager
- `homeConfigurations."gillisandrew"` — standalone home-manager for Linux/devcontainers

## darwin/ Modules

### default.nix

- Enable flakes and `nix-command`
- Set zsh as default shell
- Add `/opt/homebrew/bin` to system PATH
- Configure nix-homebrew (auto-install, agree to Xcode license)
- Wire home-manager as a nix-darwin module
- Install nix-direnv system-wide

### homebrew.nix

Core only. `onActivation.cleanup = "uninstall"` (not `"zap"` — avoids destructive defaults per upstream issue #4).

**Brews:** chezmoi, gum, starship

**Casks:** bitwarden, claude, docker-desktop, espanso, figma, ghostty, logi-options+, microsoft-edge, microsoft-office, nordvpn, obsidian, onedrive, pearcleaner, spotify, steam, temurin, visual-studio-code, whatsapp, windows-app, yubico-authenticator, anki

### settings.nix

- Touch ID for sudo
- Finder: show hidden files, extensions, full path in title
- Disable auto-correct, auto-capitalization

## home/ Modules

### shell.nix

Declarative via home-manager programs:

- `programs.zsh.enable` — completions, autosuggestions, syntax-highlighting
- `programs.starship.enable` — prompt config
- `programs.atuin.enable` — shell history
- `programs.zoxide.enable` — smart cd
- `programs.fzf.enable` — fuzzy finder
- `programs.bat.enable` — cat replacement
- `programs.direnv.enable` + `nix-direnv.enable` — per-project flake loading

Shell `initExtra` for:
- Bitwarden SSH agent socket (`SSH_AUTH_SOCK`)
- `starship-claude` integration
- Aliases (cat→bat, navigation, nix-switch)

Eliminates: shell-init caching, dotfiles-env, command-not-found handler, bash support.

### git.nix

Via `programs.git`:
- SSH signing (macOS only via `lib.mkIf`)
- VSCode as editor/difftool on macOS, vim on Linux
- Rebase by default, auto-setup remote, zdiff3, histogram diff
- Aliases: s, lg, undo, amend, new
- Inline gitattributes and gitignore

### ssh.nix

Via `programs.ssh`:
- Protocol 2, IdentitiesOnly, strict host checking
- ControlMaster multiplexing
- Default identity (BW-2026-02-10-AUTH.pub) on macOS
- GitHub-specific match block

### packages.nix

Always-on CLI tools via `home.packages`:
- From current cli role: bat, curlie, fzf, gh, htop, ripgrep, yq, zoxide
- From current ops role: fx, ncdu, openssh, uutils-coreutils
- From current dev role: pre-commit, gitleaks

### ghostty.nix

Via `xdg.configFile`:
- FiraCode Nerd Font, size 16
- Catppuccin Frappe/Latte themes
- Dracula theme file

### espanso.nix

Via `xdg.configFile`:
- Config and match files
- Personal matches stay as untracked local file

### vscode.nix

Via `programs.vscode` or `xdg.configFile`:
- Extension lists per profile (core, web_dev, python, shell_infra)

### aws.nix

Custom options:
```nix
options.myConfig.aws = {
  enable = mkEnableOption "AWS SSO configuration";
  ssoSession = mkOption { type = str; default = "zorg"; };
  ssoRegion = mkOption { type = str; default = "us-east-1"; };
  ssoRoleName = mkOption { type = str; default = "AdministratorAccess"; };
};
```

When enabled, generates `~/.aws/config` with SSO session block.

## Platform Conditionals

Shared `home/` modules use `lib.mkIf pkgs.stdenv.isDarwin` for:
- SSH identity and Bitwarden agent
- Ghostty, espanso, vscode profiles
- Git SSH signing, VSCode as editor

Linux gets: shell, git (basic), packages, atuin, aws.

## Bootstrap

### macOS (fresh machine)

1. Install Nix via Determinate Systems installer
2. `git clone <repo> ~/.config/nix`
3. `nix run nix-darwin -- switch --flake ~/.config/nix#AG-MACBOOK-1`
4. Subsequent: `darwin-rebuild switch --flake ~/.config/nix#AG-MACBOOK-1` (or `nix-switch` alias)

### Linux/devcontainers

1. Install Nix
2. `nix run home-manager -- switch --flake ~/.config/nix#gillisandrew`

## Known Gotchas (from upstream issues)

1. **#4 — Destructive Homebrew defaults:** Use `"uninstall"` not `"zap"` for cleanup.
2. **#1 — Bootstrap chicken-egg:** First run must use `nix run nix-darwin --` since `darwin-rebuild` doesn't exist yet.
3. **#3 — No license:** Not a concern; we use the repo as inspiration only.
