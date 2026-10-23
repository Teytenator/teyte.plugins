#!/bin/bash
# Install all teyte.* plugins from this repo into ~/.config/omarchy/plugins/

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"

mkdir -p "$PLUGINS_DIR"

installed=0
for manifest in "$REPO_DIR"/*/manifest.json; do
  plugin_dir="$(dirname "$manifest")"
  id="$(jq -r '.id' "$manifest")"
  target="$PLUGINS_DIR/$id"
  if [[ -e $target || -L $target ]]; then
    echo "skip   $id (already installed in $target)"
    continue
  fi
  cp -aL "$plugin_dir" "$target"
  echo "added  $id -> $target"
  installed=1
done

if (( installed )); then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  echo "Plugins rescanned. Enable them with: omarchy plugin enable <id>"
else
  echo "Nothing to install."
fi
# Install helper scripts used by plugins
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
for helper in "$REPO_DIR/bin/"*; do
  [ -f "$helper" ] || continue
  name="$(basename "$helper")"
  target="$BIN_DIR/$name"
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "skip   $name (already exists in $BIN_DIR)"
    continue
  fi
  cp -a "$helper" "$target"
  chmod +x "$target"
  echo "added  $name -> $target"
done
