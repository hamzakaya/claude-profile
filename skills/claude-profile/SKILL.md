---
name: claude-profile
description: Install, set up and manage claude-profile, a CLI that runs Claude Code with several accounts (work, personal, client…) side by side while sharing conversation history, settings, plugins and skills. Use when the user wants multiple Claude accounts, to switch or add an account, to see which account a profile uses, to resume a conversation under another account, or to fix a claude-profile setup.
license: MIT
compatibility: Claude Code on macOS, Linux or WSL with bash 3.2+ and jq.
---

# claude-profile

`claude-profile` gives each Claude Code account its own config directory (`~/.claude-<name>`, used through `CLAUDE_CONFIG_DIR`). Conversation history, settings, plugins, skills, hooks, agents and `CLAUDE.md` are symlinked back to `~/.claude`, so `--resume` works across accounts. The original `~/.claude` is the *main* profile and is never modified.

Full docs: https://github.com/hamzakaya/claude-profile

## What you can and can't do from inside this session

This session is already running as one account, and that can't change mid-session.

- **You can run:** `install`, `list`, `which`, `status`, `sessions`, `doctor`, `config`, `default`, `sync`, `version`, `help`.
- **The user must run in their own terminal:** `add`, `login`, `rename` (these open a browser for OAuth) and anything that *starts* Claude (`claude-profile <name>`, `claude-<name>`, the menu). If they want to stay here, they can type `! claude-profile add <name>`; if the login doesn't complete, use a separate terminal.
- **`rm` only after the user explicitly confirms the profile name in this conversation.** It asks `[y/N]` on stdin; pipe `y` only then: `echo y | claude-profile rm <name>`.

## Install

1. Check: `command -v claude-profile && claude-profile version`. If it's installed, skip to *Set up*.
2. Check prerequisites: `command -v jq`. If it's missing, tell the user (`brew install jq` / `sudo apt install jq`); don't install system packages without asking.
3. Install to `~/.local/bin`, verifying the release checksum:
   ```sh
   curl -fsSL https://raw.githubusercontent.com/hamzakaya/claude-profile/main/install.sh | bash
   ```
4. If `~/.local/bin` isn't on `PATH`, tell the user which line to add to their shell rc.

## Set up

1. Find the rc file: `$SHELL` ends in `zsh` → `~/.zshrc`; `bash` → `~/.bashrc` (macOS login shells: `~/.bash_profile`).
2. Unless `grep -q 'claude-profile shell-init' <rc>` already matches, **ask**, then append:
   ```sh
   eval "$(claude-profile shell-init)"
   ```
3. Optionally name the main profile (ask the user what to call their current account): `claude-profile config main <name>`.
4. Hand over the login step. Tell the user to run, in a new terminal:
   ```sh
   claude-profile add <name>     # opens the browser: pick the other account
   exec $SHELL                   # load the new claude-<name> alias
   ```
5. Afterwards run `claude-profile doctor` and `claude-profile list` and report the result.

## Everyday tasks

| User wants | Run / tell them |
|---|---|
| See accounts | `claude-profile list` (`●` this shell, `★` default) |
| Which account is this session? | `claude-profile which` |
| Are logins valid? | `claude-profile status` |
| Continue this directory's last conversation as another account | tell them: `claude-profile <name> -c` |
| Resume a specific conversation | `claude-profile sessions`, then tell them: `claude-profile <name> -r <id>` |
| Plain `claude` should use another account | `claude-profile default <name>` (new shells) |
| Copy MCP servers / project permissions to profiles | `claude-profile sync [name]` |
| Share another `~/.claude` item | `claude-profile config share "<items>"`, then `claude-profile doctor` |
| Something looks wrong | `claude-profile doctor` |

## Things to know

- `sync` rewrites the profile's `.claude.json`. If *this* session belongs to that profile (`claude-profile which`), warn that a running session can write its old `.claude.json` back: sync, then have the user restart.
- `doctor` reports **diverged** when a profile has a real file where a shared link belongs. Don't delete it yourself. Show the diff against `~/.claude/<item>` and let the user choose.
- Profile names: lowercase letters, digits, dashes; not a command name (`list`, `add`, …).
- Never read, print or copy `.credentials.json`, Keychain entries or `oauthAccount` data beyond the email that `list` shows.
- Settings live in `~/.config/claude-profile/config`: `main`, `default`, `open` (`new|continue|pick`), `auto-sync` (`on|off`), `share`.
