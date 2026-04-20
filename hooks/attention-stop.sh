#!/usr/bin/env bash
# Claude Code Stop hook: record that this session's agent is idle and may need
# attention. Writes an entry keyed by session_id to ~/.claude/attention.json.
# The shell_pid field lets a VS Code extension map the entry back to the
# integrated terminal the session is running in.

set -eu

STATE_DIR="${HOME}/.claude"
STATE_FILE="${STATE_DIR}/attention.json"
mkdir -p "${STATE_DIR}"

payload="$(cat)"

# Debug trace — remove once the hook wiring is stable.
printf '%s stop pid=%s payload=%s\n' "$(date +%s)" "$$" "${payload}" >> "${HOME}/.claude/attention-debug.log"

session_id="$(printf '%s' "${payload}" | jq -r '.session_id // empty')"
cwd="$(printf '%s' "${payload}" | jq -r '.cwd // empty')"
transcript="$(printf '%s' "${payload}" | jq -r '.transcript_path // empty')"

[ -z "${session_id}" ] && exit 0

# Walk up the process tree from this hook's parent until we hit a shell.
# The hook is a descendant of claude (node), whose parent is the shell that
# VS Code's integrated terminal owns. That shell's pid matches what the
# extension gets from Terminal.processId.
pid="${PPID}"
shell_pid="${PPID}"
for _ in 1 2 3 4 5 6 7 8; do
  [ -z "${pid}" ] && break
  [ "${pid}" -le 1 ] && break
  comm="$(ps -o comm= -p "${pid}" 2>/dev/null | awk 'NR==1{print $1}')"
  base="${comm##*/}"
  base="${base#-}"
  case "${base}" in
    zsh|bash|fish|sh|dash|ksh)
      shell_pid="${pid}"
      break
      ;;
  esac
  pid="$(ps -o ppid= -p "${pid}" 2>/dev/null | tr -d ' ')"
done

ts="$(date +%s)"

# Pull the last assistant text block from the transcript so the extension can
# use it as the item label. Falls back to empty string if the transcript is
# missing or contains no text yet.
last_text=""
if [ -n "${transcript}" ] && [ -f "${transcript}" ]; then
  last_text="$(jq -rs '
    [ .[]
      | select(.type == "assistant")
      | .message.content[]?
      | select(.type == "text")
      | .text
    ] | last // ""
  ' "${transcript}" 2>/dev/null || printf '')"
  # Collapse whitespace and cap at 300 chars so attention.json stays compact.
  last_text="$(printf '%s' "${last_text}" | tr '\n' ' ' | tr -s ' ' | cut -c1-300)"
fi

if [ -f "${STATE_FILE}" ]; then
  state="$(cat "${STATE_FILE}")"
else
  state='{}'
fi

# Guard against a malformed state file.
if ! printf '%s' "${state}" | jq -e 'type == "object"' >/dev/null 2>&1; then
  state='{}'
fi

updated="$(printf '%s' "${state}" | jq \
  --arg sid "${session_id}" \
  --arg cwd "${cwd}" \
  --arg tp "${transcript}" \
  --arg lt "${last_text}" \
  --argjson pid "${shell_pid}" \
  --argjson ts "${ts}" \
  '.[$sid] = {
     session_id: $sid,
     shell_pid:  $pid,
     cwd:        $cwd,
     transcript_path: $tp,
     last_text:  $lt,
     kind:       "stop",
     ts:         $ts
   }')"

tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
printf '%s\n' "${updated}" > "${tmp}"
mv "${tmp}" "${STATE_FILE}"
