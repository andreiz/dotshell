# Design: `brew` module for dotshell

**Date:** 2026-06-19
**Status:** Approved (pending implementation plan)

## Purpose

Add a dotshell module that manages Homebrew **packages** (formulae, casks, taps)
via a curated `Brewfile`, with support for machine-specific extras (e.g. desktop
vs. laptop). Homebrew itself is already installed by `bootstrap.sh`; this module
only installs the packages listed in the Brewfile(s).

Mac App Store apps (`mas`) are intentionally **out of scope** — they are handled
by manual App Store installs.

## Background

- The old `~/projects/dotfiles/brew/Brewfile` (June 2024) is stale: 77 entries
  vs. ~165 currently installed (79 formulae, 63 casks, 23 mas). The system no
  longer satisfies it.
- dotshell currently models variation only via OS overlays (`overlays/<os>/`).
  There is no concept of a per-machine profile. This module introduces a
  lightweight, generic mechanism (`--extra=<name>`) for machine-specific
  package sets.
- Precedent: the `macos` module is run-only (`no_stow=true`, `requires_os=darwin`,
  work done in `post_install`). The `brew` module follows the same shape.

## Module structure

```
modules/brew/
  Brewfile            # shared base: taps + formulae + casks common to ALL machines
  Brewfile.desktop    # desktop-only formulae AND casks
  Brewfile.laptop     # laptop-only formulae AND casks
  module.sh           # requires_os="darwin", no_stow=true, optional=true, post_install
```

- `no_stow=true` — nothing is symlinked into `$HOME`; the Brewfiles are run-only,
  not dotfiles.
- `requires_os="darwin"` — skipped on Linux (casks are macOS-only).
- `optional=true` — new convention (see below); excludes the module from
  `./install.sh all`.
- Each `Brewfile.<name>` is a normal Brewfile and may contain **formulae, casks,
  and taps** in any mix — not just casks.

## `--extra=<name>` flag

- `./install.sh brew` → installs base `Brewfile` only.
- `./install.sh brew --extra=desktop` → installs base `Brewfile` **then**
  `Brewfile.desktop`.
- `--extra=<name>` maps generically to `Brewfile.<name>`. If the named file does
  not exist, fail with a clear error.
- No persistence, no machine auto-detection. Omitting the flag installs base only.

## `install.sh` changes

1. **Argument parsing**: today every positional arg is treated as a module name.
   Add handling for `--extra=<name>` (strip it from the module list, export it as
   `DOTSHELL_EXTRA` so a module's `post_install` can read it). The flag is generic;
   modules that don't use it simply ignore it.
2. **`optional=true` convention**: `module.sh` may set `optional=true`. When
   `install_module` is invoked from the `all` loop, modules with `optional=true`
   are skipped with a notice (e.g. `Skipping 'brew' (optional; run explicitly)`).
   When invoked by explicit name (`./install.sh brew`), it always runs. This is
   implemented by passing the call context into `install_module` (a second arg
   indicating `all` vs. explicit).
3. **`list` annotation**: show `brew (darwin only, optional)`.

`optional=true` is a reusable convention for any future heavy/opt-in module.

## `post_install` behavior

Given `DOTSHELL_EXTRA` (possibly empty) and `MODULE_DIR`:

1. `brew bundle install --file="${MODULE_DIR}/Brewfile"` (additive; installs
   missing, removes nothing; idempotent).
2. If `DOTSHELL_EXTRA` is set:
   - If `${MODULE_DIR}/Brewfile.${DOTSHELL_EXTRA}` exists →
     `brew bundle install --file="${MODULE_DIR}/Brewfile.${DOTSHELL_EXTRA}"`.
   - Else → `error` and non-zero exit.
3. **Drift report** (informational, removes nothing): concatenate the base
   `Brewfile` and the selected `Brewfile.<extra>` (if any) into a temp file, then
   run `brew bundle cleanup --file=<temp> --dry-run` and print the result as
   "installed but not in your Brewfile(s) — review". Caveat: with base-only (no
   `--extra`), this list will include machine-specific packages; that is expected
   and clearly labeled.

## Curation workflow (one-time content step)

Produces the actual Brewfile contents before/at implementation:

1. **Dump current state** (no mas):
   `brew bundle dump --file=- --formula --cask --tap --describe`
   (`--describe` adds an explanatory comment per entry.)
2. **Diff against the old 2024 Brewfile** to surface the ~88 additions vs. carried-over
   entries.
3. **Triage interactively**: present additions grouped (formulae / casks). The user
   sorts each into base vs. a machine extra (`desktop`/`laptop`), and drops one-offs
   /experiments. Previously commented-out entries (e.g. `bettertouchtool`, `zoom`)
   are surfaced so the user decides whether to keep them excluded.
4. **Finalize** the three files with light section headers (Taps / Formulae / Casks),
   deduped (old `bat` and `private-internet-access` duplicates removed).

## mas apps (dropped)

Not installed by this module. The App Store apps from the old Brewfile (Bear,
Things, Slack, Tailscale, etc.) are recorded in a comment block at the bottom of
the base `Brewfile` as a manual-install reminder — no active `mas` lines.

## Out of scope / non-goals

- No `mas` automation.
- No machine auto-detection (hostname/marker files) — explicit `--extra` only.
- No Linux support (`requires_os=darwin`).
- No automatic uninstall of drift (`cleanup` is dry-run only).
- Not run by `./install.sh all`.

## Fresh-machine flow

1. `bootstrap.sh` → Homebrew + stow installed.
2. `./install.sh brew --extra=laptop` (or `desktop`) → base + machine packages
   installed; App Store apps installed manually.
