# teyte.plugins

Omarchy shell plugins by teyte, rendered behind all windows on the bottom layer.

## Plugins

| Plugin | Description |
|--------|-------------|
| `teyte.calendar` | Terminal-style monthly calendar |
| `teyte.media` | Now-playing media display with playback controls |
| `teyte.specs` | Fastfetch-style system specs |
| `teyte.visualizer` | Real-time audio spectrum visualizer |
| `teyte.weather` | Current weather conditions |
| `teyte.prompt` | Agent prompt palette — click the desktop bar or press `Super+Ctrl+/`, type a request, and opencode launches in a terminal |

`teyte.prompt` is the only interactive plugin: it also installs a helper
(`bin/teyte-prompt-cwd`) that picks a working directory for the agent.

Each plugin is a directory containing a `manifest.json`, a QML entry point,
and a `config.json` (layout/colors).

## Install

This is a monorepo, so `omarchy plugin add` (which expects a single plugin at
the repo root) cannot install it directly. Instead:

```bash
git clone https://github.com/Teytenator/teyte.plugins.git
cd teyte.plugins
./install.sh
omarchy plugin enable teyte.calendar
omarchy plugin enable teyte.media
omarchy plugin enable teyte.specs
omarchy plugin enable teyte.visualizer
omarchy plugin enable teyte.weather
omarchy plugin enable teyte.prompt
```

`install.sh` copies each plugin into `~/.config/omarchy/plugins/`, copies
`bin/*` helpers into `~/.local/bin/`, and rescans the shell. It never
overwrites an existing plugin or helper.

### Keybind

`teyte.prompt` is opened with `Super+Ctrl+/` (or by clicking its desktop bar).
Add the binding to `~/.config/hypr/bindings.lua` if you installed the plugin
manually:

```lua
o.bind("SUPER + CTRL + SLASH", "Agent prompt", "omarchy-shell shell summon teyte.prompt")
```

Or install a single plugin manually — copy its folder into
`~/.config/omarchy/plugins/`, then `omarchy-shell shell rescanPlugins`.

## Uninstall

```bash
omarchy plugin remove teyte.calendar
omarchy plugin remove teyte.media
omarchy plugin remove teyte.specs
omarchy plugin remove teyte.visualizer
omarchy plugin remove teyte.weather
omarchy plugin remove teyte.prompt
```

## Configure

Each plugin reads its `config.json` for font, colors, opacity, and position.
Edit the copy inside `~/.config/omarchy/plugins/<id>/` — changes hot-reload.

See [CONFIGURATION.md](CONFIGURATION.md) for every key, per-plugin options,
examples, and troubleshooting.