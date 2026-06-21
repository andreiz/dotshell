# Vim Cleanup Status (2026-06-20)

After a Homebrew cleanup broke several things, here's what was fixed and what's left.

## Root Cause

`brew cleanup` removed or upgraded packages that Vim plugins and pyenv depended on. Additionally, re-running `dotshell/install.sh vim` cloned fresh vim-airline into `pack/plugins/start/`, creating duplicates with the older `pack/vendor/start/` copies.

## Fixed

### 1. Homebrew vim not on PATH
`/etc/zprofile` runs `path_helper` which reorders PATH, burying `/opt/homebrew/bin` behind `/usr/bin`. The system Vim (9.1, Normal build) was being used instead of Homebrew's (9.2, Huge build).

**Fix:** Added Homebrew PATH re-prepend to `~/.zshrc` (line 44 in `modules/zsh/.zshrc`).

### 2. vim-airline `E117: Unknown function: airline#util#has_multiline`
Two copies of vim-airline were installed:
- `pack/plugins/start/vim-airline/` — June 2026 (from dotshell install)
- `pack/vendor/start/vim-airline/` — December 2025 (old manual install)

The new `init.vim` called `has_multiline()` (added April 2026) but the old `util.vim` from vendor won the autoload race and didn't have it.

**Fix:** Removed duplicate `vim-airline` and `vim-airline-themes` from `pack/vendor/start/`.

### 3. `E1511: Wrong number of characters for field "tab"` (2-second startup delay)
Vim 9.2 requires `scriptencoding utf-8` for multibyte characters in `listchars` to be counted correctly. Without it, `tab:»·\ ` was rejected.

**Fix:** Added `scriptencoding utf-8` to top of `.vimrc`.

### 4. pyenv Python 3.13.0 blake2b/blake2s errors
`exec zsh` produced OpenSSL hash errors. Python 3.13.0 was compiled against an older OpenSSL that was upgraded during cleanup.

**Resolved (verified 2026-06-20).** No `--force` reinstall was needed — the base 3.13.0 now links the current OpenSSL 3.6.2 and all hashlib algorithms work (`blake2b`, `blake2s`, `sha256`, `sha3_256`, `md5` all OK). `python -c "import ssl; print(ssl.OPENSSL_VERSION)"` reports `OpenSSL 3.6.2`. No remaining hash errors.

### 5. Slow Vim startup for certain filetypes (~600-700ms)
Files like `Brewfile` (ft=brewfile) and `duti.conf` (ft=conf) took ~700ms to open. Files like `bootstrap.sh` (ft=sh) open in ~35ms.

**Root cause:** vim-polyglot's built-in sleuth (indent auto-detection) runs on `BufEnter`. When it can't guess indent from the file's own content, it globs neighboring files matching the filetype pattern and reads them. For `*.conf`, this matches many files across 3 directory levels. For `sh`, it guesses from the file itself and returns immediately.

**Resolved (verified 2026-06-20).** `let g:polyglot_disabled = ['autoindent']` in `.vimrc` works and loads early enough — the worry about load order was unfounded (native `pack/*/start/` packages do load after the vimrc in Vim 8+). Measured in a directory of 160 `.conf` files: **35ms with the fix vs 318ms without**. The `.conf`-vs-`.sh` differential is now ~20ms.

> Measurement note: `vim … >/dev/null` adds a spurious fixed ~2s "Output is not to a terminal" warning delay. Measure inside a real pty (`script -q /dev/null vim --startuptime …`) to get accurate numbers.

### 6. Stale `pack/vendor/start/` plugins
These remained from an old manual setup, predating the dotshell installer.

**Resolved (2026-06-20).** Deleted `pack/vendor/` entirely. `gruvbox` and `onedark.vim` (unused colorschemes — everforest is active) and `vim-sensible` (redundant with Vim 9.2 defaults) were dropped. `vim-fugitive` and `vim-surround` were migrated to dotshell-managed `pack/plugins/start/` via `modules/vim/module.sh`. Verified both load: `:Git` exists (fugitive) and `ds`/`cs`/`ys` map to `<Plug>` targets with `g:loaded_surround=1` (surround). Vim starts clean with no errors.

## Files Changed

| File | Change |
|------|--------|
| `modules/zsh/.zshrc` | Added Homebrew PATH fix (line 44-46) |
| `modules/vim/.vimrc` | Added `scriptencoding utf-8`, `g:polyglot_disabled` |
| `modules/vim/module.sh` | Added vim-fugitive and vim-surround install blocks |
| `~/.vim/pack/vendor/` | Deleted entirely (gruvbox, onedark.vim, vim-sensible removed; fugitive + surround migrated) |
| `~/.vim/pack/plugins/start/vim-fugitive/` | Cloned (dotshell-managed) |
| `~/.vim/pack/plugins/start/vim-surround/` | Cloned (dotshell-managed) |
| `~/.vim/pack/vendor/start/vim-airline/` | Deleted (earlier) |
| `~/.vim/pack/vendor/start/vim-airline-themes/` | Deleted (earlier) |
| `~/.vim/pack/plugins/start/vim-airline/autoload/airline/util.vim` | Reverted (early `has_multiline` def removed after finding the real cause) |
