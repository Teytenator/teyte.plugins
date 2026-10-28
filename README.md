# teyte.plugins

Omarchy shell plugins by teyte, rendered behind all windows on the bottom layer.

## Plugins

| Plugin | Description |
|--------|-------------|
| `teyte.calendar` | Terminal-style monthly calendar |
| `teyte.media` | Now-playing media display with cover art and playback controls |
| `teyte.specs` | Fastfetch-style system specs |
| `teyte.visualizer` | Real-time audio spectrum visualizer |
| `teyte.weather` | Current weather conditions from Open-Meteo |
| `teyte.todo` | Markdown task list — click a task to check it off, or `EDIT` to open the file |
| `teyte.prompt` | Search/agent palette — click the desktop bar or press `Super+Ctrl+/`, type a query to search the web in your default browser. `@` launches opencode; `>` runs a shell command, `:` saves a note, and `=` calculates |

`teyte.prompt` and `teyte.todo` are the interactive plugins. Helpers they
install:

| Helper | Purpose |
|--------|---------|
| `teyte-prompt-cwd` | Picks a working directory for the agent |
| `teyte-prompt-calc` | Safe arithmetic evaluator (calculator mode) |
| `teyte-prompt-note` | Appends a timestamped note (note mode) |
| `teyte-prompt-shot` | Screenshot → palette prefilled for the agent, with OCR |
| `teyte-todo-toggle` | Toggles a markdown task in place |
| `teyte-settings` | Unified TUI for all installed `teyte.*` configs |

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
cp -a teyte.prompt/Prompt.qml teyte.prompt/PromptBar.qml teyte.prompt/manifest.json ~/.config/omarchy/plugins/teyte.prompt/
cp -a teyte.media/Media.qml ~/.config/omarchy/plugins/teyte.media/
cp -a teyte.todo/Todo.qml ~/.config/omarchy/plugins/teyte.todo/
cp -a bin/teyte-prompt-shot ~/.local/bin/
cp -a bin/teyte-settings ~/.local/bin/
omarchy restart shell
```

If your prompt config predates 1.1.0, add `defaultMode` and `searchUrl`
to `~/.config/omarchy/plugins/teyte.prompt/config.json` (see
[CONFIGURATION.md](CONFIGURATION.md)) or copy the repo's `config.json` if you
have not customized it.

`install.sh` also copies `teyte-settings`, but it skips files that already
exist. Copy the helper by hand once if you are updating an older install.

### Keybinds

| Keybind | Action |
|---------|--------|
| `Super+Ctrl+/` | Open the search/agent palette (or click its desktop bar) |
| `Super+Shift+Print` | Capture a region and open the palette prefilled for the agent |
| `Super+Shift+Alt+S` | Open the unified settings TUI |

Add them to `~/.config/hypr/bindings.lua` if you installed the plugins
manually:

```lua
o.bind("SUPER + CTRL + SLASH", "Search / agent prompt", "omarchy-shell shell summon teyte.prompt")
o.bind("SUPER + SHIFT + PRINT", "Screenshot to agent", "teyte-prompt-shot")
o.bind("SUPER + SHIFT + ALT + S", "teyte settings", "omarchy-launch-terminal teyte-settings")
```

Or install a single plugin manually — copy its folder into
`~/.config/omarchy/plugins/`, then `omarchy-shell shell rescanPlugins`.

### Clipboard history

You do not need another plugin for this: Omarchy already ships a clipboard
manager with persistent history. Press `Super+Ctrl+V` to open it. It supports
text and images, keeps the last 300 entries in
`~/.local/state/omarchy/clipboard-history.json`, and is styled by your current
Omarchy theme. This repo intentionally leaves the built-in manager alone
instead of running a second clipboard watcher.

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

Optional helper cleanup (these live outside the plugin directories):

```bash
rm -f ~/.local/bin/teyte-settings
```

## Todo

`teyte.todo` shows the open tasks from a markdown file as a desktop widget.
Click a task to toggle it; the file is rewritten in place. Click **EDIT** in the
widget header to open the file in Omarchy's default editor. You can also edit
the file by hand — the widget re-reads it every few seconds, and your agent can
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

## Unified settings TUI

`teyte-settings` puts every installed `teyte.*` config in one terminal UI:

```bash
teyte-settings
```

Pick a plugin, then pick a key. Strings and numbers are edited in place,
booleans use a picker, and arrays/objects accept JSON. `Edit raw JSON` opens a
temporary copy in `$VISUAL`/`$EDITOR` (falling back to `nvim`/`nano`); valid
saves apply live while the editor is open. Quit the editor to return to the
menu (`:wq` in nvim, `Ctrl-X` in nano). Saves are atomic, so the normal
hot-reload keeps working.

Useful non-interactive commands:

```bash
teyte-settings --list            # installed plugins and config paths
teyte-settings --check           # validate every config (nonzero = invalid)
teyte-settings --plugin teyte.media
```

Open it with `Super+Shift+Alt+S` after adding the binding above, or launch it
directly from any terminal. It needs `gum` and `jq`; both are normally present
on Omarchy.

## Configure

Each plugin reads its `config.json` for font, colors, opacity, and position.
Edit the copy inside `~/.config/omarchy/plugins/<id>/` — changes hot-reload.
The settings TUI is the safer way to edit live values because it validates
JSON before writing.

See [CONFIGURATION.md](CONFIGURATION.md) for every key, per-plugin options,
examples, and troubleshooting.
