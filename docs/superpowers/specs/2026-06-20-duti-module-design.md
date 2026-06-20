# Design: `duti` module for dotshell

**Date:** 2026-06-20
**Status:** Approved (pending implementation plan)

## Purpose

Add a dotshell module that declaratively sets macOS default applications for file
types (and URL schemes) using [`duti`](https://github.com/moretension/duti). The
module applies a tracked config file so default-app associations are reproducible
across machines.

## Background

- `duti` applies a settings file: `duti <file>`. Each line is
  `<bundle-id>  <ext|UTI|url-scheme>  <role>`.
- Verified behavior (2026-06-20): both `duti -s` and the settings file accept a
  bare **extension** with a leading dot (e.g. `.md`), not only UTIs — so the
  config can be written in human-friendly extension form. UTIs and URL schemes
  (e.g. `http`) are still supported where an extension does not apply.
- `duti` has **no dump command** — it cannot export all current associations. The
  config is authored, but can be *seeded* by querying current handlers with
  `duti -x <ext>` (returns the current handler's app, path, and bundle id).
- `duti` is idempotent: re-applying the same mappings has no adverse effect.
- Precedent: the `macos` module is run-only (`no_stow=true`, `requires_os=darwin`,
  work done in `post_install`). The `duti` module follows the same shape but is
  **not** run-once guarded (it re-applies every run).

## Module structure

```
modules/duti/
  duti.conf      # default-app mappings (seeded from current handlers, then curated)
  module.sh      # requires_os="darwin", no_stow=true, post_install
```

- `requires_os="darwin"` — macOS only; the `all` loop auto-skips it on Linux.
- `no_stow=true` — nothing symlinked into `$HOME`; `duti.conf` is applied, not linked.
- Runs as part of `./install.sh all` (and explicitly). **No run-once marker** — it
  re-applies each run, harmlessly re-asserting associations if something changed them.

## `post_install` behavior

```
post_install():
  if `duti` is not on PATH:
      warn "duti not installed; skipping default-app associations"
      return 0                      # optional dependency, not a hard error
  info "Applying default-app associations (duti)"
  duti "${MODULE_DIR}/duti.conf"
  success "default-app associations applied"
```

The `duti` formula is expected to be installed (it is `[b]` in the brew Brewfile),
but the module must degrade gracefully if it is absent.

## Config format (`duti.conf`)

Native `duti` settings file. One mapping per line:
`<bundle-id>  <ext|UTI|url-scheme>  <role>`, `#` comments allowed, grouped by
category. Extension form preferred for readability; UTI/scheme used where needed.

```
# Text & code
app.cyan.markedit         .md     all
com.microsoft.VSCode      .json   all

# Web (URL scheme — not an extension)
org.mozilla.firefox       http    all
```

`role` is `all` (viewer + editor) unless a narrower role is intentionally wanted.

### Day-to-day: assigning a new app to an extension

1. Get the app's bundle id: `osascript -e 'id of app "<App Name>"'`
   (or inspect the current handler: `duti -x <ext>`).
2. Add/edit a line in `modules/duti/duti.conf`:  `<bundle-id>  .<ext>  all`.
3. Re-apply:  `./install.sh duti`  (or `duti modules/duti/duti.conf`).
   Quick one-off test before committing: `duti -s <bundle-id> .<ext> all`.

## Seeding the initial config (one-time, at build)

Query current handlers for a curated extension set and emit
`<bundle-id>  .<ext>  all` lines, grouped with comments:

- Text/code: `txt md json yaml toml xml csv log sh py js ts html css`
- Media: `png jpg gif mp4 mov mp3 pdf`
- Archives: `zip tar gz`

For each extension, `duti -x <ext>` yields the current handler's bundle id (3rd
output line). URL schemes (`http`, `mailto`) are not queryable this way and are
added as commented examples for the user to fill in. The user prunes/adjusts the
generated file before it is committed.

## Testing

`post_install` is testable with a `duti` stub on `PATH` (same pattern as the brew
module test in `tests/`). No real associations are touched.

- **Applies config:** with a stub `duti` that logs its args and a temp
  `MODULE_DIR/duti.conf`, calling `post_install` invokes `duti <MODULE_DIR>/duti.conf`.
- **Graceful skip:** with no `duti` on `PATH`, `post_install` returns 0 and does
  not invoke duti (warns instead).

## Out of scope / non-goals

- No dumping/syncing of the full current association set (duti can't, and we don't
  try to keep duti.conf in lockstep with the live system).
- No run-once guard (re-apply is cheap and idempotent).
- No Linux support (`requires_os=darwin`).
- The module does not install `duti` itself (that's the brew module's job); it only
  degrades gracefully if absent.

## Fresh-machine flow

1. `./install.sh brew` (installs `duti` among other packages).
2. `./install.sh all` (or `./install.sh duti`) → applies `duti.conf`.
