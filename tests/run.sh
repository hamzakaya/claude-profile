#!/usr/bin/env bash
# Test suite for claude-profile. No dependencies beyond bash and jq.
# Every test runs in a throwaway $HOME with a fake `claude` on PATH, so your real
# ~/.claude is never touched.
#
#   tests/run.sh            run everything
#   tests/run.sh sync       run tests whose name contains "sync"
set -uo pipefail

ROOT=$(cd "${0%/*}/.." && pwd)
CP="$ROOT/claude-profile"
FILTER=${1:-}
PASS=0 FAIL=0

# ── harness ────────────────────────────────────────────────────────────────────────
setup() {
  T=$(mktemp -d)
  export HOME=$T/home XDG_CONFIG_HOME=$T/home/.config NO_COLOR=1
  unset CLAUDE_CONFIG_DIR CLAUDECODE CLAUDE_PROFILE_OPEN CLAUDE_CODE_OAUTH_TOKEN
  mkdir -p "$HOME/.claude/projects" "$HOME/.claude/skills" "$T/bin"
  echo '{}' > "$HOME/.claude/settings.json"
  jq -n '{oauthAccount: {emailAddress: "main@example.com"},
          mcpServers: {m1: {command: "x"}}, projects: {"/p": {allowedTools: ["a"]}},
          hasCompletedOnboarding: true}' > "$HOME/.claude.json"
  # Fake claude: `auth login|logout|status` edit the profile's .claude.json; anything
  # else records its arguments and config dir to $STUB_OUT, and CLAUDE_PROFILE_OPEN (which
  # must not leak into the session) to $STUB_OUT.env, and CLAUDE_CODE_OAUTH_TOKEN to $STUB_OUT.token.
  cat > "$T/bin/claude" <<'STUB'
#!/usr/bin/env bash
j=${CLAUDE_CONFIG_DIR:+$CLAUDE_CONFIG_DIR/.claude.json}; j=${j:-$HOME/.claude.json}
name=$(basename "${CLAUDE_CONFIG_DIR:-main}"); name=${name#.claude-}
case "$1 ${2:-}" in
  "auth login")  jq --arg e "$name@example.com" '.oauthAccount.emailAddress = $e' "$j" > "$j.t" && mv "$j.t" "$j" ;;
  "auth logout") jq 'del(.oauthAccount)' "$j" > "$j.t" && mv "$j.t" "$j" ;;
  "auth status") jq -c '{loggedIn: (.oauthAccount != null), authMethod: "oauth"}' "$j" ;;
  *) printf '%s|%s\n' "${CLAUDE_CONFIG_DIR:-}" "$*" > "$STUB_OUT"
     printf '%s\n' "${CLAUDE_PROFILE_OPEN-<unset>}" > "$STUB_OUT.env"
     printf '%s\n' "${CLAUDE_CODE_OAUTH_TOKEN-<unset>}" > "$STUB_OUT.token" ;;
esac
STUB
  chmod +x "$T/bin/claude"
  export PATH="$T/bin:$PATH" STUB_OUT=$T/exec
  cd "$T" || exit 1
}
teardown() { cd / && rm -rf "$T"; }

run() { RC=0; OUT=$("$CP" "$@" 2>&1) || RC=$?; }

fail() { printf '    %s\n' "$*"; return 1; }
assert_ok()       { [[ $RC == 0 ]] || fail "expected success, got rc=$RC: $OUT"; }
assert_fail()     { [[ $RC != 0 ]] || fail "expected failure, got: $OUT"; }
assert_out()      { [[ $OUT == *"$1"* ]] || fail "output lacks '$1': $OUT"; }
assert_not_out()  { [[ $OUT != *"$1"* ]] || fail "output has '$1': $OUT"; }
assert_link()     { [[ -L $1 ]] || fail "not a symlink: $1"; }
assert_file()     { [[ -e $1 ]] || fail "missing: $1"; }
assert_no_file()  { [[ ! -e $1 ]] || fail "should not exist: $1"; }
assert_eq()       { [[ $1 == "$2" ]] || fail "expected '$2', got '$1'"; }

t() {   # t <name> <function>
  [[ -z $FILTER || $1 == *"$FILTER"* ]] || return 0
  setup
  # Not `if ( ... )`: bash ignores `set -e` inside an if condition, so only the last
  # assertion would count.
  ( set -e; "$2" ); local rc=$?
  if (( rc == 0 )); then PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"
  else FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; fi
  teardown
}

# ── tests ──────────────────────────────────────────────────────────────────────────
test_help_and_version() {
  run help;    assert_ok; assert_out "claude-profile add <name>"; assert_not_out "set -euo"
  run version; assert_ok; assert_out "claude-profile "
}

test_add_creates_profile() {
  run add work; assert_ok
  assert_file "$HOME/.claude-work/.claude-profile"
  assert_link "$HOME/.claude-work/projects"
  assert_link "$HOME/.claude-work/settings.json"
  assert_link "$HOME/.claude-work/skills"
  assert_no_file "$HOME/.claude-work/agents"        # absent in main → not linked
  assert_eq "$(jq -r '.mcpServers.m1.command' "$HOME/.claude-work/.claude.json")" x
  assert_eq "$(jq -r '.oauthAccount.emailAddress' "$HOME/.claude-work/.claude.json")" work@example.com
}

test_add_rejects_bad_names() {
  run add Work;  assert_fail; assert_out "Invalid name"
  run add list;  assert_fail; assert_out "command name"
  run add main;  assert_fail; assert_out "main profile"
  run add;       assert_fail
  run add work;  assert_ok
  run add work;  assert_fail; assert_out "Already exists"
}

test_add_refuses_foreign_dir() {
  mkdir "$HOME/.claude-work"
  run add work; assert_fail; assert_out "isn't a profile"
}

test_list_and_which() {
  "$CP" add work >/dev/null
  run list; assert_ok; assert_out "main@example.com"; assert_out "work@example.com"
  CLAUDE_CONFIG_DIR=$HOME/.claude-work run which; assert_out "work"
  mkdir "$HOME/.claude-stray"   # no marker → not a profile
  run list; assert_not_out "stray"
}

test_use_execs_claude_with_config_dir() {
  "$CP" add work >/dev/null
  run work -r abc; assert_ok
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|-r abc"
  run main --foo; assert_ok
  assert_eq "$(cat "$STUB_OUT")" "|--foo"
}

test_open_continue_without_sessions_starts_new() {
  "$CP" add work >/dev/null
  "$CP" config open continue >/dev/null
  run work; assert_ok; assert_out "starting a new one"
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|"
}

test_explicit_continue_is_passed_through() {
  # Even with no sessions found, a -c the user typed goes to claude untouched.
  "$CP" add work >/dev/null
  run work -c; assert_ok; assert_not_out "starting a new one"
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|-c"
}

test_open_setting_does_not_leak_into_session() {
  "$CP" add work >/dev/null
  CLAUDE_PROFILE_OPEN=new run work
  assert_eq "$(cat "$STUB_OUT.env")" "<unset>"
}

test_sessions_found_for_non_ascii_path() {
  # Claude Code replaces every non-ASCII-alphanumeric character (not byte) with "-".
  mkdir -p "$T/müşteri İş" && cd "$T/müşteri İş"
  d="$HOME/.claude/projects/${T//[^A-Za-z0-9]/-}-m--teri---"; mkdir -p "$d"
  echo '{"type":"user","message":{"content":"merhaba"}}' > "$d/s1.jsonl"
  # en_US.UTF-8: [A-Za-z] matches ü, ş…; C: bash works on bytes. Both used to miss the folder.
  # (Where en_US.UTF-8 isn't installed bash falls back to C and warns; the warning is dropped.)
  for loc in en_US.UTF-8 C; do
    { LC_ALL=$loc run sessions; } 2>/dev/null; assert_ok; assert_out "merhaba"
  done
  "$CP" add work >/dev/null
  "$CP" config open continue >/dev/null
  { LC_ALL=en_US.UTF-8 run work; } 2>/dev/null; assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|-c"
}

test_use_continue_with_sessions() {
  "$CP" add work >/dev/null
  d="$HOME/.claude/projects/${PWD//[^A-Za-z0-9]/-}"; mkdir -p "$d"
  echo '{"type":"user","message":{"content":"hello there"}}' > "$d/s1.jsonl"
  run work -c; assert_ok
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|-c"
  run sessions; assert_ok; assert_out "s1"; assert_out "hello there"
}

test_unknown_profile() {
  run nope; assert_fail; assert_out "Unknown command or profile"
}

test_dash_args_use_default_profile() {
  "$CP" add work >/dev/null
  "$CP" default work >/dev/null
  run --version; assert_ok
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|--version"
}

test_config_roundtrip() {
  run config open continue;  assert_ok
  run config open;           assert_eq "$OUT" continue
  run config open sometimes; assert_fail
  run config auto-sync on;   assert_ok
  run config share "rules";  assert_ok
  run config share ".credentials.json"; assert_fail
  run config nope;           assert_fail; assert_out "Unknown setting"
  run config; assert_out "continue"; assert_out "rules"
}

test_share_links_extra_items() {
  echo 'echo hi' > "$HOME/.claude/statusline.sh"
  "$CP" config share statusline.sh >/dev/null
  "$CP" add work >/dev/null
  assert_link "$HOME/.claude-work/statusline.sh"
}

test_rules_and_paste_cache_shared_by_default() {
  mkdir "$HOME/.claude/rules" "$HOME/.claude/paste-cache"
  "$CP" add work >/dev/null
  assert_link "$HOME/.claude-work/rules"
  assert_link "$HOME/.claude-work/paste-cache"
}

test_install_sh_backs_up_foreign_script() {
  # Fake curl serves the working copy, so the installer runs offline.
  # shellcheck disable=SC2016  # $# and $1 belong to the fake curl, not to this shell
  printf '%s\n' '#!/usr/bin/env bash' 'while [[ $# -gt 1 ]]; do [[ $1 == -o ]] && out=$2; shift; done' \
    "cp '$CP' \"\$out\"" > "$T/bin/curl"
  chmod +x "$T/bin/curl"
  mkdir -p "$T/p/bin"; echo '# my own script' > "$T/p/bin/claude-profile"
  OUT=$(PREFIX=$T/p CLAUDE_PROFILE_VERSION=main bash "$ROOT/install.sh" 2>&1); RC=$?
  assert_ok; assert_out "Backed up"
  assert_eq "$(cat "$T/p/bin/claude-profile.bak")" "# my own script"
  grep -q '^PROG=claude-profile$' "$T/p/bin/claude-profile" || fail "not installed"
  # Upgrading an existing claude-profile makes no backup.
  rm "$T/p/bin/claude-profile.bak"
  OUT=$(PREFIX=$T/p CLAUDE_PROFILE_VERSION=main bash "$ROOT/install.sh" 2>&1); RC=$?
  assert_ok; assert_not_out "Backed up"; assert_no_file "$T/p/bin/claude-profile.bak"
}

test_make_install_backs_up_foreign_script() {
  command -v make >/dev/null || return 0
  mkdir -p "$T/m"; echo '# my own script' > "$T/m/claude-profile"
  OUT=$(make -s -C "$ROOT" install BINDIR="$T/m" 2>&1); RC=$?
  assert_ok; assert_out "Backed up"
  assert_eq "$(cat "$T/m/claude-profile.bak")" "# my own script"
}

test_default_profile() {
  "$CP" add work >/dev/null
  run default;       assert_eq "$OUT" main
  run default work;  assert_ok
  run default;       assert_eq "$OUT" work
  run default ghost; assert_fail
}

test_sync_merges_and_keeps_profile_entries() {
  "$CP" add work >/dev/null
  j=$HOME/.claude-work/.claude.json
  jq '.projects["/p"].allowedTools = ["mine"] | .projects["/q"] = {x: 1}' "$j" > "$j.t" && mv "$j.t" "$j"
  jq '.mcpServers.m2 = {command: "y"}' "$HOME/.claude.json" > "$T/m" && mv "$T/m" "$HOME/.claude.json"
  run sync work; assert_ok
  assert_eq "$(jq -r '.mcpServers.m2.command' "$j")" y
  assert_eq "$(jq -r '.projects["/p"].allowedTools[0]' "$j")" mine
  assert_eq "$(jq -r '.projects["/q"].x' "$j")" 1
  assert_eq "$(jq -r '.oauthAccount.emailAddress' "$j")" work@example.com
}

test_rm_asks_and_keeps_history() {
  "$CP" add work >/dev/null
  "$CP" default work >/dev/null
  OUT=$(echo n | "$CP" rm work 2>&1) || true; assert_out "Cancelled"
  assert_file "$HOME/.claude-work"
  echo y | "$CP" rm work >/dev/null 2>&1
  assert_no_file "$HOME/.claude-work"
  assert_file "$HOME/.claude/projects"
  run default; assert_eq "$OUT" main
  run rm main; assert_fail
}

test_setup_token_saved_and_used() {
  "$CP" add work >/dev/null
  OUT=$(printf '  sk-ant-oat01-Abc_1-x \n' | "$CP" setup-token work 2>&1) || fail "$OUT"
  f=$HOME/.claude-work/.oauth-token
  assert_eq "$(cat "$f")" "sk-ant-oat01-Abc_1-x"
  [[ $(ls -l "$f") == -rw-------* ]] || fail "token file is not mode 600: $(ls -l "$f")"
  # Starting the profile passes the token, even over one inherited from the shell.
  CLAUDE_CODE_OAUTH_TOKEN=other run work -c; assert_ok
  assert_eq "$(cat "$STUB_OUT.token")" "sk-ant-oat01-Abc_1-x"
  # Other profiles don't get it.
  run main; assert_eq "$(cat "$STUB_OUT.token")" "<unset>"
  # --login: the regular login this once, and --login isn't passed to claude.
  CLAUDE_CODE_OAUTH_TOKEN=other run work --login -c; assert_ok
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|-c"
  assert_eq "$(cat "$STUB_OUT.token")" "<unset>"
  "$CP" default work >/dev/null
  run --login; assert_ok
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|"
  assert_eq "$(cat "$STUB_OUT.token")" "<unset>"
  "$CP" logout work >/dev/null
  run list; assert_out "work             not logged in"
  printf 'sk-ant-oat01-y\n' | "$CP" setup-token work >/dev/null 2>&1
  run list; assert_out "token login"
  run setup-token work --remove; assert_ok; assert_no_file "$f"
}

test_setup_token_rejects_bad_input() {
  "$CP" add work >/dev/null
  OUT=$(echo 'hello world' | "$CP" setup-token work 2>&1) && fail "accepted junk"
  assert_out "doesn't look like a token"; assert_no_file "$HOME/.claude-work/.oauth-token"
  run setup-token;            assert_fail; assert_out "profile name required"
  run setup-token ghost;      assert_fail; assert_out "No such profile"
  run setup-token work --bad; assert_fail; assert_out "usage"
  run add setup-token;        assert_fail; assert_out "command name"
  run config share .oauth-token; assert_fail
}

test_add_with_token() {
  OUT=$(echo 'sk-ant-oat01-z' | "$CP" add work --token 2>&1) || fail "$OUT"
  assert_eq "$(cat "$HOME/.claude-work/.oauth-token")" "sk-ant-oat01-z"
  assert_eq "$(jq -r '.oauthAccount // "none"' "$HOME/.claude-work/.claude.json")" none  # no auth login
  run rename work job; assert_ok; assert_out "token moved"
  assert_eq "$(cat "$HOME/.claude-job/.oauth-token")" "sk-ant-oat01-z"
}

test_shell_init_main_with_token() {
  run shell-init; assert_not_out "function claude {"
  echo 'sk-ant-oat01-m' | "$CP" setup-token main >/dev/null 2>&1
  init=$("$CP" shell-init); assert_eq "$(grep -c 'function claude {' <<<"$init")" 1
  bash -c "eval \"\$1\"; claude -p hi" _ "$init"
  assert_eq "$(cat "$STUB_OUT")" "|-p hi"
  assert_eq "$(cat "$STUB_OUT.token")" "sk-ant-oat01-m"
}

test_env_token_warning() {
  run doctor; assert_not_out "CLAUDE_CODE_OAUTH_TOKEN"
  CLAUDE_CODE_OAUTH_TOKEN=x run doctor; assert_out "overrides every profile's login"
  CLAUDE_CODE_OAUTH_TOKEN=x run status; assert_out "overrides every profile's login"
  # Inside Claude Code the session's own token is expected.
  CLAUDECODE=1 CLAUDE_CODE_OAUTH_TOKEN=x run doctor; assert_not_out "CLAUDE_CODE_OAUTH_TOKEN"
}

test_rename() {
  "$CP" add work >/dev/null
  "$CP" default work >/dev/null
  run rename work job; assert_ok
  assert_no_file "$HOME/.claude-work"
  assert_file "$HOME/.claude-job/.claude-profile"
  assert_eq "$(jq -r '.oauthAccount.emailAddress' "$HOME/.claude-job/.claude.json")" job@example.com
  run default; assert_eq "$OUT" job
}

test_rename_main_changes_setting() {
  run rename main personal; assert_ok
  run list; assert_out "personal"
}

test_doctor_repairs_links_and_adopts() {
  "$CP" add work >/dev/null
  mkdir "$HOME/.claude/agents"                        # created in main after the profile
  mkdir -p "$HOME/.claude-old"; echo '{}' > "$HOME/.claude-old/.claude.json"
  ln -s "$HOME/.claude/projects" "$HOME/.claude-old/projects"
  run doctor
  assert_link "$HOME/.claude-work/agents"
  assert_out "adopted existing profile"
  assert_file "$HOME/.claude-old/.claude-profile"
}

test_doctor_reports_diverged_file() {
  "$CP" add work >/dev/null
  rm "$HOME/.claude-work/settings.json"; echo '{}' > "$HOME/.claude-work/settings.json"
  run doctor; assert_out "diverged"
}

test_status() {
  "$CP" add work >/dev/null
  "$CP" logout work >/dev/null
  run status; assert_ok
  assert_out "main@example.com"; assert_out "not logged in"
}

test_shell_init() {
  "$CP" add work >/dev/null
  run shell-init; assert_ok
  assert_out "alias claude-work='$CP use work'"
  assert_out "alias claude-main="
  assert_not_out "claude() {"
  "$CP" default work >/dev/null
  run shell-init; assert_out "export CLAUDE_CONFIG_DIR='$HOME/.claude-work'"; assert_out "function claude {"
  # The generated code must be valid for both shells it targets.
  bash -n <<<"$OUT"
  if command -v zsh >/dev/null; then zsh -n <<<"$OUT"; fi
}

test_shell_init_with_user_claude_alias() {
  # A user alias named claude must not break the generated function (it did with `claude() {`).
  "$CP" add work >/dev/null
  "$CP" default work >/dev/null
  "$CP" shell-init > "$T/init.sh"
  # A script file, one command per line: an alias only applies to lines read after it is
  # defined, and `zsh -c` parses its whole string up front. $PATH starts with the fake claude.
  printf '%s\n' "alias claude='claude --flag'" ". '$T/init.sh'" 'claude x' > "$T/user.sh"
  bash -O expand_aliases "$T/user.sh" >/dev/null 2>"$T/err"
  assert_eq "$(cat "$T/err")" ""
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|--flag x"
  if command -v zsh >/dev/null; then
    rm -f "$STUB_OUT"
    zsh -f "$T/user.sh" >/dev/null 2>"$T/err"
    assert_eq "$(cat "$T/err")" ""
    assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|--flag x"
  fi
}

test_shell_init_function_inside_claude_code() {
  # Inside a Claude Code session the function must run the real claude with the session's
  # own config dir, not switch to the default profile.
  "$CP" add work >/dev/null
  "$CP" add other >/dev/null
  "$CP" default work >/dev/null
  init=$("$CP" shell-init)
  CLAUDECODE=1 CLAUDE_CONFIG_DIR=$HOME/.claude-other bash -c "eval \"\$1\"; claude -p hi" _ "$init"
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-other|-p hi"
  bash -c "eval \"\$1\"; claude -p hi" _ "$init"
  assert_eq "$(cat "$STUB_OUT")" "$HOME/.claude-work|-p hi"
}

test_requires_main_login() {
  rm "$HOME/.claude.json"
  run add work; assert_fail; assert_out "log in once"
}

test_invalid_config_file() {
  mkdir -p "$XDG_CONFIG_HOME/claude-profile"
  echo 'main=Bad Name' > "$XDG_CONFIG_HOME/claude-profile/config"
  run list; assert_fail; assert_out "invalid"
}

for fn in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do t "${fn#test_}" "$fn"; done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
