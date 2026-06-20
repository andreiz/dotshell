#!/usr/bin/env bash
# Run all tests/test_*.sh; non-zero exit if any fail.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
rc=0
for t in test_*.sh; do
    [[ -f "$t" ]] || continue
    echo "### $t"
    if ! bash "$t"; then
        rc=1
    fi
    echo
done
exit $rc
