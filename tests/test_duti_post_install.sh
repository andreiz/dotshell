#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"
source "$DIR/../lib/common.sh"   # info/substep/success

TMP="$(mktemp -d)"
export DUTI_LOG="$TMP/log"; : > "$DUTI_LOG"
export MODULE_DIR="$TMP/mod"; mkdir -p "$MODULE_DIR"
printf 'app.cyan.markedit  .md  all\n' > "$MODULE_DIR/duti.conf"

# A `duti` stub that logs its args
mkdir -p "$TMP/bin"
cat > "$TMP/bin/duti" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$DUTI_LOG"
exit 0
STUB
chmod +x "$TMP/bin/duti"
mkdir -p "$TMP/empty"   # a PATH dir with no `duti`

source "$DIR/../modules/duti/module.sh"

# Case 1: duti present -> applies the conf
PATH="$TMP/bin:$PATH" post_install >/dev/null 2>&1; rc=$?
log="$(cat "$DUTI_LOG")"
assert_eq "$rc" "0" "post_install succeeds when duti present"
assert_contains "$log" "$MODULE_DIR/duti.conf" "applies the duti.conf"

# Case 2: duti absent -> graceful skip (rc 0, no invocation, no crash)
: > "$DUTI_LOG"
PATH="$TMP/empty" post_install >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "post_install succeeds (skips) when duti absent"
assert_eq "$(cat "$DUTI_LOG")" "" "duti not invoked when absent"

finish
