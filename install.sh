#!/usr/bin/env bash
# Installer for claude-profile.
#
#   curl -fsSL https://raw.githubusercontent.com/hamzakaya/claude-profile/main/install.sh | bash
#
# Environment:
#   CLAUDE_PROFILE_VERSION   release tag (e.g. v1.0.0), "latest" (default) or "main"
#   PREFIX                   install prefix; the script goes to $PREFIX/bin  (default: ~/.local)
set -euo pipefail

REPO=hamzakaya/claude-profile
VERSION=${CLAUDE_PROFILE_VERSION:-latest}
BINDIR=${PREFIX:-$HOME/.local}/bin

say() { printf '\033[36m›\033[0m %s\n' "$*"; }
die() { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || die "curl is required."
command -v jq   >/dev/null || die "jq is required (brew install jq / apt install jq)."
command -v claude >/dev/null || say "Note: 'claude' is not on PATH yet — install Claude Code before using profiles."

case $VERSION in
  main)   base="https://raw.githubusercontent.com/$REPO/main" ;;
  latest) base="https://github.com/$REPO/releases/latest/download" ;;
  v*)     base="https://github.com/$REPO/releases/download/$VERSION" ;;
  *)      die "CLAUDE_PROFILE_VERSION must be a tag like v1.0.0, 'latest' or 'main'." ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

say "Downloading claude-profile ($VERSION)"
curl -fsSL "$base/claude-profile" -o "$tmp/claude-profile" || die "download failed: $base/claude-profile"

# Releases ship SHA256SUMS; the main branch has nothing to check against.
if [[ $VERSION != main ]]; then
  curl -fsSL "$base/SHA256SUMS" -o "$tmp/SHA256SUMS" || die "download failed: $base/SHA256SUMS"
  if command -v sha256sum >/dev/null; then sum=(sha256sum); else sum=(shasum -a 256); fi
  (cd "$tmp" && grep ' claude-profile$' SHA256SUMS | "${sum[@]}" -c - >/dev/null) || die "checksum mismatch"
fi
bash -n "$tmp/claude-profile" || die "downloaded file is not a valid script"

mkdir -p "$BINDIR"
# Something else under the same name (e.g. a hand-written script): keep a copy, don't lose it.
target=$BINDIR/claude-profile
if [[ -e $target ]] && ! grep -q '^PROG=claude-profile$' "$target" 2>/dev/null; then
  cp -p "$target" "$target.bak" || die "could not back up $target"
  say "Backed up the existing $target (not claude-profile) to $target.bak"
fi
install -m 0755 "$tmp/claude-profile" "$target"
say "Installed $("$BINDIR/claude-profile" version) → $BINDIR/claude-profile"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) say "Add $BINDIR to your PATH:  export PATH=\"$BINDIR:\$PATH\"" ;;
esac
cat <<EOF

Next steps:
  1. Add to ~/.zshrc or ~/.bashrc:   eval "\$(claude-profile shell-init)"
  2. Create a profile:               claude-profile add work
  3. Check the setup:                claude-profile doctor
EOF
