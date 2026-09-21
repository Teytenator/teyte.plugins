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

Each plugin is a directory containing a `manifest.json`, a QML entry point,
and a `config.json` (layout/colors).

## Install

This is a monorepo, so `omarchy plugin add` (which expects a single plugin at
the repo root) cannot install it directly. Instead:

```bash
git clone https://github.com/teyte/teyte.plugins.git
cd teyte.plugins
./install.sh
omarchy plugin enable teyte.calendar
omarchy plugin enable teyte.media
omarchy plugin enable teyte.specs
omarchy plugin enable teyte.visualizer
omarchy plugin enable teyte.weather
```

`install.sh` copies each plugin into `~/.config/omarchy/plugins/` and rescans
the shell. It never overwrites an existing plugin.

Or install a single plugin manually — copy its folder into
`~/.config/omarchy/plugins/`, then `omarchy-shell shell rescanPlugins`.

## Uninstall

```bash
omarchy plugin remove teyte.calendar
omarchy plugin remove teyte.media
omarchy plugin remove teyte.specs
omarchy plugin remove teyte.visualizer
omarchy plugin remove teyte.weather
```

## Configure

Each plugin reads its `config.json` for font, colors, opacity, and position.
Edit the copy inside `~/.config/omarchy/plugins/<id>/` — changes hot-reload.