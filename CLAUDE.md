# Tools

Majorelle theme configurations for VS Code, iTerm2, and Oh My Zsh.

## iTerm2 Tab Bar

To make the iTerm2 tab bar match the terminal background color (instead of default chrome), set the appearance theme to **Minimal**:

```bash
defaults write com.googlecode.iterm2 TabStyleWithAutomaticOption -int 5
```

Or manually: **iTerm2 > Settings > Appearance > General > Theme > Minimal**

### TabStyleWithAutomaticOption values

- `0` = Light
- `1` = Dark
- `2` = Light (High Contrast)
- `3` = Dark (High Contrast)
- `4` = Automatic
- `5` = Minimal
- `6` = Compact
