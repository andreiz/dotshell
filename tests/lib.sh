#!/usr/bin/env bash
# Plain-bash test helpers. No framework.

TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$1" != "$2" ]]; then
        echo "FAIL: $3: expected [$2], got [$1]"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo "ok: $3"
    fi
}

assert_contains() {
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$1" != *"$2"* ]]; then
        echo "FAIL: $3: [$1] does not contain [$2]"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo "ok: $3"
    fi
}

# make_brew_stub <dir>: writes a fake `brew` that logs invocations to $BREW_LOG
# and, for `bundle cleanup`, copies the --file target to $BREW_COMBINED.
make_brew_stub() {
    cat > "$1/brew" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$BREW_LOG"
if [[ "${1:-}" == "bundle" && "${2:-}" == "cleanup" ]]; then
    for a in "$@"; do
        case "$a" in --file=*) cp "${a#--file=}" "$BREW_COMBINED" ;; esac
    done
fi
exit 0
STUB
    chmod +x "$1/brew"
}

finish() {
    echo "---"
    echo "$((TESTS_RUN - TESTS_FAILED))/${TESTS_RUN} passed"
    [[ $TESTS_FAILED -eq 0 ]]
}
