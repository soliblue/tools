# Majorelle - Oh My Zsh Theme
# Inspired by the Majorelle Garden in Marrakech
# Matches the Majorelle VS Code theme color palette
#
# Colors (256-color approximations):
#   Coral/Terracotta: 173  (#CC7257)
#   Blue:             111  (#6C9EF8)
#   Green:            114  (#7EC87E)
#   Gold:             179  (#E5A84B)
#   Purple:           176  (#C586C0)
#   Cyan:              80  (#56D4C8)
#   Muted Blue:        60  (#546191)
#   Red:              203  (#F44747)

# Prompt symbol
MAJORELLE_SYMBOL=${MAJORELLE_SYMBOL:-"$"}
MAJORELLE_SYMBOL_ERROR=${MAJORELLE_SYMBOL_ERROR:-"$"}

# Time display (set to false to hide)
MAJORELLE_SHOW_TIME=${MAJORELLE_SHOW_TIME:-true}

# Virtualenv display
MAJORELLE_SHOW_VENV=${MAJORELLE_SHOW_VENV:-true}

_majorelle_git_info() {
  (( $+commands[git] )) || return
  [[ "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] || return

  local branch dirty ahead behind stash
  branch=$(command git symbolic-ref --short HEAD 2>/dev/null) || \
  branch=$(command git describe --exact-match --tags HEAD 2>/dev/null) || \
  branch=$(command git rev-parse --short HEAD 2>/dev/null)

  dirty=$(command git status --porcelain 2>/dev/null)

  # Ahead/behind
  ahead=$(command git rev-list --count @{upstream}..HEAD 2>/dev/null)
  behind=$(command git rev-list --count HEAD..@{upstream} 2>/dev/null)

  # Stash
  stash=$(command git stash list 2>/dev/null | wc -l | tr -d ' ')

  # Branch color: green if clean, gold if dirty
  if [[ -n $dirty ]]; then
    echo -n "%F{179}%f"  # gold branch icon
    echo -n "%F{179}${branch:gs/%/%%}%f"
  else
    echo -n "%F{114}%f"  # green branch icon
    echo -n "%F{114}${branch:gs/%/%%}%f"
  fi

  # Dirty indicator
  [[ -n $dirty ]] && echo -n " %F{173}*%f"

  # Ahead/behind
  [[ $ahead -gt 0 ]] 2>/dev/null && echo -n " %F{80}${ahead}%f"
  [[ $behind -gt 0 ]] 2>/dev/null && echo -n " %F{203}${behind}%f"

  # Stash
  [[ $stash -gt 0 ]] 2>/dev/null && echo -n " %F{176}${stash}s%f"
}

_majorelle_venv() {
  [[ "$MAJORELLE_SHOW_VENV" != true ]] && return
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo -n "%F{176}(${VIRTUAL_ENV:t})%f "
  elif [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    echo -n "%F{176}(${CONDA_DEFAULT_ENV})%f "
  fi
}

_majorelle_time() {
  [[ "$MAJORELLE_SHOW_TIME" != true ]] && return
  echo -n "%F{60}%T%f"
}

# Build the prompt
_majorelle_prompt() {
  local exit_code=$?

  # Line 1: directory and git
  echo -n "%F{111}%~%f"                    # blue directory path
  local git_info=$(_majorelle_git_info)
  [[ -n $git_info ]] && echo -n " %F{60}on%f $git_info"
  echo ""                                  # newline

  # Line 2: prompt symbol
  if [[ $exit_code -ne 0 ]]; then
    echo -n "%F{203}${MAJORELLE_SYMBOL_ERROR}%f "   # red on error
  else
    echo -n "%F{173}${MAJORELLE_SYMBOL}%f "          # coral accent
  fi
}

# Virtualenv + prompt
PROMPT='$(_majorelle_venv)$(_majorelle_prompt)'

# Right prompt: time
RPROMPT='$(_majorelle_time)'

# Git prompt settings (for plugins that use these)
ZSH_THEME_GIT_PROMPT_PREFIX="%F{60}on%f %F{114}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f"
ZSH_THEME_GIT_PROMPT_DIRTY=" %F{173}*%f"
ZSH_THEME_GIT_PROMPT_CLEAN=""
