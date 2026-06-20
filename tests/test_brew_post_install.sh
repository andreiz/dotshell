#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"
source "$DIR/../lib/common.sh"   # info/substep/error

TMP="$(mktemp -d)"
export BREW_LOG="$TMP/log"; : > "$BREW_LOG"
export BREW_COMBINED="$TMP/combined"; : > "$BREW_COMBINED"
export XDG_STATE_HOME="$TMP/state"          # isolate the drift-union state file
mkdir -p "$TMP/bin"; make_brew_stub "$TMP/bin"; export PATH="$TMP/bin:$PATH"
export MODULE_DIR="$TMP/mod"; mkdir -p "$MODULE_DIR"
printf 'brew "base1"\n'    > "$MODULE_DIR/Brewfile"
printf 'cask "desktop1"\n' > "$MODULE_DIR/Brewfile.desktop"
printf 'cask "laptop1"\n'  > "$MODULE_DIR/Brewfile.laptop"

source "$DIR/../modules/brew/module.sh"

export DOTSHELL_FORCE_CASKS=""   # default off unless a case opts in

# Case 1: base only, cleanup reports no drift
export DOTSHELL_EXTRA=""
export BREW_CLEANUP_RC=0
out="$(post_install)"; rc=$?
log="$(cat "$BREW_LOG")"
assert_eq "$rc" "0" "post_install succeeds"
assert_contains "$log" "bundle install --file=$MODULE_DIR/Brewfile" "base install invoked"
assert_not_contains "$log" "bundle install --file=$MODULE_DIR/Brewfile.laptop" "extra NOT installed without --extra"
assert_contains "$log" "bundle cleanup" "drift check invoked"
assert_not_contains "$log" "--dry-run" "cleanup does not pass invalid --dry-run"
assert_not_contains "$log" "--force" "cleanup never uses --force (never uninstalls)"
# Drift compares against the UNION of ALL Brewfiles, even with no --extra, so
# machine-specific packages tracked for other machines are not falsely flagged.
combined="$(cat "$BREW_COMBINED")"
assert_contains "$combined" "base1" "drift union includes base"
assert_contains "$combined" "desktop1" "drift union includes desktop extra"
assert_contains "$combined" "laptop1" "drift union includes laptop extra"
assert_not_contains "$out" "Review" "no drift pointer when cleanup is clean"

# Case 2: cleanup reports drift -> quiet pointer printed, still succeeds
: > "$BREW_LOG"
export BREW_CLEANUP_RC=1
out="$(post_install)"; rc=$?
assert_eq "$rc" "0" "post_install succeeds even when drift exists"
assert_contains "$out" "brew bundle cleanup --file=" "prints quiet review pointer on drift"

# Case 3: with --extra, the extra is installed
: > "$BREW_LOG"
export BREW_CLEANUP_RC=0
export DOTSHELL_EXTRA="laptop"
post_install >/dev/null; rc=$?
log="$(cat "$BREW_LOG")"
assert_contains "$log" "bundle install --file=$MODULE_DIR/Brewfile.laptop" "extra install invoked with --extra"

# Case 4: missing extra errors
: > "$BREW_LOG"
export DOTSHELL_EXTRA="nope"
post_install >/dev/null 2>&1; rc=$?
assert_eq "$rc" "1" "missing extra Brewfile returns non-zero"

# Case 5: --force-casks adds --force to install (opt-in)
: > "$BREW_LOG"
export DOTSHELL_EXTRA=""
export BREW_CLEANUP_RC=0
export DOTSHELL_FORCE_CASKS=1
post_install >/dev/null
log="$(cat "$BREW_LOG")"
assert_contains "$log" "bundle install --file=$MODULE_DIR/Brewfile --force" "force-casks passes --force to bundle install"
export DOTSHELL_FORCE_CASKS=""

finish
