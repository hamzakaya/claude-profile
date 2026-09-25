# Contributing

Thanks for helping. This is a single Bash script by design. It should stay small, have no dependencies beyond `bash` and `jq`, and be readable in one sitting.

## Setup

```sh
git clone https://github.com/hamzakaya/claude-profile.git
cd claude-profile
make check        # shellcheck + tests
```

You need `bash`, `jq` and [`shellcheck`](https://github.com/koalaman/shellcheck#installing). You don't need Claude Code: the tests use a fake `claude` and a throwaway `$HOME`, so your real `~/.claude` is never touched.

To try your working copy by hand without installing it:

```sh
./claude-profile doctor
```

## Tests

`tests/run.sh` is plain Bash. Each `test_*` function runs in its own temporary `$HOME` with `set -e`, so any failing assertion fails the test.

```sh
make test                 # all tests
tests/run.sh sync         # only tests whose name contains "sync"
```

Add a test for every behavior change. `run <args>` sets `$OUT` and `$RC`; then use `assert_ok`, `assert_fail`, `assert_out`, `assert_link`, `assert_eq` and friends. The fake `claude` writes the arguments it was `exec`'d with to `$STUB_OUT`.

## Rules for the script

- **bash 3.2 compatible.** That's what macOS ships as `/bin/bash`, and CI tests it. No `mapfile`/`readarray`, associative arrays, `${var,,}`, `&>>` or `declare -n`.
- **`shellcheck` clean.** If you disable a check, add a comment explaining why.
- **Never touch real files you didn't create.** Shared items are symlinks; anything the script didn't make gets a warning and is left alone.
- **Atomic writes.** Write to a temp file, then `mv`.
- **Keep the help text accurate.** `claude-profile help` prints the comment block at the top of the script. Update it and `README.md` when commands or settings change.
- Match the existing style: 2-space indent, short functions, `cmd_<name>` for commands.

## Pull requests

1. For anything bigger than a bug fix, open an issue first so we can agree on the approach.
2. One change per PR. Use [Conventional Commits](https://www.conventionalcommits.org/) (`fix: …`, `feat: …`, `docs: …`).
3. Add an entry under **Unreleased** in `CHANGELOG.md`.
4. CI must pass.

## Releasing (maintainers)

1. Bump `VERSION=` in `claude-profile` and `version` in `.claude-plugin/plugin.json` (`make version-check` enforces it), and move the **Unreleased** changelog entries under the new version.
2. Commit, then `git tag vX.Y.Z && git push origin main vX.Y.Z`.
3. The release workflow checks that the tag matches `VERSION`, runs `make check`, and publishes the script, `install.sh` and `SHA256SUMS`.
