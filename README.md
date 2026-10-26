# teyte.plugins

Omarchy shell plugins by teyte, rendered behind all windows on the bottom layer.

## Plugins

| Plugin | Description |
|--------|-------------|
| `teyte.calendar` | Terminal-style monthly calendar |
| `teyte.media` | Now-playing media display with playback controls |
| `teyte.specs` | Fastfetch-style system specs |
| `teyte.visualizer` | Real-time audio spectrum visualizer |
| `teyte.weather` | Current weather conditions from Open-Meteo |
| `teyte.todo` | Markdown task list — click a task to check it off |
| `teyte.prompt` | Agent prompt palette — click the desktop bar or press `Super+Ctrl+/`, type a request, and opencode launches in a terminal. Prefixes turn it into a shell runner, note taker, or calculator |

`teyte.prompt` and `teyte.todo` are the interactive plugins. Helpers they
install:

| Helper | Purpose |
|--------|---------|
| `teyte-prompt-cwd` | Picks a working directory for the agent |
| `teyte-prompt-calc` | Safe arithmetic evaluator (calculator mode) |
| `teyte-prompt-note` | Appends a timestamped note (note mode) |
| `teyte-prompt-shot` | Screenshot → palette, with OCR prefill |
| `teyte-todo-toggle` | Toggles a markdown task in place |

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
omarchy plugin enable teyte.todo
omarchy plugin enable teyte.prompt
```

`install.sh` copies each plugin into `~/.config/omarchy/plugins/`, copies
`bin/*` helpers into `~/.local/bin/`, and rescans the shell. It never
overwrites an existing plugin or helper.

To update an existing install, copy the changed files in by hand (keep your
`config.json`):

```bash
cp -a teyte.prompt/Prompt.qml ~/.config/omarchy/plugins/teyte.prompt/
cp -a bin/teyte-prompt-shot ~/.local/bin/
omarchy restart shell
```

### Keybinds

| Keybind | Action |
|---------|--------|
| `Super+Ctrl+/` | Open the agent palette (or click its desktop bar) |
| `Super+Shift+Print` | Capture a region and open the palette prefilled for the agent |

Add them to `~/.config/hypr/bindings.lua` if you installed the plugins
manually:

```lua
o.bind("SUPER + CTRL + SLASH", "Agent prompt", "omarchy-shell shell summon teyte.prompt")
o.bind("SUPER + SHIFT + PRINT", "Screenshot to agent", "teyte-prompt-shot")
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
omarchy plugin remove teyte.todo
omarchy plugin remove teyte.prompt
```

## Todo

`teyte.todo` shows the open tasks from a markdown file as a desktop widget.
Click a task to toggle it; the file is rewritten in place. Add or edit tasks by
editing the file — the widget re-reads it every few seconds, and your agent can
edit it too.

```markdown
# Tasks
- [ ] Write the release notes
- [ ] Review the pull request
- [x] Ship the widget
```

The default file is `~/todo.md`; set `path` in the plugin's `config.json` to use
another file. Nothing is created automatically, so the widget shows a hint until
the file exists.

## Configure

Each plugin reads its `config.json` for font, colors, opacity, and position.
Edit the copy inside `~/.config/omarchy/plugins/<id>/` — changes hot-reload.

See [CONFIGURATION.md](CONFIGURATION.md) for every key, per-plugin options,
examples, and troubleshooting.