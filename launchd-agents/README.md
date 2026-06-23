# launchd-agents

Version-controlled user launchd agents for **wick**. Plists live here and are
symlinked into `~/Library/LaunchAgents`; they point at scripts in-place in this
repo (no copying, no per-machine migration).

Run `./install.sh` to build the runner bundles and symlink + (re)load every
agent. It's idempotent — each agent is `bootout`'d then `bootstrap`'d via the
modern `launchctl` API.

> This lives in dotshell but is **not** a stow module — it's imperative (compiles
> a binary, bootstraps services, needs manual TCC grants), so it has its own
> `install.sh` and is run by hand. Installed ~once per machine. The fleet catalog
> (`continental/devices/wick.md`) points here for rebuilds.

## Fresh-machine setup

The script automates the build/load; the rest is manual and easy to forget.

1. **Xcode Command Line Tools** (provides `clang` + `codesign`): `xcode-select --install`
2. **Build + load the agents:** `./install.sh`
3. **Grant TCC** (per the runner-bundle table below):
   - `AgentRunner.app` — allow the just-in-time **Downloads folder** prompt when
     heic2jpeg first fires (or AirDrop a HEIC to trigger it).
   - `AgentRunnerFDA.app` — add it manually under **System Settings → Privacy &
     Security → Full Disk Access** (FDA is not promptable).
4. **Set the Keychain secrets** — unscripted; if missing, the affected agents run
   but silently skip their Home Assistant calls:
   ```sh
   security add-generic-password -s ha-things-drain    -a "$USER" -w   # things-drain
   security add-generic-password -s ha-imessage-export -a "$USER" -w   # imessage-export
   ```
   (omit `-w` to be prompted, so the token never lands in shell history)

## TCC / privacy: the runner bundles

macOS attaches privacy permissions (Downloads/Documents/Desktop folder access,
Full Disk Access, …) to the executing **Mach-O binary or app bundle**, never to
a shell script. A LaunchAgent that runs a `.sh` directly can't get into
protected folders — the grant would have to land on `/bin/bash` (broad, leaky).

So every privacy-sensitive agent runs through a tiny compiled, ad-hoc-signed
launcher (`runner/runner.c`). The plist passes the real script as `argv[1]`; the
runner spawns it as a child, so the bundle stays the TCC-responsible process and
its grant covers the script. `install.sh` builds **two bundles from the one
source**, split by privilege tier so each agent gets only what it needs:

| Bundle | Bundle id | Grant | Agents |
|--------|-----------|-------|--------|
| `AgentRunner.app` | `org.zmievski.agent-runner` | Downloads folder | heic2jpeg |
| `AgentRunnerFDA.app` | `org.zmievski.agent-runner-fda` | Full Disk Access | imessage-export |

- **Granted to the bundle, inherited by every agent routed through it.** Folder
  access (Downloads) is offered as a just-in-time prompt — click **Allow**. Full
  Disk Access is *not* promptable; add `AgentRunnerFDA.app` manually under
  **System Settings → Privacy & Security → Full Disk Access**.
- The `*.app/` bundles are build artifacts (git-ignored). `install.sh` rebuilds
  only when `runner/` sources change. Caveat: a rebuild changes the ad-hoc
  signature (cdhash), which resets the grant — Downloads re-prompts, FDA must be
  re-added. Don't edit `runner/` casually.

## Agents

- **org.zmievski.heic2jpeg** — WatchPaths-triggered on `~/Downloads`; converts each
  new top-level `*.heic` to JPEG (EXIF preserved via `sips`) into
  `~/Downloads/AirDrop`, then **deletes the source HEIC on successful
  conversion**. Deps: `sips` (built-in). Needs Downloads-folder access (granted
  to the runner bundle, see above). Logs: `/tmp/heic2jpeg.{out,err}`.

- **org.zmievski.thingsdrain** — runs every 30 min (and at load); drains the Home
  Assistant "Things Outbox" to-do list into Things 3 via the `things:///add` URL
  scheme. Direct `python3` (stdlib only), **not** via the runner — reads its HA
  token from the Keychain (`ha-things-drain`), so it keeps a stable invocation
  identity. Script lives in-place at
  `~/projects/ha-workshop/scripts/things-drain/things_drain.py`. Logs:
  `/tmp/thingsdrain.{out,err}`.

- **org.zmievski.imessage-export** — monthly (1st at 10:00); exports the previous
  month of a fixed set of iMessage threads to HTML with cloned attachments via
  `imessage-exporter`, downsizes attachment images with `sips`, and pings Home
  Assistant with a summary. Routed through **`AgentRunnerFDA.app`** — reading
  `~/Library/Messages/chat.db` needs Full Disk Access. HA token from the Keychain
  (`ha-imessage-export`). Script: `bin/imessage-export.sh`; exports land in
  `~/imessage-export/monthly/`. Logs: `/tmp/imessage-export.{out,err}`.
