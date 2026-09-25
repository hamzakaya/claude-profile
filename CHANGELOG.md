# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.1] - 2026-09-26

### Fixed

- Sessions weren't found in directories with non-ASCII characters (`ü`, `ş`, `İ`, …) in their path: the project folder name depended on the locale. It is now computed the way Claude Code does, whatever the locale.
- A `-c` you type (`claude-profile work -c`, or plain `claude -c` with a default profile) is passed to `claude` unchanged. Only `open continue` still falls back to a new conversation when there is nothing to continue.
- `shell-init` no longer breaks when you have your own `claude` alias (zsh: "defining function based on alias"; bash: syntax error). The alias's flags now reach the default profile.
- The `open` override used by the menu and `shell-init` no longer leaks into the Claude Code session's environment.
- `doctor` finds the shell integration in `$ZDOTDIR/.zshrc`.
- `install.sh` and `make install` back up an existing `claude-profile` that isn't this tool (to `claude-profile.bak`) instead of overwriting it.

### Changed

- `rules` (`~/.claude/rules`, user-level instructions) and `paste-cache` (long pastes that the shared `history.jsonl` points to) are now shared by default.

## [1.0.0] - 2026-09-26

### Added

- Profiles: `add`, `list`, `which`, `use`, `rename`, `rm`, `login`, `logout`, `status`.
- Shared conversation history, settings, plugins, skills and hooks through symlinks, so `--resume` works across accounts.
- Interactive menu (`claude-profile` with no arguments).
- `sessions` to list recent conversations in the current directory.
- `sync` to merge MCP servers and project settings from the main profile; `auto-sync` setting.
- `doctor` to check the setup, repair missing links and adopt existing profile directories.
- `shell-init` with `claude-<name>` aliases and a configurable default profile.
- Settings: `main`, `default`, `open`, `auto-sync`, `share`.
- `version` command.
- Installer with checksum verification, Makefile, test suite, CI on Linux and macOS (bash 3.2 and 5).
- Claude Code plugin and marketplace with a `claude-profile` skill for guided setup.

[Unreleased]: https://github.com/hamzakaya/claude-profile/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/hamzakaya/claude-profile/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/hamzakaya/claude-profile/releases/tag/v1.0.0
