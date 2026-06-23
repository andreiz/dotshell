# launchd-agents

Version-controlled user launchd agents for **wick**. Plists live here and are
symlinked into `~/Library/LaunchAgents`; they point at scripts in-place in this
repo (no copying, no per-machine migration).

Run `./install.sh` to build the runner bundle and symlink + (re)load every
agent. It's idempotent — each agent is `bootout`'d then `bootstrap`'d via the
modern `launchctl` API.

## TCC / privacy: the runner bundle

macOS attaches privacy permissions (Downloads/Documents/Desktop folder access,
Full Disk Access, …) to the executing **Mach-O binary or app bundle**, never to
a shell script. A LaunchAgent that runs a `.sh` directly can't get into
protected folders — the grant would have to land on `/bin/bash` (broad, leaky).

So every privacy-sensitive agent runs through **`AgentRunner.app`** — a tiny
compiled, ad-hoc-signed launcher (`runner/runner.c`, bundle id
`org.zmievski.agent-runner`) built by `install.sh`. The plist passes the real
script as `argv[1]`; the runner spawns it as a child, so the bundle stays the
TCC-responsible process and its grant covers the script.

- **Granted once, to the bundle.** The first time an agent touches a protected
  folder, macOS prompts (e.g. *"AgentRunner wants to access your Downloads
  folder"*) — click **Allow**. Because the grant is keyed to the bundle id,
  every agent routed through the runner inherits it. Manage under **System
  Settings → Privacy & Security → Files and Folders**.
- `AgentRunner.app/` is a build artifact (git-ignored); `install.sh` rebuilds it
  only when `runner/` sources change, keeping the signature — and the grant —
  stable.

## Agents

- **org.zmievski.heic2jpeg** — WatchPaths-triggered on `~/Downloads`; converts each
  new top-level `*.heic` to JPEG (EXIF preserved via `sips`) into
  `~/Downloads/AirDrop`, then **deletes the source HEIC on successful
  conversion**. Deps: `sips` (built-in). Needs Downloads-folder access (granted
  to the runner bundle, see above). Logs: `/tmp/heic2jpeg.{out,err}`.

<!-- Planned (not yet added): org.zmievski.imessage-export, org.zmievski.thingsdrain -->
