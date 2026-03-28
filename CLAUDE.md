# Tools

Majorelle theme configurations for VS Code, iTerm2, and Oh My Zsh.

This repo is also meant to give other people and their agents a compact glimpse into the author's personal setup.

## Files

- `vscode/` contains a local VS Code theme extension with 3 themes:
  - `Majorelle`
  - `Majorelle Medium`
  - `Majorelle Light`
- `iterm/` contains 3 `.itermcolors` presets with the same names.
- `oh-my-zsh/majorelle.zsh-theme` contains the shell prompt theme.

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

### Recommended keybinding

For this setup, `cmd+t` should open a new terminal in the editor area of the current VS Code window.

Use this user keybinding:

```json
{
  "key": "cmd+t",
  "command": "workbench.action.createTerminalEditor"
}
```

This intentionally replaces VS Code's default `cmd+t` behavior for this machine.

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
- Prefer preserving existing user profile settings and only changing theme-related values.
- If updating installed user files, keep repo files as the source of truth and sync outward from this repo.
