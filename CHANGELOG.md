# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/hamzakaya/claude-profile/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hamzakaya/claude-profile/releases/tag/v1.0.0
