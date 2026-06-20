#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"
source "$DIR/../lib/common.sh"   # info/substep/error

TMP="$(mktemp -d)"
export BREW_LOG="$TMP/log"; : > "$BREW_LOG"
export BREW_COMBINED="$TMP/combined"; : > "$BREW_COMBINED"
mkdir -p "$TMP/bin"; make_brew_stub "$TMP/bin"; export PATH="$TMP/bin:$PATH"
export MODULE_DIR="$TMP/mod"; mkdir -p "$MODULE_DIR"
printf 'brew "base1"\n' > "$MODULE_DIR/Brewfile"
printf 'cask "laptop1"\n' > "$MODULE_DIR/Brewfile.laptop"

source "$DIR/../modules/brew/module.sh"

# Case 1: base only
export DOTSHELL_EXTRA=""
post_install; rc=$?
log="$(cat "$BREW_LOG")"
assert_eq "$rc" "0" "post_install succeeds (drift report does not abort it)"
assert_contains "$log" "bundle install --file=$MODULE_DIR/Brewfile" "base install invoked"
assert_contains "$log" "bundle cleanup" "drift report invoked"
# `brew bundle cleanup` has no --dry-run flag; the no---force default IS the dry run.
assert_not_contains "$log" "--dry-run" "cleanup does not pass invalid --dry-run"
assert_not_contains "$log" "--force" "cleanup never uses --force (never uninstalls)"

# Case 2: with extra
: > "$BREW_LOG"
export DOTSHELL_EXTRA="laptop"
post_install
log="$(cat "$BREW_LOG")"
assert_contains "$log" "bundle install --file=$MODULE_DIR/Brewfile.laptop" "extra install invoked"
combined="$(cat "$BREW_COMBINED")"
assert_contains "$combined" "base1" "drift combined includes base"
assert_contains "$combined" "laptop1" "drift combined includes extra"

# Case 3: missing extra errors
: > "$BREW_LOG"
export DOTSHELL_EXTRA="nope"
post_install; rc=$?
assert_eq "$rc" "1" "missing extra Brewfile returns non-zero"

finish
