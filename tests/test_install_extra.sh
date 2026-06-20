#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"
source "$DIR/../install.sh"   # main() is source-guarded; sourcing must not run it
set +e                         # install.sh sets -e; disable for assertions

parse_args foo bar --extra=laptop
assert_eq "${MODULES[*]}" "foo bar" "modules collected, --extra stripped"
assert_eq "$DOTSHELL_EXTRA" "laptop" "extra value parsed"

parse_args all
assert_eq "${MODULES[*]}" "all" "all is treated as a module arg"
assert_eq "$DOTSHELL_EXTRA" "" "extra empty when flag absent"

parse_args mod --force-casks
assert_eq "${MODULES[*]}" "mod" "--force-casks stripped from modules"
assert_eq "$DOTSHELL_FORCE_CASKS" "1" "--force-casks parsed"
parse_args mod
assert_eq "$DOTSHELL_FORCE_CASKS" "" "force-casks empty when flag absent"

should_skip_optional all true      && r=skip || r=run; assert_eq "$r" skip "optional skipped under all"
should_skip_optional explicit true && r=skip || r=run; assert_eq "$r" run  "optional runs when explicit"
should_skip_optional all ""        && r=skip || r=run; assert_eq "$r" run  "non-optional runs under all"

finish
