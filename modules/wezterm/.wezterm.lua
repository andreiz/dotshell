-- Pull in the wezterm API
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local host = wezterm.hostname()

-- Appearance / behavior
config.scrollback_lines = 3500
config.color_scheme = 'nord'
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 15

-- Local persistence: a standalone mux-server reachable via a unix socket.
config.unix_domains = {
  { name = 'unix' },
}

-- Only the mux HOST (wick) makes new panes spawn into the standalone
-- mux-server (socket at ~/.local/share/wezterm/sock) instead of the GUI's
-- internal 'local' domain. GUI-local panes have no socket and can't be reached
-- remotely. A client domain (ssh/tls/unix) can NOT be a mux server's
-- default_domain, so persistence lives here as a unix domain and the
-- connection lives on the client as an ssh domain -- different by design.
if host:find('wick') then
  config.default_domain = 'unix'
end

-- Client side: reach wick's mux over SSH. Start from the auto-populated
-- SSH:/SSHMUX: domains so every other ssh_config host still works, then append
-- a customized 'wick' entry with remote_wezterm_path (Homebrew's
-- /opt/homebrew/bin is not on sshd's non-interactive PATH on macOS; omitting it
-- yields a misleading "server is older than client" / leb128 EOF error).
config.ssh_domains = wezterm.default_ssh_domains()
table.insert(config.ssh_domains, {
  name = 'wick',
  remote_address = 'wick.local',
  username = 'andrei',
  remote_wezterm_path = '/opt/homebrew/bin/wezterm',
})

config.keys = {
  { key = 'Enter', mods = 'SHIFT', action = wezterm.action { SendString = '\x1b\r' } },
}

return config
