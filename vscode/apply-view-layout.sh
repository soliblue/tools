#!/usr/bin/env bash
# Hide Outline, Timeline, Open Editors, and Source Control Repositories views
# in the VS Code Explorer sidebar by patching the workbench view state rows in
# ~/Library/Application Support/Code/User/globalStorage/state.vscdb.
#
# VS Code does not expose these toggles via settings.json, so this script is
# the portable way to apply the hidden-view layout on a fresh machine.
#
# Usage: quit VS Code, then run `bash vscode/apply-view-layout.sh`.
set -euo pipefail

DB="$HOME/Library/Application Support/Code/User/globalStorage/state.vscdb"

if [[ ! -f "$DB" ]]; then
  echo "error: $DB not found" >&2
  exit 1
fi

if pgrep -xq "Code" || pgrep -xq "Code Helper"; then
  echo "error: VS Code is running — quit it first (it locks state.vscdb)" >&2
  exit 1
fi

for cmd in sqlite3 jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: $cmd is required" >&2
    exit 1
  fi
done

patch_view_state() {
  local key="$1"
  shift
  local ids=("$@")

  local current
  current=$(sqlite3 "$DB" "SELECT value FROM ItemTable WHERE key = '$key';")

  if [[ -z "$current" ]]; then
    echo "warn: no existing row for $key — skipping" >&2
    return
  fi

  local updated="$current"
  for id in "${ids[@]}"; do
    updated=$(jq -c --arg id "$id" '
      if any(.[]; .id == $id) then
        map(if .id == $id then .isHidden = true else . end)
      else
        . + [{id: $id, isHidden: true}]
      end
    ' <<< "$updated")
  done

  local tmp
  tmp=$(mktemp)
  printf '%s' "$updated" > "$tmp"
  sqlite3 "$DB" "UPDATE ItemTable SET value = readfile('$tmp') WHERE key = '$key';"
  rm -f "$tmp"
  echo "patched: $key"
}

patch_view_state "workbench.explorer.views.state.hidden" \
  "outline" \
  "timeline" \
  "workbench.explorer.openEditorsView" \
  "workbench.scm.repositories"

patch_view_state "workbench.scm.views.state.hidden" \
  "workbench.scm.repositories"

echo "done — relaunch VS Code to see the updated layout"
