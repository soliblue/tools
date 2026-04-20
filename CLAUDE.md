# Tools

Majorelle theme configurations for VS Code, iTerm2, and Oh My Zsh.

This repo is also meant to give other people and their agents a compact glimpse into the author's personal setup.

## Files

- `vscode/` contains a local VS Code theme extension with 3 themes (`Majorelle`, `Majorelle Medium`, `Majorelle Light`), plus `settings.json`, `keybindings.json`, and `apply-view-layout.sh` as the source of truth for user-level config.
- `iterm/` contains 3 `.itermcolors` presets with the same names.
- `oh-my-zsh/majorelle.zsh-theme` contains the shell prompt theme.
- `hooks/` contains Claude Code hook scripts used by the extension's attention view.

## VS Code

The VS Code theme in this repo is a local extension, not a published marketplace extension.

Do not assume `code --install-extension ./vscode` will work. On this machine, the reliable install path was copying the folder to:

```bash
~/.vscode/extensions/soli.majorelle-0.1.0
```

Then set the active theme in:

```json
"workbench.colorTheme": "Majorelle Light"
```

Any of the 3 theme names above are valid values.

### Settings

`vscode/settings.json` is the source of truth for user settings that belong to this setup. On a new machine, **merge** the entries into `~/Library/Application Support/Code/User/settings.json` — do not overwrite, preserve anything already there that isn't managed by this repo.

Currently tracked entries:

- `workbench.colorTheme: "Majorelle Light"`
- `workbench.editorAssociations` — open `.md` files in preview by default
- `python.terminal.activateEnvironment: false`
- `terminal.integrated.tabs.title: "${sequence}"`
- `files.exclude` additions (e.g. `**/__pycache__`)
- Minimal UI chrome (next section)

### Minimal UI chrome

These settings hide non-essential workbench chrome:

```json
"workbench.statusBar.visible": false,
"window.commandCenter": false,
"workbench.layoutControl.enabled": false,
"workbench.activityBar.location": "hidden",
"explorer.openEditors.visible": 0
```

Additional view toggles that VS Code does **not** expose via `settings.json` (Outline, Timeline, Source Control Repositories) are applied by `vscode/apply-view-layout.sh` — see below.

### Claude · Attention view

The extension contributes a view inside the Explorer sidebar that lists Claude Code sessions whose agent has finished responding and is waiting on the user. The view is scoped per workspace: only sessions whose `cwd` is inside one of the current window's workspace folders are shown, so other projects' sessions never bleed in.

How it works:

- Four hooks in `hooks/` write to a shared state file at `~/.claude/attention.json`:
  - `attention-stop.sh` runs on `Stop` and records the entry with `kind: "stop"`. It walks its process tree up to the first `zsh`/`bash`/`fish` ancestor to capture the PID of the shell that VS Code's terminal owns.
  - `attention-notify.sh` runs on `Notification` (permission prompts, idle alerts) and records the entry with `kind: "notification"`, using the notification message as the label snippet.
  - `attention-clear-notification.sh` runs on `PostToolUse` and flips `notification`-kind entries back to `kind: "running"` once the approved tool finishes (subject to a 2-second minimum age). The notify hook stashes the prior running label in a `running_text` field so this flip can restore it — the row stays visible with the play icon until `Stop` fires. `stop`/`running` entries are left alone.
  - `attention-running.sh` runs on `UserPromptSubmit` and records the entry with `kind: "running"`, using the user's prompt as the label snippet. It overwrites any previous `stop`/`notification` state; a later `Stop` or `Notification` hook will overwrite it back when the agent pauses or finishes.
- The extension picks a different codicon per `kind`: `bell-dot` for `stop`, `warning` for `notification`, `play` for `running`.
- The extension watches `~/.claude/attention.json`, filters by workspace folder, and renders one tree item per session.
- Clicking an item calls `Terminal.processId` for each open terminal and focuses the one matching `shell_pid`. If the terminal is gone, a notification explains so.

The hooks are wired in this repo's own `.claude/settings.json` using `$CLAUDE_PROJECT_DIR` so the paths stay portable when the repo is cloned elsewhere. That scoping means the attention view only lights up for Claude sessions started inside this project — which is usually what you want. To cover every project, copy the same two hook entries into `~/.claude/settings.json` instead (or additionally) with absolute paths.

Requires `jq` on `PATH` (already required by `apply-view-layout.sh`).

### Keybindings

`vscode/keybindings.json` is the source of truth for keybindings that belong to this setup. Merge into `~/Library/Application Support/Code/User/keybindings.json` the same way as settings.

- <kbd>⌘ T</kbd> — open a new terminal in the editor area (replaces the default "Go to Symbol in Workspace")
- <kbd>⌘ G</kbd> — open a terminal, `cd` into the codex project, and launch codex. Gated behind `config.codex.projectKeybinding` so it is inert unless explicitly enabled. The path inside is machine-specific; update it when cloning elsewhere.
- <kbd>⌘ I</kbd> — `majorelle.openInBrowser` (provided by this extension)

### Hidden view layout (non-settings-portable)

VS Code stores the visibility of some views (Outline, Timeline, Source Control Repositories, Open Editors) as JSON blobs inside `~/Library/Application Support/Code/User/globalStorage/state.vscdb` (SQLite), not in `settings.json`. A full profile export would sync them but also drags in ~600 KB of unrelated state.

The minimal alternative is `vscode/apply-view-layout.sh`, which patches only the two relevant rows. Usage:

1. Quit VS Code (it locks `state.vscdb` while running).
2. Run `bash vscode/apply-view-layout.sh`.
3. Relaunch VS Code.

Requires `sqlite3` and `jq` on `PATH`.

Open Editors is redundantly covered by both `explorer.openEditors.visible: 0` (in settings) and the script — this is intentional so either alone is sufficient.

## Oh My Zsh

Install the theme by copying:

```bash
oh-my-zsh/majorelle.zsh-theme
```

to:

```bash
~/.oh-my-zsh/themes/majorelle.zsh-theme
```

Then set:

```bash
ZSH_THEME="majorelle"
```

in `~/.zshrc`.

### Current prompt behavior

The prompt was intentionally simplified during setup:

- single-line prompt
- current folder only, using `%1~`
- git branch info on the same line
- no extra prompt symbol such as `$`
- command entry stays on the same line

If the theme changes, preserve this behavior unless explicitly asked otherwise.

## iTerm2

### Color presets

The `.itermcolors` files can be opened with iTerm to import them into the `Color Presets...` menu.

### Profiles

Separate iTerm profiles can also be created for:

- `Majorelle`
- `Majorelle Medium`
- `Majorelle Light`

These should be cloned from the current default profile so font, shell, and other profile settings remain intact while only the color preset changes.

### Tab bar / toolbar styling

Do not use custom shell escape sequences or explicit profile `Tab Color` overrides for the top chrome.

The correct fix for making the iTerm tab bar match the terminal background was setting iTerm's global appearance theme to **Minimal**:

```bash
defaults write com.googlecode.iterm2 TabStyleWithAutomaticOption -int 5
```

Or manually:

`iTerm2 > Settings > Appearance > General > Theme > Minimal`

This worked better than custom tab-color hacks and should be the default recommendation for future setup.

### TabStyleWithAutomaticOption values

- `0` = Light
- `1` = Dark
- `2` = Light (High Contrast)
- `3` = Dark (High Contrast)
- `4` = Automatic
- `5` = Minimal
- `6` = Compact

## Agent Notes

- `AGENTS.md` should be a symlink to `CLAUDE.md`.
- Repo files (`vscode/settings.json`, `vscode/keybindings.json`, the theme JSONs, `oh-my-zsh/majorelle.zsh-theme`, the `.itermcolors` presets, `vscode/apply-view-layout.sh`) are the source of truth. When applying to a machine, sync outward from the repo.
- When merging `settings.json` or `keybindings.json` into the user's VS Code config, merge — do not overwrite. Preserve entries already present that aren't tracked in this repo.
