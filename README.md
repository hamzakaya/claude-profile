# claude-profile

[![CI](https://github.com/hamzakaya/claude-profile/actions/workflows/ci.yml/badge.svg)](https://github.com/hamzakaya/claude-profile/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hamzakaya/claude-profile)](https://github.com/hamzakaya/claude-profile/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Run [Claude Code](https://docs.claude.com/en/docs/claude-code) with several accounts side by side, sharing one conversation history.**

Each profile has its own login. Everything else (conversation history, settings, plugins, skills, hooks, agents, `CLAUDE.md`) is shared with `~/.claude`. So you can start a conversation with your work account and pick it up later with your personal one via `--resume`.

```console
$ claude-profile list
● ★ personal         me@personal.dev
    work             me@company.com
● this shell  ★ default

$ claude-profile work -c        # continue the last conversation here, as "work"
```

It's a single Bash script with no dependencies beyond `jq`.

---

- [Why](#why)
- [Requirements](#requirements)
- [Install](#install)
- [Quick start](#quick-start)
- [Usage](#usage)
- [Settings](#settings)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Contributing](#contributing) · [Security](#security) · [License](#license)

## Why

Claude Code keeps one login per config directory. The built-in way to switch is to set `CLAUDE_CONFIG_DIR` by hand, which gives each account its own history, settings and plugins. Nothing carries over.

`claude-profile` gives every account its own config directory but symlinks the shared parts back to `~/.claude`:

- **One history.** `claude --resume` and `-c` see the same conversations whichever account you use.
- **One setup.** Install a plugin, add a skill or change `settings.json` once, and every profile gets it.
- **Parallel sessions.** Run `claude-work` in one terminal and `claude-personal` in another.
- **Nothing hidden.** Profiles are plain `~/.claude-<name>` directories. `doctor` tells you exactly what's linked.

## Requirements

| | Version | Notes |
|---|---|---|
| [Claude Code](https://docs.claude.com/en/docs/claude-code/setup) | recent | `claude` on your `PATH`, logged in once |
| Bash | 3.2+ | macOS's built-in `/bin/bash` works |
| [jq](https://jqlang.org/download/) | 1.6+ | `brew install jq` · `apt install jq` · `dnf install jq` |
| OS | macOS, Linux, WSL | zsh or bash as your interactive shell |

## Install

**Installer** (recommended). It downloads the latest release, checks its SHA-256 and installs to `~/.local/bin`:

```sh
curl -fsSL https://raw.githubusercontent.com/hamzakaya/claude-profile/main/install.sh | bash
```

Options: `CLAUDE_PROFILE_VERSION=v1.0.0` pins a release. `PREFIX=/usr/local` changes the install location (`sudo` may be needed).

<details>
<summary>Manual download</summary>

```sh
mkdir -p ~/.local/bin
curl -fsSL https://github.com/hamzakaya/claude-profile/releases/latest/download/claude-profile \
  -o ~/.local/bin/claude-profile
chmod +x ~/.local/bin/claude-profile
```

</details>

<details>
<summary>From source</summary>

```sh
git clone https://github.com/hamzakaya/claude-profile.git
cd claude-profile
make install              # or: make install PREFIX=/usr/local
```

</details>

Make sure the install directory is on your `PATH`. Then add shell integration to `~/.zshrc` or `~/.bashrc`:

```sh
eval "$(claude-profile shell-init)"
```

This gives you a `claude-<name>` alias for every profile, and makes plain `claude` use your [default profile](#settings).

### Let Claude Code set it up

**As a plugin.** This repo is also a Claude Code plugin marketplace. The plugin adds a `claude-profile` skill that knows how to install, set up and troubleshoot the tool. Run inside Claude Code:

```text
/plugin marketplace add hamzakaya/claude-profile
/plugin install claude-profile@claude-profile
```

Then just ask: *"set up claude-profile and add my work account"*, or run `/claude-profile:claude-profile`.

<details>
<summary>Skill only, without the plugin system</summary>

```sh
mkdir -p ~/.claude/skills/claude-profile
curl -fsSL https://raw.githubusercontent.com/hamzakaya/claude-profile/main/skills/claude-profile/SKILL.md \
  -o ~/.claude/skills/claude-profile/SKILL.md
```

</details>

**With a prompt.** No plugin needed. Paste this into Claude Code:

```text
Install claude-profile from https://github.com/hamzakaya/claude-profile so I can use
several Claude Code accounts side by side.
1. Check that jq is installed; if not, tell me the command and stop.
2. Run: curl -fsSL https://raw.githubusercontent.com/hamzakaya/claude-profile/main/install.sh | bash
3. Make sure ~/.local/bin is on my PATH.
4. Ask me first, then add  eval "$(claude-profile shell-init)"  to my shell rc file,
   unless it's already there.
5. Ask what my current account should be called and run: claude-profile config main <name>
6. Tell me the exact command to add my second account in a new terminal
   (it opens a browser, so don't run it yourself), then run claude-profile doctor.
```

Claude can't log in to another account or switch accounts inside a running session. That step always happens in your terminal.

## Quick start

```sh
# 1. Log in to your first account the normal way (if you haven't already).
claude

# 2. Optional: give that original ~/.claude profile a name (default: "main").
claude-profile config main personal

# 3. Add a second account. A browser opens: pick the other account.
claude-profile add work

# 4. Reload your shell so the new alias exists, then check everything.
exec $SHELL
claude-profile doctor

# 5. Use it.
claude-work                 # new conversation as "work"
claude-profile work -c      # continue the latest conversation in this directory
claude-profile              # interactive menu
```

## Usage

```text
claude-profile                        interactive menu (↑↓/jk, enter, 1-9, q)
claude-profile <name> [claude args]   start claude with a profile (= use <name> ...)
claude-profile -c | -r <id> ...       start claude with the default profile
```

Anything after the profile name goes straight to `claude`, so every Claude Code flag works:

```sh
claude-profile work -c                 # continue the latest conversation here
claude-profile personal -r 3f2a…       # resume a specific session
claude-profile work -p "summarize"     # print mode
```

### Commands

| Command | What it does |
|---|---|
| `list` (`ls`) | List profiles with their logged-in account. `●` = this shell, `★` = default |
| `which` (`current`) | Show the profile this shell is using |
| `add <name>` (`new`) | Create a profile and log in. Names: lowercase letters, digits, dashes |
| `default [name]` | Show or set the profile that plain `claude` uses |
| `sessions [n]` (`s`) | The last *n* (default 10) conversations in this directory, with their first message |
| `status [name]` | Check login status of all profiles (in parallel) or one |
| `login <name>` / `logout <name>` | Refresh or remove a profile's login |
| `rename <old> <new>` (`mv`) | Rename a profile. You'll log in again, because the macOS Keychain entry is tied to the directory |
| `rm <name>` (`remove`) | Delete a profile after confirming. Shared history is kept |
| `sync [name]` | Copy MCP servers and project settings from the main profile |
| `doctor` | Check the setup, repair missing links, adopt profile directories made by hand |
| `config [key [value]]` | Show or change [settings](#settings) |
| `shell-init` | Print shell integration code for `eval` |
| `version` · `help` | Version · built-in help |

Set `NO_COLOR=1` to turn off colors.

## Settings

Stored in `~/.config/claude-profile/config` (or `$XDG_CONFIG_HOME/claude-profile/config`). Change them with `claude-profile config <key> <value>`:

| Key | Values | Default | Meaning |
|---|---|---|---|
| `main` | profile name | `main` | Name of the original `~/.claude` profile |
| `default` | profile name | *main* | Profile used by plain `claude` and `claude-profile -c` |
| `open` | `new` · `continue` · `pick` | `new` | What `claude-profile <name>` does with no extra arguments |
| `auto-sync` | `on` · `off` | `off` | Run `sync` every time a profile starts |
| `share` | space-separated names | *(none)* | Extra items in `~/.claude` to share, e.g. `"rules statusline.sh"` |

```console
$ claude-profile config
main       personal  profile name of ~/.claude
default    personal  plain claude / claude-profile -c
open       new  new | continue | pick
auto-sync  off  on | off
share      -  extra shared items
```

## How it works

```text
~/.claude/                     ← main profile (untouched, works as before)
├── projects/                  ← conversation history
├── settings.json
├── plugins/ skills/ hooks/ agents/ commands/ …
└── CLAUDE.md
~/.claude.json                 ← main login + MCP servers + per-project settings

~/.claude-work/                ← "work" profile  (CLAUDE_CONFIG_DIR points here)
├── .claude-profile            ← marker: only marked dirs count as profiles
├── .claude.json               ← work's own login, MCP servers, project trust
├── projects      → ~/.claude/projects
├── settings.json → ~/.claude/settings.json
└── …             → ~/.claude/…
```

Starting a profile sets `CLAUDE_CONFIG_DIR=~/.claude-<name>` and `exec`s `claude`. It also re-links any shared item that has appeared in `~/.claude` since last time.

**Shared** (symlinked): `projects`, `settings.json`, `agents`, `commands`, `skills`, `hooks`, `plugins`, `plans`, `output-styles`, `file-history`, `history.jsonl`, `tasks`, `todos`, `keybindings.json`, `CLAUDE.md`, plus anything in `share`.

**Per profile**:
- the login: the macOS Keychain entry, or `.credentials.json` on Linux;
- `.claude.json`: account info, MCP servers, per-project permissions and trust.

When you create a profile, it starts with a copy of the main profile's MCP servers and project settings. Use `sync` (or `auto-sync on`) to pull in later changes. In the merge, the profile keeps its own project entries, and for MCP servers with the same name, main wins.

Existing files are never overwritten. If a profile has a real file where a link should be, `doctor` reports it as *diverged* so you can merge it by hand.

**Inside Claude Code.** `shell-init` does nothing when `CLAUDECODE` is set. So shells that Claude Code spawns keep the account of the session that started them.

## Troubleshooting

Start with `claude-profile doctor`. It checks `claude`, your shell rc, settings and every profile's links, and repairs missing links.

<details>
<summary><code>claude-work: command not found</code></summary>

Aliases are generated when your shell starts. After `add` or `rename`, run `exec $SHELL` or open a new terminal. Also check that `eval "$(claude-profile shell-init)"` is in the rc file your shell actually reads (`~/.zshrc` for zsh, `~/.bashrc` or `~/.bash_profile` for bash).
</details>

<details>
<summary>MCP servers or project permissions are missing in a profile</summary>

Those live in `.claude.json`, which is per profile. Run `claude-profile sync <name>`, or `claude-profile config auto-sync on`. Restart any open sessions of that profile first: a running session can write its old `.claude.json` back.
</details>

<details>
<summary><code>diverged (real file, not shared)</code></summary>

Something (often Claude Code itself, before the link existed) created a real file in the profile. Compare it with the one in `~/.claude`, keep what you need, delete the profile's copy, then run `doctor` to re-link it.
</details>

<details>
<summary>Asked to log in again after <code>rename</code></summary>

This is expected. On macOS the login is stored in the Keychain, keyed by the config directory path, so it can't move with the directory.
</details>

<details>
<summary><code>-c</code> started a new conversation</summary>

There was no conversation to continue in this directory, so `claude -c` would have failed. `claude-profile` starts a fresh one instead. Use `claude-profile sessions` to see what's there.
</details>

<details>
<summary>I made <code>~/.claude-foo</code> by hand before</summary>

`doctor` adopts directories that have a `.claude.json` and a `projects` symlink. Other `~/.claude-*` directories are ignored, and `claude-profile` never deletes a directory without its marker.
</details>

## Uninstall

```sh
# 1. Remove each extra profile (logs out and deletes ~/.claude-<name>; history stays in ~/.claude)
claude-profile rm work

# 2. Remove the eval line from ~/.zshrc / ~/.bashrc, then the script and its settings
rm ~/.local/bin/claude-profile            # or: make uninstall
rm -rf ~/.config/claude-profile
```

Your original `~/.claude` and its login are never modified, so plain `claude` keeps working afterwards.

## Contributing

Bug reports and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. In short: `make check` must pass, new behavior needs a test, and the script must keep working on bash 3.2.

## Security

The script never reads or copies credentials; logins go through `claude auth`. See [SECURITY.md](SECURITY.md) for what it touches and how to report a vulnerability privately.

## License

[MIT](LICENSE) © Hamza KAYA

*Not affiliated with or endorsed by Anthropic. "Claude" and "Claude Code" are trademarks of Anthropic. Make sure your use of multiple accounts complies with the terms that apply to them.*
