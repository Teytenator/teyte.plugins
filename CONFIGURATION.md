# Configuration cheat-sheet

Every plugin reads a `config.json` sitting next to its QML. Edit the installed
copy — the running plugin re-reads it every few seconds, so changes hot-reload
without a restart.

## Where the files live

Installed plugins (this is the live copy):

```
~/.config/omarchy/plugins/teyte.calendar/config.json
~/.config/omarchy/plugins/teyte.media/config.json
~/.config/omarchy/plugins/teyte.specs/config.json
~/.config/omarchy/plugins/teyte.visualizer/config.json
~/.config/omarchy/plugins/teyte.weather/config.json
~/.config/omarchy/plugins/teyte.prompt/config.json
```

Source copies (edit these too if you want the change to survive a reinstall):
`teyte.<id>/config.json` in this repo.

## Common keys

| Key | Type | Meaning |
|-----|------|---------|
| `color` | hex string | Text color, e.g. `"#ffffff"` |
| `bgColor` | hex string | Panel background color, e.g. `"#000000"` |
| `bgOpacity` | 0.0–1.0 | Panel opacity; `1.0` = solid, `0.0` = invisible |
| `opacity` | 0.0–1.0 | Opacity of the content (text, bars) |
| `fontFamily` | string | Font name; `"system"` uses the default font |
| `fontWeight` | number | `400` normal, `700` bold |
| `fontSize` | px | Text size |
| `fontScale` | fraction | Size relative to screen height (used where `fontSize` is not set) |
| `padding` | px | Inner padding around the content |
| `width` | px | Panel width |
| `xMargin` | px | Distance from the left edge |
| `xRatio` / `yRatio` | 0.0–1.0 | Position as a fraction of the screen |
| `xOffset` / `yOffset` | px | Extra pixel offset on top of the ratio position |

## Per-plugin keys

| Plugin | Extra keys |
|--------|-----------|
| `teyte.calendar` | `cellSize` — day-cell size in px |
| `teyte.visualizer` | `bars` (count), `barWidth`, `barGap`, `maxBarHeight` (px), `maxValue` (input gain ceiling, default `8000`) |
| `teyte.weather` | `city` (`"auto"` or a city name), `units` (`"metric"` / `"imperial"`), `refreshMinutes` |
| `teyte.prompt` | `agent`, `agentArgs`, `terminal`, `cwd` (`"auto"`, `"home"`, or an absolute path), `placeholder`, `barLabel`, `paletteYRatio`, `historyLimit`, `barNamespace` |

### `teyte.prompt`

The palette is the only interactive plugin. A few keys behave differently:

| Key | Default | Meaning |
|-----|---------|---------|
| `agent` | `"opencode"` | Command run inside the terminal |
| `agentArgs` | `[]` | Extra arguments inserted before `--prompt`, e.g. `["--model", "anthropic/claude-sonnet-4-5"]` |
| `terminal` | `"foot"` | Terminal emulator; the launch is `<terminal> -e <agent> [agentArgs] --prompt "<text>"` |
| `cwd` | `"auto"` | `"auto"` = the focused window's working directory (falls back to `~/Work`, then `$HOME`); `"home"` = `$HOME`; anything else is used as-is |
| `placeholder` | `"Ask the agent what to do or build…"` | Dim text shown in the empty input |
| `barLabel` | `"❯ ask agent…"` | Text on the clickable desktop bar |
| `paletteYRatio` | `0.28` | Vertical position of the palette (fraction of screen height) |
| `historyLimit` | `50` | Recent prompts kept in the input history |
| `barNamespace` | `"teyte.prompt-bar"` | Layer-shell namespace for the desktop bar |

Open it with `Super+Ctrl+/` or by clicking the desktop bar. Within the palette:

| Key | Action |
|-----|--------|
| `Enter` | Launch the agent, close the palette |
| `Esc` | Close the palette |
| `↑` / `↓` | Cycle through recent prompts |
| Click outside | Close the palette |

Prompts are stored newest-first in `~/.local/state/teyte.prompt/history.txt`.
To see the directory the agent will use without opening a terminal, run:

```bash
~/.local/bin/teyte-prompt-cwd
```

## Examples

Solid black panels (current default):

```json
"bgColor": "#000000",
"bgOpacity": 1.0
```

Frosted / see-through panels, leaving the navy tint:

```json
"bgColor": "#05182e",
"bgOpacity": 0.55
```

Accent-colored text (cyan, matching the built-in highlights):

```json
"color": "#66ccff"
```

Move a plugin: `xRatio`/`yRatio` are fractions of the screen, `xOffset`/`yOffset`
are pixel nudges. Example — bottom-left:

```json
"xRatio": 0.25,
"yRatio": 0.9,
"xOffset": 0,
"yOffset": 0
```

## Apply / verify

```bash
# Validate JSON after editing
jq -e . ~/.config/omarchy/plugins/teyte.calendar/config.json

# Wait ~5 s for the hot-reload, or force a full shell restart
omarchy restart shell
```

`omarchy-shell shell rescanPlugins` alone is **not** enough: these plugins set
`keepLoaded: true`, so a rescan keeps the existing service instance alive and
the QML defaults stay in memory. The config file is still re-read on its timer,
but QML edits need `omarchy restart shell` (or toggling the plugin off/on).

## Troubleshooting

- **Edits do nothing** — make sure you edited the installed copy above, not
  only the repo copy. The plugin reads the absolute path under
  `~/.config/omarchy/plugins/<id>/`.
- **Still the old look after a QML edit** — `keepLoaded` services survive
  rescans; run `omarchy restart shell`.
- **Panel missing entirely** — some panels are conditionally visible (weather
  waits for data, visualizer for audio). Check the shell log:

  ```bash
  journalctl --user -f | grep -i teyte
  ```

- **Check the panel is mounted** — list layer-shell surfaces:

  ```bash
  hyprctl layers | grep teyte
  ```
