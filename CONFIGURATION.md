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
~/.config/omarchy/plugins/teyte.todo/config.json
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
| `teyte.todo` | `path` (markdown file), `maxItems`, `showCompleted`, `accentColor`, `width` |
| `teyte.prompt` | `agent`, `agentArgs`, `terminal`, `cwd` (`"auto"`, `"home"`, or an absolute path), `placeholder`, `barLabel`, `paletteYRatio`, `historyLimit`, `barNamespace`, `modesEnabled`, `notePath` |

### `teyte.prompt`

The palette is interactive. A few keys behave differently:

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
| `modesEnabled` | `true` | Enable the `>`, `:`, and `=` prefixes; `false` sends everything to the agent |
| `notePath` | `"~/inbox.md"` | File that note mode appends timestamped lines to |

#### Modes

A prefix on the first character switches what `Enter` does. The glyph on the
left and the hint line show the active mode.

| Prefix | Mode | `Enter` does |
|--------|------|--------------|
| *(none)*, `?`, or a leading space | agent | Launches `agent` with the text as `--prompt` |
| `>` | shell | Runs the rest in `$SHELL` inside `terminal`; the shell stays open afterward |
| `:` | note | Appends `- HH:MM <text>` to `notePath` and shows a notification |
| `=` | calc | Evaluates the expression, copies the result to the clipboard, then closes the palette |

Start with a space to send a literal `>`, `:`, or `=` prompt to the agent.

Examples:

```
fix the failing test in this repo
? explain what this function does
> npm run dev
: call the dentist tomorrow
= 12 * 8 + 3
```

Calc supports `+ - * / ** %`, parentheses, `sqrt()`, `sin()`, `cos()`, `log()`,
`pi`, `e`, and the rest of Python's `math` functions. It is a safe AST
evaluator — not a shell — so typos show an error instead of executing anything.

#### Screenshot to agent

`Super+Shift+Print` prompts for a screen region, saves a PNG under
`~/.cache/teyte.prompt/`, OCRs it with `tesseract` when available, and opens the
palette prefilled with:

```
Screenshot: /home/you/.cache/teyte.prompt/shot-....png — text: <OCR text>
```

Add your request after the prefilled text and press `Enter`. The same flow can
be run by hand — useful with an existing file or a preset region:

```bash
~/.local/bin/teyte-prompt-shot                  # interactive region picker
~/.local/bin/teyte-prompt-shot "0,0 800x600"    # explicit slurp-style geometry
```

#### Within the palette

| Key | Action |
|-----|--------|
| `Enter` | Run the active mode and close the palette |
| `Esc` | Close the palette |
| `↑` / `↓` | Cycle through recent prompts |
| Click outside | Close the palette |

Prompts are stored newest-first in `~/.local/state/teyte.prompt/history.txt`.
To see the directory the agent will use without opening a terminal, run:

```bash
~/.local/bin/teyte-prompt-cwd
```

### `teyte.todo`

A markdown task list on the desktop. Click a row to toggle its checkbox; the
file is rewritten in place. Add tasks by editing the file (or let your agent
edit it) — the widget re-reads it every few seconds.

| Key | Default | Meaning |
|-----|---------|---------|
| `path` | `"~/todo.md"` | Markdown file to read; `~/` is expanded |
| `maxItems` | `12` | Maximum number of rows shown |
| `showCompleted` | `true` | Also show checked tasks; `false` hides them |
| `accentColor` | `"#66ccff"` | Color of the `[ ]` marker and row hover |
| `width` | `320` | Panel width in px |

The panel is click-through everywhere except the task list itself. The checkbox
syntax is standard GitHub-flavored markdown:

```markdown
# Tasks
- [ ] Open task
- [x] Done task
```

`-` and `*` both work, and only the first line matching the clicked text is
toggled. The helper behind it can be used directly:

```bash
~/.local/bin/teyte-todo-toggle ~/todo.md "Open task"
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

Move the todo list, hide finished tasks, and use a different file:

```json
"path": "~/Documents/tasks.md",
"xRatio": 0.75,
"yRatio": 0.25,
"showCompleted": false
```

Send notes to a different file:

```json
"notePath": "~/notes/inbox.md"
```

Set `"modesEnabled": false` to disable the `>`/`:`/`=` prefixes and send every
line to the agent.

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
- **New modes/todo missing after pulling this repo** — `install.sh` skips
  plugins and helpers that already exist. Copy the changed QML/helper into the
  installed paths (see the README update snippet), or remove the plugin folder
  and reinstall. Keep your `config.json` if you customized it.
- **Todo widget is behind a window** — it lives on the bottom layer with the
  other desktop widgets. Minimize the window or switch to an empty workspace.
- **Screenshot key does nothing** — confirm `teyte-prompt-shot` is on `PATH`
  (`~/.local/bin/teyte-prompt-shot`) and that `Super+Shift+Print` is not
  overridden. `hyprctl binds` shows the active bindings.
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
