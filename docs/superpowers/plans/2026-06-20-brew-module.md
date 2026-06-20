# Brew Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in dotshell `brew` module that installs Homebrew packages from a curated base `Brewfile` plus optional per-machine extras selected via `./install.sh brew --extra=<name>`.

**Architecture:** Run-only module (`no_stow=true`, `requires_os="darwin"`) mirroring the existing `macos` module. Its `post_install` runs `brew bundle install` against the base Brewfile and, when `--extra=<name>` is passed, against `Brewfile.<name>`, then prints a dry-run drift report. `install.sh` gains generic `--extra=<name>` parsing and an `optional=true` convention that excludes a module from `./install.sh all` while still allowing explicit invocation.

**Tech Stack:** Bash, GNU Stow, Homebrew (`brew bundle`). Tests are plain-bash scripts with a `brew` stub — no test framework dependency.

## Global Constraints

- Bash only; no new runtime dependencies (tests add no framework — plain bash).
- `brew` module is macOS-only: `requires_os="darwin"`.
- `brew` module is run-only: `no_stow=true` (nothing symlinked into `$HOME`).
- `brew` module is opt-in: `optional=true` (excluded from `./install.sh all`).
- No `mas` automation — App Store apps are manual; recorded only as a comment block in the base `Brewfile`.
- `--extra=<name>` maps to `modules/brew/Brewfile.<name>`; missing file → clear error, non-zero exit.
- Drift report is **dry-run only** (`brew bundle cleanup --dry-run`) — never uninstalls.
- Use existing logging helpers from `lib/common.sh`: `info`, `substep`, `success`, `error`.
- Follow existing module conventions (see `modules/macos/module.sh`).

---

## File Structure

- **Modify** `install.sh` — add `parse_args()` (extract `--extra=`), `should_skip_optional()` helper, `main()` wrapper with source-guard, `optional` handling in `install_module`, and `list` annotation.
- **Create** `modules/brew/module.sh` — `requires_os`, `no_stow`, `optional`, `post_install`.
- **Create** `modules/brew/Brewfile` — curated shared base (taps + formulae + casks; mas as comment).
- **Create** `modules/brew/Brewfile.desktop` — desktop-only formulae + casks.
- **Create** `modules/brew/Brewfile.laptop` — laptop-only formulae + casks.
- **Create** `tests/lib.sh` — assertion + `brew` stub helpers.
- **Create** `tests/run.sh` — runs all `tests/test_*.sh`.
- **Create** `tests/test_install_extra.sh` — `parse_args` + `should_skip_optional` unit tests.
- **Create** `tests/test_brew_post_install.sh` — `post_install` command-sequence tests.
- **Modify** `README.md` — document the module, `--extra`, and `optional` convention.

---

## Task 1: Test harness

**Files:**
- Create: `tests/lib.sh`
- Create: `tests/run.sh`

**Interfaces:**
- Produces (sourced by other tests):
  - `assert_eq <actual> <expected> <name>` — pass if equal.
  - `assert_contains <haystack> <needle> <name>` — pass if substring present.
  - `make_brew_stub <dir>` — writes an executable `brew` into `<dir>` that appends `"$*"` to `$BREW_LOG`; on `bundle cleanup`, copies the `--file=` target to `$BREW_COMBINED`.
  - `finish` — prints summary, returns non-zero if any assertion failed.
- `tests/run.sh` — executes every `tests/test_*.sh`, aggregates exit status.

- [ ] **Step 1: Create `tests/lib.sh`**

```bash
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
```

- [ ] **Step 2: Create `tests/run.sh`**

```bash
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
```

- [ ] **Step 3: Make scripts executable**

Run: `chmod +x tests/run.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Verify harness runs with no tests yet**

Run: `bash tests/run.sh`
Expected: exits 0, no `### test_*.sh` lines (no test files yet).

- [ ] **Step 5: Commit**

```bash
git add tests/lib.sh tests/run.sh
git commit -m "test: add plain-bash test harness for dotshell"
```

---

## Task 2: `install.sh` — `--extra` parsing and `optional` skip helper

**Files:**
- Modify: `install.sh` (wrap dispatch in `main()` + source-guard; add `parse_args()` and `should_skip_optional()`)
- Test: `tests/test_install_extra.sh`

**Interfaces:**
- Produces:
  - `parse_args "$@"` — sets global array `MODULES` (positional args, including `all`/`list`) and global `DOTSHELL_EXTRA` (from `--extra=<name>`, else empty); exports `DOTSHELL_EXTRA`; errors and exits 1 on unknown `--flag` or bare `--extra` without `=`.
  - `should_skip_optional <context> <optional_flag>` — returns 0 (skip) only when `context == "all"` AND `optional_flag == "true"`.
  - `main "$@"` — runs only when the script is executed directly (source-guard), so tests can source `install.sh` without triggering it.

- [ ] **Step 1: Write the failing test — `tests/test_install_extra.sh`**

```bash
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

should_skip_optional all true     && r=skip || r=run; assert_eq "$r" skip "optional skipped under all"
should_skip_optional explicit true && r=skip || r=run; assert_eq "$r" run  "optional runs when explicit"
should_skip_optional all ""        && r=skip || r=run; assert_eq "$r" run  "non-optional runs under all"

finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_install_extra.sh`
Expected: FAIL — sourcing `install.sh` currently executes the full script (no `main`/guard), and `parse_args`/`should_skip_optional` are undefined.

- [ ] **Step 3: Add `parse_args()` and `should_skip_optional()` to `install.sh`**

Insert these functions after `check_dependencies()` (after line 26, before `list_modules()`):

```bash
# Parse CLI args: separate module names from flags.
# Sets global MODULES (array) and DOTSHELL_EXTRA; exports DOTSHELL_EXTRA.
parse_args() {
    MODULES=()
    DOTSHELL_EXTRA=""
    local arg
    for arg in "$@"; do
        case "$arg" in
            --extra=*) DOTSHELL_EXTRA="${arg#--extra=}" ;;
            --extra)   error "--extra requires a value, e.g. --extra=laptop"; exit 1 ;;
            --*)       error "Unknown option: ${arg}"; exit 1 ;;
            *)         MODULES+=("$arg") ;;
        esac
    done
    export DOTSHELL_EXTRA
}

# True (skip) only for optional modules invoked via the `all` loop.
should_skip_optional() {
    local context="$1" optional_flag="$2"
    [[ "$context" == "all" && "$optional_flag" == "true" ]]
}
```

- [ ] **Step 4: Wrap the dispatch block in `main()` with a source-guard**

Replace the current bottom dispatch block (lines 113-150, from `[[ $# -eq 0 ]] && usage` through the `BACKED_UP` report) with:

```bash
main() {
    parse_args "$@"

    [[ ${#MODULES[@]} -eq 0 ]] && usage

    check_dependencies

    case "${MODULES[0]}" in
        list)
            echo "Available modules:"
            for module in $(list_modules); do
                local_requires=""
                local_optional=""
                if [[ -f "${DOTSHELL_DIR}/modules/${module}/module.sh" ]]; then
                    local_requires=$(grep -o 'requires_os="[^"]*"' "${DOTSHELL_DIR}/modules/${module}/module.sh" 2>/dev/null | cut -d'"' -f2 || true)
                    grep -q 'optional=true' "${DOTSHELL_DIR}/modules/${module}/module.sh" 2>/dev/null && local_optional="optional"
                fi
                local tags=""
                [[ -n "$local_requires" ]] && tags="${local_requires} only"
                [[ -n "$local_optional" ]] && tags="${tags:+${tags}, }optional"
                if [[ -n "$tags" ]]; then
                    echo "  ${module} (${tags})"
                else
                    echo "  ${module}"
                fi
            done
            ;;
        all)
            for module in $(list_modules); do
                install_module "$module" "all"
            done
            ;;
        *)
            for module in "${MODULES[@]}"; do
                install_module "$module" "explicit"
            done
            ;;
    esac

    if [[ ${#BACKED_UP[@]} -gt 0 ]]; then
        info "Backed up ${#BACKED_UP[@]} existing file(s):"
        for f in "${BACKED_UP[@]}"; do
            substep "$f"
        done
    fi
}

# Run main only when executed directly, not when sourced (enables tests).
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_install_extra.sh`
Expected: all `ok:` lines, final `6/6 passed`, exit 0.

- [ ] **Step 6: Smoke-test real invocation still works**

Run: `./install.sh list`
Expected: prints "Available modules:" and the existing modules (no errors). `macos` still shows `(darwin only)`.

- [ ] **Step 7: Commit**

```bash
git add install.sh tests/test_install_extra.sh
git commit -m "feat(install): add --extra parsing and optional-module skip helper"
```

---

## Task 3: `install.sh` — wire `optional` skip into `install_module`

**Files:**
- Modify: `install.sh` (`install_module` accepts context, resets `optional`, skips when applicable)

**Interfaces:**
- Consumes: `should_skip_optional` (Task 2).
- Produces: `install_module <module> <context>` where `<context>` is `all` or `explicit` (defaults to `explicit`).

- [ ] **Step 1: Reset the `optional` var with the other per-module vars**

In `install_module`, find the "Reset per-module variables" block (currently lines 61-63):

```bash
    # Reset per-module variables
    local requires_os=""
    local no_stow=""
```

Replace with:

```bash
    # Reset per-module variables
    local requires_os=""
    local no_stow=""
    local optional=""
    local context="${2:-explicit}"
```

- [ ] **Step 2: Add the optional-skip check after `module.sh` is sourced**

Immediately after the `module.sh` sourcing block (after the `fi` that closes `if [[ -f "${module_dir}/module.sh" ]]; then ... fi`, currently around line 69) and before the OS-restriction check, insert:

```bash
    # Skip optional modules when running `all`; they must be invoked explicitly.
    if should_skip_optional "$context" "${optional:-}"; then
        substep "Skipping '${module}' (optional; run explicitly: ./install.sh ${module})"
        return 0
    fi
```

- [ ] **Step 3: Manually verify skip logic with a temporary optional module**

Run:
```bash
mkdir -p modules/_tmpopt
printf '#!/usr/bin/env bash\noptional=true\nno_stow=true\npost_install() { echo "RAN _tmpopt"; }\n' > modules/_tmpopt/module.sh
echo "--- all (should SKIP _tmpopt):"; ./install.sh all 2>&1 | grep -E "_tmpopt"
echo "--- explicit (should RUN _tmpopt):"; ./install.sh _tmpopt 2>&1 | grep -E "_tmpopt|RAN"
rm -rf modules/_tmpopt
```
Expected:
- Under `all`: a line `==== Skipping '_tmpopt' (optional; run explicitly: ./install.sh _tmpopt)`.
- Under explicit: `RAN _tmpopt` appears.

- [ ] **Step 4: Confirm cleanup**

Run: `ls modules/ | grep _tmpopt || echo "removed"`
Expected: `removed`.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat(install): skip optional modules during 'all'"
```

---

## Task 4: `brew` module `post_install`

**Files:**
- Create: `modules/brew/module.sh`
- Test: `tests/test_brew_post_install.sh`

**Interfaces:**
- Consumes: `MODULE_DIR` (exported by `install.sh` before calling `post_install`), `DOTSHELL_EXTRA` (Task 2), logging helpers from `common.sh`.
- Produces: `post_install()` that calls, in order: `brew bundle install --file=<base>`; if `DOTSHELL_EXTRA` set, `brew bundle install --file=<base>.<extra>` (error+return 1 if missing); then `brew bundle cleanup --file=<temp base+extra concat> --dry-run`.

- [ ] **Step 1: Write the failing test — `tests/test_brew_post_install.sh`**

```bash
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
post_install
log="$(cat "$BREW_LOG")"
assert_contains "$log" "bundle install --file=$MODULE_DIR/Brewfile" "base install invoked"
assert_contains "$log" "bundle cleanup" "drift report invoked"
assert_contains "$log" "--dry-run" "cleanup is dry-run only"

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_brew_post_install.sh`
Expected: FAIL — `modules/brew/module.sh` does not exist, so `source` fails / `post_install` undefined.

- [ ] **Step 3: Create `modules/brew/module.sh`**

```bash
#!/usr/bin/env bash

requires_os="darwin"
no_stow=true
optional=true

post_install() {
    local brewfile="${MODULE_DIR}/Brewfile"
    local files=("$brewfile")

    info "Installing base Brewfile packages"
    brew bundle install --file="$brewfile"

    if [[ -n "${DOTSHELL_EXTRA:-}" ]]; then
        local extra_file="${MODULE_DIR}/Brewfile.${DOTSHELL_EXTRA}"
        if [[ ! -f "$extra_file" ]]; then
            error "No Brewfile for extra '${DOTSHELL_EXTRA}' (expected ${extra_file})"
            return 1
        fi
        info "Installing extra Brewfile: ${DOTSHELL_EXTRA}"
        brew bundle install --file="$extra_file"
        files+=("$extra_file")
    fi

    # Drift report: list packages installed but not in the Brewfile(s).
    # Dry-run only — nothing is uninstalled.
    local combined
    combined="$(mktemp)"
    cat "${files[@]}" > "$combined"
    substep "Installed but not in your Brewfile(s) — review (nothing removed):"
    brew bundle cleanup --file="$combined" --dry-run || true
    rm -f "$combined"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_brew_post_install.sh`
Expected: all `ok:` lines, final `8/8 passed`, exit 0.

- [ ] **Step 5: Run full suite**

Run: `bash tests/run.sh`
Expected: both test files run, all pass, exit 0.

- [ ] **Step 6: Commit**

```bash
git add modules/brew/module.sh tests/test_brew_post_install.sh
git commit -m "feat(brew): add run-only module with base+extra install and drift report"
```

---

## Task 5: Curate and write the Brewfiles

**Files:**
- Create: `modules/brew/Brewfile`
- Create: `modules/brew/Brewfile.desktop`
- Create: `modules/brew/Brewfile.laptop`

**Note:** File *contents* are produced by `brew bundle dump` + interactive triage with the user — they cannot be hand-authored in advance because they depend on the user's keep/drop/which-machine decisions. The steps below give the exact commands and the triage procedure. This task has no unit test; it is validated with `brew bundle` parsing/check.

- [ ] **Step 1: Dump the current system state (no mas), excluding nothing else**

Run:
```bash
export HOMEBREW_NO_AUTO_UPDATE=1
brew bundle dump --file=- --formula --cask --tap --describe > /tmp/brewfile.dump
wc -l /tmp/brewfile.dump
```
Expected: a Brewfile-format dump (tap/brew/cask lines, each preceded by a `#` description comment), no `mas` lines.

- [ ] **Step 2: Diff against the old 2024 Brewfile to surface changes**

Run:
```bash
# Compare just the package identifiers (ignore descriptions/order)
diff <(grep -oE '^(brew|cask|tap) "[^"]+"' /tmp/brewfile.dump | sort) \
     <(grep -oE '^(brew|cask|tap) "[^"]+"' ~/projects/dotfiles/brew/Brewfile | sort)
```
Expected: `<` lines = present now but not in old file (the additions to triage); `>` lines = in old file but no longer installed.

- [ ] **Step 3: Generate an editable triage file**

Write `modules/brew/triage.md` listing every dumped formula and cask, each on its
own line **pre-tagged** with a single-letter bucket and a one-line note. Entries
are **grouped by bucket** under section headers (so same-bucket items are adjacent
for scanning); the bracket tag is the source of truth, the grouping is cosmetic.

Tag legend (kept at the top of the file):
```
# Triage — edit the [tag] on each line, save, then tell me to continue.
# [b] = base (all machines)   [d] = desktop   [l] = laptop   [r] = drop (don't track)
# A trailing "?" means it's my guess — confirm or change it.
```

Layout — group under headers, short tags, one entry per line:
```
## base
[b]  brew "ripgrep"      # fast grep; cross-machine CLI
[b]  cask "1password"    # password manager

## desktop?  (my guesses — confirm machine)
[d?] cask "daisydisk"    # disk viz — desktop or laptop?

## laptop?
[l?] cask "<app>"        # ...

## drop?  (one-offs — confirm removal)
[r?] cask "heynote"      # scratch-pad app — keep?

## previously disabled in old Brewfile (tag [b]/[d]/[l] to re-enable)
[r]  cask "zoom"
[r]  cask "transmit"
[r]  cask "bettertouchtool"
[r]  cask "betterzip"
[r]  cask "displaycal"
[r]  cask "fastrawviewer"
[r]  cask "photosync"
[r]  cask "viscosity"
[r]  cask "xee"
```

Bucketing rules for the pre-tags:
- CLI **formulae** → `[b]` by default.
- **Casks** clearly cross-machine (browsers, 1password, dropbox) → `[b]`; GUI apps
  whose machine is unclear → `[d?]`/`[l?]`.
- Likely one-offs/experiments → `[r?]` with a reason.
- Old file's previously-disabled entries → `[r]` (re-enable by retagging).

The user edits the single-letter tags inline (and may move lines between sections
or not — only the `[tag]` matters), saves, and tells the implementer to continue.
The implementer parses the final `[b]/[d]/[l]/[r]` tags to drive Steps 4-5.
`triage.md` is a scratch artifact — **delete it after the Brewfiles are written**
(do not commit it).

- [ ] **Step 4: Write `modules/brew/Brewfile` (base)**

Use this skeleton; fill the sections from the triage. Keep `--describe` comments. Remove duplicates (the old `bat` and `private-internet-access` dupes must not reappear).

```ruby
# dotshell base Brewfile — packages common to all machines.
# Install:  ./install.sh brew                (base only)
#           ./install.sh brew --extra=laptop  (base + Brewfile.laptop)
# App Store apps are installed manually (see bottom of this file).

# Taps
tap "homebrew/bundle"

# Formulae
brew "bat"
# ... (curated formulae)

# Casks
cask "1password"
# ... (curated casks)

# --- Mac App Store (install manually; not managed by brew) ---
# AdGuard for Safari, Bear, Disk Speed Test, Microsoft Remote Desktop,
# Pins, Slack, Tailscale, Things  (and any others you use)
```

- [ ] **Step 5: Write `modules/brew/Brewfile.desktop` and `modules/brew/Brewfile.laptop`**

Each is a normal Brewfile holding only that machine's extras (formulae AND/OR casks). Example shape:

```ruby
# dotshell desktop-only packages (layered on top of base Brewfile).
cask "daisydisk"
# ... desktop-only formulae/casks
```

```ruby
# dotshell laptop-only packages (layered on top of base Brewfile).
# ... laptop-only formulae/casks
```

- [ ] **Step 6: Validate the Brewfiles parse and base is satisfied**

Run:
```bash
export HOMEBREW_NO_AUTO_UPDATE=1
brew bundle list --file=modules/brew/Brewfile >/dev/null && echo "base parses"
brew bundle list --file=modules/brew/Brewfile.desktop >/dev/null && echo "desktop parses"
brew bundle list --file=modules/brew/Brewfile.laptop >/dev/null && echo "laptop parses"
brew bundle check --file=modules/brew/Brewfile && echo "base satisfied on this machine"
```
Expected: all four echo lines print (base "check" passes because base packages are installed on the current machine). If `check` reports missing base packages, move them out of base or install them — base must be satisfiable on the current machine.

- [ ] **Step 7: Delete the scratch triage file and commit**

```bash
rm -f modules/brew/triage.md
git status --short modules/brew/        # confirm triage.md is gone, only Brewfiles staged
git add modules/brew/Brewfile modules/brew/Brewfile.desktop modules/brew/Brewfile.laptop
git commit -m "feat(brew): add curated base + per-machine Brewfiles"
```

---

## Task 6: Documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add `brew` to the Modules table**

In `README.md`, the Modules table (lines 33-40), add this row after the `macos` row:

```markdown
| `brew` | Homebrew packages via `Brewfile` (+ per-machine extras) | macOS |
```

- [ ] **Step 2: Document the `--extra` flag and opt-in behavior in Usage**

In the `## Usage` section, after the existing code block (after line 29), add:

```markdown
The `brew` module is **opt-in** — it is excluded from `./install.sh all` and must be run explicitly. It installs packages from a curated Brewfile, with optional per-machine extras:

```bash
./install.sh brew                    # base Brewfile only
./install.sh brew --extra=laptop     # base + modules/brew/Brewfile.laptop
./install.sh brew --extra=desktop    # base + modules/brew/Brewfile.desktop
```

Mac App Store apps are not managed by `brew bundle`; install them manually (the base `Brewfile` lists them in a comment). After install, the module prints a dry-run drift report of packages installed but not in your Brewfile(s) — it never uninstalls anything.
```

- [ ] **Step 3: Note the `optional` convention in "Adding a Module"**

In the `## Adding a Module` section, after step 2 (line 53), add:

```markdown
   - Set `optional=true` in `module.sh` to exclude the module from `./install.sh all` (it will still run when named explicitly).
```

- [ ] **Step 4: Verify the README renders sensibly**

Run: `sed -n '23,45p' README.md`
Expected: the Usage section shows the new `brew`/`--extra` block and the Modules table includes the `brew` row.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: document brew module, --extra flag, and optional convention"
```

---

## Self-Review Notes

- **Spec coverage:** module structure (T4/T5), `--extra` flag (T2), `optional`/exclude-from-`all` (T2/T3), `post_install` install+extra+drift (T4), curation workflow incl. mas comment block (T5), README (T6). All spec sections mapped.
- **Type/name consistency:** `parse_args`→`MODULES`/`DOTSHELL_EXTRA`; `should_skip_optional` used by both Task 2 test and Task 3 wiring; `post_install` reads `MODULE_DIR`/`DOTSHELL_EXTRA`; brew stub contract (`$BREW_LOG`, `$BREW_COMBINED`) consistent across `tests/lib.sh` and `tests/test_brew_post_install.sh`.
- **Drift-report caveat** from spec (base-only includes machine packages) is preserved via the `substep` label "review (nothing removed)".
```
