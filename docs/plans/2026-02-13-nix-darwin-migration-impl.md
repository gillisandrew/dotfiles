# Nix-Darwin + Home-Manager Migration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate dotfiles management from chezmoi to nix-darwin + home-manager, with a new repo at `~/.config/nix/`.

**Architecture:** nix-darwin manages macOS system settings and wires in home-manager as a module. home-manager manages all user-level config (shell, git, ssh, apps). A standalone `homeConfigurations` output supports Linux/devcontainers. Language toolchains live in per-project flakes via nix-direnv.

**Tech Stack:** Nix flakes, nix-darwin, home-manager, nix-homebrew, nix-direnv

**Reference files:**
- Design doc: `docs/plans/2026-02-13-nix-darwin-migration-design.md`
- Starter repo (cloned): `/tmp/nix-macos-starter/`
- Current chezmoi source: `/Users/gillisandrew/.local/share/chezmoi/`

---

### Task 1: Initialize the repository and flake.nix

**Files:**
- Create: `~/.config/nix/flake.nix`
- Create: `~/.config/nix/.gitignore`

**Step 1: Create the directory and initialize git**

```bash
mkdir -p ~/.config/nix
cd ~/.config/nix
git init
```

**Step 2: Create `.gitignore`**

```
result
.direnv
```

**Step 3: Write `flake.nix`**

```nix
{
  description = "gillisandrew system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      self,
      darwin,
      nixpkgs,
      home-manager,
      nix-homebrew,
      ...
    }@inputs:
    let
      primaryUser = "gillisandrew";
    in
    {
      darwinConfigurations."AG-MACBOOK-1" = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./darwin
          ./hosts/AG-MACBOOK-1/configuration.nix
        ];
        specialArgs = { inherit inputs self primaryUser; };
      };

      homeConfigurations."gillisandrew" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        modules = [ ./home ];
        extraSpecialArgs = { inherit inputs self; primaryUser = "gillisandrew"; };
      };
    };
}
```

**Step 4: Commit**

```bash
cd ~/.config/nix
git add flake.nix .gitignore
git commit -m "feat: initialize flake with darwin and home-manager outputs"
```

---

### Task 2: Create darwin/ modules (system, homebrew, settings)

**Files:**
- Create: `~/.config/nix/darwin/default.nix`
- Create: `~/.config/nix/darwin/homebrew.nix`
- Create: `~/.config/nix/darwin/settings.nix`

**Step 1: Write `darwin/default.nix`**

Adapts `/tmp/nix-macos-starter/darwin/default.nix`. Key differences from starter: adds `nix-direnv` to system packages, keeps `nix.enable = false` for Determinate installer.

```nix
{
  pkgs,
  inputs,
  self,
  primaryUser,
  ...
}:
{
  imports = [
    ./homebrew.nix
    ./settings.nix
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    enable = false; # using determinate installer
  };

  nixpkgs.config.allowUnfree = true;

  nix-homebrew = {
    user = primaryUser;
    enable = true;
    autoMigrate = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${primaryUser} = {
      imports = [
        ../home
      ];
    };
    extraSpecialArgs = {
      inherit inputs self primaryUser;
    };
  };

  system.primaryUser = primaryUser;
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;
  };

  environment = {
    systemPath = [
      "/opt/homebrew/bin"
    ];
    pathsToLink = [ "/Applications" ];
    systemPackages = with pkgs; [
      nix-direnv
    ];
  };
}
```

**Step 2: Write `darwin/homebrew.nix`**

Core GUI apps only. Uses `"uninstall"` not `"zap"` (upstream issue #4).

```nix
{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "uninstall";
    };

    caskArgs.no_quarantine = true;
    global.brewfile = true;

    brews = [
      "chezmoi"
      "gum"
    ];

    casks = [
      "anki"
      "bitwarden"
      "claude"
      "docker-desktop"
      "espanso"
      "figma"
      "ghostty"
      "logi-options+"
      "microsoft-edge"
      "microsoft-excel"
      "microsoft-outlook"
      "microsoft-powerpoint"
      "microsoft-word"
      "nordvpn"
      "obsidian"
      "onedrive"
      "pearcleaner"
      "spotify"
      "steam"
      "temurin"
      "visual-studio-code"
      "whatsapp"
      "windows-app"
      "yubico-authenticator"
    ];
  };
}
```

**Step 3: Write `darwin/settings.nix`**

macOS system defaults from starter + current chezmoi setup.

```nix
{ self, ... }:
{
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    stateVersion = 6;
    configurationRevision = self.rev or self.dirtyRev or null;

    startup.chime = false;

    defaults = {
      loginwindow = {
        GuestEnabled = false;
        DisableConsoleAccess = true;
      };

      finder = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        _FXShowPosixPathInTitle = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };

      NSGlobalDomain = {
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
      };
    };
  };
}
```

**Step 4: Commit**

```bash
cd ~/.config/nix
git add darwin/
git commit -m "feat: add darwin modules (system, homebrew, settings)"
```

---

### Task 3: Create home/default.nix and home/packages.nix

**Files:**
- Create: `~/.config/nix/home/default.nix`
- Create: `~/.config/nix/home/packages.nix`

**Step 1: Write `home/default.nix`**

Imports all home modules. Initially just packages — other modules added in subsequent tasks.

```nix
{ primaryUser, ... }:
{
  imports = [
    ./packages.nix
    ./shell.nix
    ./git.nix
    ./ssh.nix
    ./ghostty.nix
    ./espanso.nix
    ./vscode.nix
    ./aws.nix
  ];

  home = {
    username = primaryUser;
    stateVersion = "25.05";
    file.".hushlogin".text = "";
  };
}
```

**Step 2: Write `home/packages.nix`**

Always-on CLI tools migrated from chezmoi Brewfile.d roles (cli, ops, dev). These were previously installed via `brew bundle` but now come from nixpkgs.

```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # CLI essentials (from Brewfile.d/cli)
    curlie
    fzf
    gh
    htop
    ripgrep
    yq
    jq

    # Ops tools (from Brewfile.d/ops)
    fx
    ncdu
    uutils-coreutils

    # Dev tools (from Brewfile.d/dev)
    pre-commit
    gitleaks
    git-filter-repo
    tmux

    # Nix tools
    nil
    nixfmt-rfc-style

    # Fonts
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
  ];
}
```

**Step 3: Commit**

```bash
cd ~/.config/nix
git add home/default.nix home/packages.nix
git commit -m "feat: add home-manager entry point and CLI packages"
```

---

### Task 4: Create home/shell.nix

**Files:**
- Create: `~/.config/nix/home/shell.nix`

**Step 1: Write `home/shell.nix`**

Replaces: `dot_zshrc.tmpl`, `dot_zprofile.tmpl`, `rc-common`, `profile-common` templates. Home-manager's program modules handle init script generation — no more manual caching.

```nix
{ pkgs, lib, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      la = "ls -la";
      cat = "bat";
      curl = "curlie";
      nix-switch = "darwin-rebuild switch --flake ~/.config/nix";
    };

    initExtra = lib.mkMerge [
      # Bitwarden SSH agent (macOS only — guarded at runtime)
      ''
        if [[ -S "$HOME/.bitwarden-ssh-agent.sock" ]]; then
          export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
        fi
      ''
      # Shell functions
      ''
        extract() {
          if [ -f "$1" ]; then
            case $1 in
              *.tar.bz2)   tar xjf "$1"     ;;
              *.tar.gz)    tar xzf "$1"     ;;
              *.bz2)       bunzip2 "$1"     ;;
              *.rar)       unrar e "$1"     ;;
              *.gz)        gunzip "$1"      ;;
              *.tar)       tar xf "$1"      ;;
              *.tbz2)      tar xjf "$1"     ;;
              *.tgz)       tar xzf "$1"     ;;
              *.zip)       unzip "$1"       ;;
              *.Z)         uncompress "$1"  ;;
              *.7z)        7z x "$1"        ;;
              *)           echo "'$1' cannot be extracted via extract()" ;;
            esac
          else
            echo "'$1' is not a valid file"
          fi
        }
      ''
    ];
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[λ](bold green)";
        error_symbol = "[λ](bold red)";
      };
    };
  };

  programs.atuin = {
    enable = true;
    settings = {
      enter_accept = true;
      sync.records = true;
    };
  };

  programs.zoxide = {
    enable = true;
    options = [ "--cmd" "cd" ];
  };

  programs.fzf.enable = true;

  programs.bat.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
```

**Step 2: Commit**

```bash
cd ~/.config/nix
git add home/shell.nix
git commit -m "feat: add shell config (zsh, starship, atuin, zoxide, direnv)"
```

---

### Task 5: Create home/git.nix

**Files:**
- Create: `~/.config/nix/home/git.nix`

**Step 1: Write `home/git.nix`**

Translates `dot_gitconfig.tmpl`. Platform conditionals use `pkgs.stdenv.isDarwin` instead of chezmoi's `{{ .chezmoi.os }}`.

```nix
{ pkgs, lib, primaryUser, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  programs.git = {
    enable = true;
    userName = "Andrew Gillis";
    userEmail = "gillis.andrew@gmail.com";

    lfs.enable = true;

    signing = lib.mkIf isDarwin {
      key = "key::ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBU9/f1kZUWBLDJmQDW5v3WQBxWi5Ijrog0HE6hOceAP";
      format = "ssh";
      signByDefault = true;
    };

    ignores = [
      ".DS_Store"
    ];

    attributes = [
      "* text=auto eol=lf"
      "*.js text"
      "*.jsx text"
      "*.ts text"
      "*.tsx text"
      "*.svelte text"
      "*.json text"
      "*.css text"
      "*.scss text"
      "*.html text"
      "*.xml text"
      "*.svg text"
      "*.yml text"
      "*.yaml text"
      "*.toml text"
      "*.md text diff=markdown"
      "*.sh text eol=lf"
      "*.bash text eol=lf"
      "*.zsh text eol=lf"
      "*.png binary"
      "*.jpg binary"
      "*.jpeg binary"
      "*.gif binary"
      "*.ico binary"
      "*.webp binary"
      "*.woff binary"
      "*.woff2 binary"
      "*.ttf binary"
      "*.pdf binary"
      "*.zip binary"
      "*.tar binary"
      "*.gz binary"
      "package-lock.json linguist-generated=true merge=ours"
      "yarn.lock linguist-generated=true merge=ours"
      "pnpm-lock.yaml linguist-generated=true merge=ours"
      "bun.lockb binary linguist-generated=true merge=ours"
      "*.min.js linguist-generated=true"
      "*.min.css linguist-generated=true"
      "dist/** linguist-generated=true"
      "build/** linguist-generated=true"
      "*.svelte diff=html linguist-language=Svelte"
    ];

    aliases = {
      s = "status -sb";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      undo = "reset --soft HEAD^";
      amend = "commit --amend --no-edit";
      new = "log main..HEAD --oneline";
    };

    extraConfig = {
      github.user = primaryUser;
      init.defaultBranch = "main";
      core.editor = if isDarwin then "code --wait" else "vim";
      pull.rebase = true;
      push = {
        default = "current";
        autoSetupRemote = true;
      };
      fetch = {
        prune = true;
        prunetags = true;
      };
      rebase = {
        autoStash = true;
        autoSquash = true;
      };
      merge.conflictStyle = "zdiff3";
      log.date = "iso";
      diff = {
        algorithm = "histogram";
        colorMoved = "default";
      } // lib.optionalAttrs isDarwin {
        tool = "vscode";
      };
    } // lib.optionalAttrs isDarwin {
      "difftool \"vscode\"".cmd = "code --wait --diff $LOCAL $REMOTE";
    };
  };
}
```

**Step 2: Commit**

```bash
cd ~/.config/nix
git add home/git.nix
git commit -m "feat: add git config with signing, aliases, and attributes"
```

---

### Task 6: Create home/ssh.nix

**Files:**
- Create: `~/.config/nix/home/ssh.nix`

**Step 1: Write `home/ssh.nix`**

Translates `private_dot_ssh/config.tmpl`.

```nix
{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  programs.ssh = {
    enable = true;

    extraConfig = ''
      Protocol 2
      IdentitiesOnly yes
      PubkeyAuthentication yes
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      ChallengeResponseAuthentication no
      StrictHostKeyChecking ask
      HashKnownHosts yes
      VerifyHostKeyDNS yes
      ServerAliveInterval 60
      ServerAliveCountMax 3
      TCPKeepAlive no
      ControlMaster auto
      ControlPersist 10m
      ControlPath %d/.ssh/control-%C
      Compression yes
      LogLevel VERBOSE
    '' + lib.optionalString isDarwin ''
      IdentityFile ~/.ssh/BW-2026-02-10-AUTH.pub
    '';

    matchBlocks = {
      "github.com" = {
        extraOptions = {
          CheckHostIP = "no";
          VerifyHostKeyDNS = "no";
        };
      };
    };
  };
}
```

**Step 2: Commit**

```bash
cd ~/.config/nix
git add home/ssh.nix
git commit -m "feat: add SSH config with hardening and multiplexing"
```

---

### Task 7: Create home/ghostty.nix

**Files:**
- Create: `~/.config/nix/home/ghostty.nix`

**Step 1: Write `home/ghostty.nix`**

Places config files via `xdg.configFile`. Only active on macOS.

```nix
{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  xdg.configFile = lib.mkIf isDarwin {
    "ghostty/config" = {
      text = ''
        font-family = "FiraCode Nerd Font Mono"
        font-size = 16
        window-padding-x = 6
        window-padding-y = 3
        theme = dark:Catppuccin Frappe,light:Catppuccin Latte
        macos-auto-secure-input = true
        macos-icon = blueprint
        keybind = shift+enter=text:\n
        macos-titlebar-style = tabs
        macos-titlebar-proxy-icon = hidden
        window-inherit-working-directory = true
      '';
    };

    "ghostty/themes/dracula" = {
      text = ''
        palette = 0=#21222c
        palette = 1=#ff5555
        palette = 2=#50fa7b
        palette = 3=#f1fa8c
        palette = 4=#bd93f9
        palette = 5=#ff79c6
        palette = 6=#8be9fd
        palette = 7=#f8f8f2
        palette = 8=#6272a4
        palette = 9=#ff6e6e
        palette = 10=#69ff94
        palette = 11=#ffffa5
        palette = 12=#d6acff
        palette = 13=#ff92df
        palette = 14=#a4ffff
        palette = 15=#ffffff
        background = #282a36
        foreground = #f8f8f2
        cursor-color = #f8f8f2
        cursor-text = #282a36
        selection-foreground = #f8f8f2
        selection-background = #44475a
      '';
    };
  };
}
```

**Step 2: Commit**

```bash
cd ~/.config/nix
git add home/ghostty.nix
git commit -m "feat: add Ghostty terminal config and Dracula theme"
```

---

### Task 8: Create home/espanso.nix

**Files:**
- Create: `~/.config/nix/home/espanso.nix`

**Step 1: Write `home/espanso.nix`**

Config and base matches. Personal matches (`match/personal.yml`) stay as a local untracked file.

```nix
{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  xdg.configFile = lib.mkIf isDarwin {
    "espanso/config/default.yml" = {
      text = ''
        search_shortcut: OPTION+SPACE
        search_trigger: :.
      '';
    };

    "espanso/match/base.yml" = {
      text = builtins.readFile ./files/espanso-base.yml;
    };
  };
}
```

Also create the espanso base match file verbatim (it's large and has YAML that's easier to keep as a file):

- Create: `~/.config/nix/home/files/espanso-base.yml`

Copy the contents of `/Users/gillisandrew/.local/share/chezmoi/private_dot_config/espanso/match/base.yml` verbatim into this file.

**Step 2: Commit**

```bash
cd ~/.config/nix
git add home/espanso.nix home/files/espanso-base.yml
git commit -m "feat: add Espanso text expansion config"
```

---

### Task 9: Create home/vscode.nix

**Files:**
- Create: `~/.config/nix/home/vscode.nix`

**Step 1: Write `home/vscode.nix`**

Manages VSCode extensions declaratively. Profile export files are complex and better managed by VSCode itself — we just ensure extensions are installed.

```nix
{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  programs.vscode = lib.mkIf isDarwin {
    enable = true;
    # Don't let home-manager manage the binary — it's installed via Homebrew cask
    package = pkgs.emptyDirectory;
    mutableExtensionsDir = true;
    profiles.default.extensions = with pkgs.vscode-marketplace; [ ];
  };

  # GitHub CLI config
  xdg.configFile."gh/config.yml" = {
    text = ''
      version: 1
      git_protocol: ssh
      prompt: enabled
      prefer_editor_prompt: disabled
      pager:
      aliases:
          co: pr checkout
      color_labels: disabled
      spinner: enabled
    '';
  };
}
```

> **Note:** VSCode extension management via nix is fragile — extensions update frequently and many aren't in nixpkgs. Consider whether to manage extensions via nix at all, or just track profiles as config files. The gh config is placed here for now but could move to its own module later.

**Step 2: Commit**

```bash
cd ~/.config/nix
git add home/vscode.nix
git commit -m "feat: add VSCode and GitHub CLI config"
```

---

### Task 10: Create home/aws.nix with custom options

**Files:**
- Create: `~/.config/nix/home/aws.nix`

**Step 1: Write `home/aws.nix`**

Custom nix options that generate `~/.aws/config` when enabled. Values are set in host configuration.

```nix
{ config, lib, ... }:
let
  cfg = config.myConfig.aws;
in
{
  options.myConfig.aws = {
    enable = lib.mkEnableOption "AWS SSO configuration";
    ssoSession = lib.mkOption {
      type = lib.types.str;
      default = "zorg";
      description = "AWS SSO session name";
    };
    ssoStartUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://${cfg.ssoSession}.awsapps.com/start";
      description = "AWS SSO start URL";
    };
    ssoRegion = lib.mkOption {
      type = lib.types.str;
      default = "us-east-1";
      description = "AWS SSO region";
    };
    ssoRoleName = lib.mkOption {
      type = lib.types.str;
      default = "AdministratorAccess";
      description = "AWS SSO role name";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".aws/config" = {
      text = ''
        [default]
        cli_pager=
        output=json
        region=us-east-1

        [sso-session ${cfg.ssoSession}]
        sso_region = ${cfg.ssoRegion}
        sso_start_url = ${cfg.ssoStartUrl}

        ; Run 'refresh-zorg-profiles' to populate SSO account profiles.
      '';
    };
  };
}
```

**Step 2: Commit**

```bash
cd ~/.config/nix
git add home/aws.nix
git commit -m "feat: add AWS SSO config with custom nix options"
```

---

### Task 11: Create host configuration and starship-claude script

**Files:**
- Create: `~/.config/nix/hosts/AG-MACBOOK-1/configuration.nix`
- Create: `~/.config/nix/home/scripts/starship-claude`

**Step 1: Write `hosts/AG-MACBOOK-1/configuration.nix`**

Host-specific overrides. Sets hostname, enables AWS, wires in starship-claude.

```nix
{
  primaryUser,
  ...
}:
{
  networking.hostName = "AG-MACBOOK-1";

  home-manager.users.${primaryUser} = {
    # Enable AWS SSO with defaults
    myConfig.aws.enable = true;

    # Source starship-claude into PATH
    home.file.".local/bin/starship-claude" = {
      source = ../../home/scripts/starship-claude;
      executable = true;
    };
  };
}
```

**Step 2: Copy starship-claude script**

Copy `/Users/gillisandrew/.local/share/chezmoi/dot_local/bin/executable_starship-claude` to `~/.config/nix/home/scripts/starship-claude` verbatim.

**Step 3: Commit**

```bash
cd ~/.config/nix
git add hosts/ home/scripts/
git commit -m "feat: add AG-MACBOOK-1 host config and starship-claude script"
```

---

### Task 12: Build and verify (dry run)

**Step 1: Generate the flake lock file**

```bash
cd ~/.config/nix
nix flake update
```

**Step 2: Dry-run the darwin build**

```bash
cd ~/.config/nix
nix build .#darwinConfigurations.AG-MACBOOK-1.system --dry-run
```

Expected: resolves all dependencies and shows what would be built. No errors.

**Step 3: If errors, fix them iteratively**

Common issues:
- Missing module imports in `home/default.nix` — ensure all `./foo.nix` files exist
- Nix syntax errors — check for missing semicolons, commas, or braces
- Option type mismatches — ensure `lib.mkIf` wraps sets not individual values where needed
- `programs.vscode.package` may need adjustment if `emptyDirectory` doesn't work — can use `pkgs.runCommand "empty" {} "mkdir -p $out"` instead

**Step 4: Commit the lock file**

```bash
cd ~/.config/nix
git add flake.lock
git commit -m "chore: add flake.lock"
```

---

### Task 13: Apply the configuration

> **CAUTION:** This will apply system-wide changes. Review the dry-run output from Task 12 first.

**Step 1: Build and switch**

First-ever run (before `darwin-rebuild` exists on PATH):

```bash
cd ~/.config/nix
nix run nix-darwin -- switch --flake .#AG-MACBOOK-1
```

**Step 2: Verify key outcomes**

```bash
# Shell tools available
which starship atuin zoxide fzf bat direnv

# Homebrew casks managed
brew list --cask

# macOS defaults applied
defaults read com.apple.finder AppleShowAllFiles

# Git config correct
git config --global user.email
git config --global commit.gpgsign

# SSH config exists
cat ~/.ssh/config | head -5

# AWS config generated
cat ~/.aws/config

# Ghostty config in place
cat ~/.config/ghostty/config | head -3

# starship-claude in PATH
which starship-claude
```

**Step 3: Commit any fixes needed during verification**

---

### Task 14: Post-migration cleanup and documentation

**Step 1: Add a `nix-switch` convenience alias verification**

Run `nix-switch` from a new shell and confirm it rebuilds.

**Step 2: Verify nix-direnv works**

```bash
mkdir /tmp/test-flake && cd /tmp/test-flake
nix flake init --template "https://flakehub.com/f/the-nix-way/dev-templates/*#node"
echo "use flake" > .envrc
direnv allow
# Should load node into PATH
which node
rm -rf /tmp/test-flake
```

**Step 3: Commit final state**

```bash
cd ~/.config/nix
git add -A
git commit -m "chore: post-verification cleanup"
```
