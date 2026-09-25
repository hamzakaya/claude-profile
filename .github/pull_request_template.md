## What and why

<!-- One or two sentences. Link the issue: Closes #123 -->

## Checklist

- [ ] `make check` passes (shellcheck + tests)
- [ ] New behavior has a test in `tests/run.sh`
- [ ] Works on bash 3.2 (macOS `/bin/bash`): no `mapfile`, `declare -A`, `${var,,}`, etc.
- [ ] Help text at the top of `claude-profile` and `README.md` updated if commands or settings changed
- [ ] `CHANGELOG.md` has an entry under **Unreleased**
