# Plan: Migrate AWS onboarding to unified modify_ script

## Context

Current AWS onboarding is a 3-step process: `chezmoi init` (prompts for SSO details) → `chezmoi apply` (seeds empty `~/.aws/config`) → manually run `refresh-zorg-profiles` (does `aws sso login`, enumerates accounts, **replaces** entire config). This is fragile (full file replacement, no cred reuse, manual step required). We're consolidating into a single `modify_` script that auto-refreshes profiles when valid SSO creds exist and gracefully degrades when they don't.

## Files to change

| File | Action |
|------|--------|
| `dot_aws/modify_private_config.tmpl` | **Rewrite** — unified modify script |
| `dot_local/bin/executable_refresh-zorg-profiles.tmpl` | **Simplify** — thin wrapper: `aws sso login` + `chezmoi apply ~/.aws/config` |
| `.chezmoiscripts/run_once_after_setup-aws-sso.sh.tmpl` | **Delete** — functionality absorbed by modify script stderr messages |

## Step 1: Rewrite `dot_aws/modify_private_config.tmpl`

The modify script receives current `~/.aws/config` on stdin, outputs new contents on stdout.

**Logic flow:**
1. If `aws.enabled` is false → pass stdin through unchanged, exit
2. Always write base config: `[default]` (with `cli_pager=fx`) + `[sso-session]` block from template data
3. Find valid SSO access token:
   - Iterate `~/.aws/sso/cache/*.json` files
   - Match by `startUrl` == configured SSO start URL
   - Must have `accessToken` field
   - Check `expiresAt` > now (macOS `date -jf` with Linux `date -d` fallback)
4. If valid token found → run `aws sso list-accounts`, build `[profile <name>]` blocks (sorted alphabetically), output them
5. If token invalid/missing → extract existing `[profile ...]` sections from stdin, preserve them
6. If no profiles at all → output comment: `; Run refresh-zorg-profiles to populate SSO profiles.`
7. All status messages go to stderr (visible to user, doesn't affect file content)

**Key decisions:**
- Never triggers interactive `aws sso login` (no browser popups during `chezmoi apply`)
- Profiles sorted alphabetically for stable diffs
- `cli_pager=fx` in both default and per-profile sections
- macOS/Linux compatible date parsing

## Step 2: Simplify `executable_refresh-zorg-profiles.tmpl`

Replace 117-line script with ~10 lines:
```bash
#!/usr/bin/env bash
set -euo pipefail
unset AWS_PROFILE
aws sso login --sso-session "{{ .aws.sso_session }}"
chezmoi apply ~/.aws/config
```

All enumeration logic now lives in the modify script. This script just ensures fresh creds exist, then delegates.

## Step 3: Delete `run_once_after_setup-aws-sso.sh.tmpl`

The modify script's stderr messages replace the one-time nag:
- `[aws] SSO profiles refreshed from live account list.`
- `[aws] SSO token expired. Preserved existing profiles. Run: refresh-zorg-profiles`
- `[aws] No SSO credentials found. Run: refresh-zorg-profiles`

These appear on every `chezmoi apply` when relevant (better than run_once which only fires once).

## Verification

1. `chezmoi diff ~/.aws/config` — preview changes (read-only, safe)
2. `chezmoi apply ~/.aws/config -v` — apply and check output
3. Verify `~/.aws/config` has base config + existing profiles preserved
4. Run `refresh-zorg-profiles` — should login, then re-apply with fresh profiles
5. `chezmoi apply` again — should show no diff (idempotent)
