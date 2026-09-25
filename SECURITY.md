# Security Policy

## Supported versions

Only the latest release gets fixes.

## Reporting a vulnerability

Please **don't open a public issue.** Use GitHub's [private vulnerability reporting](https://github.com/hamzakaya/claude-profile/security/advisories/new) instead.

Include what you ran, what happened, and what an attacker could gain. You'll get a reply within 7 days. Confirmed issues are fixed in a patch release, with credit unless you'd rather stay anonymous.

## What claude-profile touches

Knowing this helps judge what's in scope:

- **Credentials.** The script never reads, copies or prints OAuth tokens. Logins are done by `claude auth login` itself and stored where Claude Code puts them: the macOS Keychain, or `.credentials.json` inside the profile directory on Linux. `.credentials.json` and `.claude.json` can never be added to the `share` setting.
- **`.claude.json`.** Read with `jq` to show the logged-in email. Written only by `add` (initial copy of MCP servers and project settings from the main profile), `sync`, and `rename` (drops `oauthAccount`). Writes go through a temp file and `mv`.
- **Deletes.** `rm` deletes only `~/.claude-<name>` directories that contain the `.claude-profile` marker, after a `[y/N]` prompt. Shared items are symlinks, so the real files in `~/.claude` are never removed.
- **Shell code.** `shell-init` prints aliases and a `claude` function meant for `eval`. Profile names are limited to `[a-z0-9-]`, so they can't inject shell code.
- **Network.** None. Only `install.sh` downloads anything, over HTTPS, and it checks `SHA256SUMS` for release downloads.
