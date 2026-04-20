#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook: record that this session is actively
# working on a new turn. Writes the entry with `kind: "running"`, overwriting
# any previous stop/notification state. A later Stop or Notification hook
# will overwrite this back when the agent pauses or finishes.

set -eu

STATE_DIR="${HOME}/.claude"
STATE_FILE="${STATE_DIR}/attention.json"
mkdir -p "${STATE_DIR}"

payload="$(cat)"

# Debug trace — remove once the hook wiring is stable.
printf '%s running pid=%s payload=%s\n' "$(date +%s)" "$$" "${payload}" >> "${HOME}/.claude/attention-debug.log"

session_id="$(printf '%s' "${payload}" | jq -r '.session_id // empty')"
cwd="$(printf '%s' "${payload}" | jq -r '.cwd // empty')"
transcript="$(printf '%s' "${payload}" | jq -r '.transcript_path // empty')"
prompt="$(printf '%s' "${payload}" | jq -r '.prompt // empty')"

[ -z "${session_id}" ] && exit 0

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
last_text="$(printf '%s' "${prompt}" | tr '\n' ' ' | tr -s ' ' | cut -c1-300)"

if [ -f "${STATE_FILE}" ]; then
  state="$(cat "${STATE_FILE}")"
else
  state='{}'
fi
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
     kind:       "running",
     ts:         $ts
   }')"

tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
printf '%s\n' "${updated}" > "${tmp}"
mv "${tmp}" "${STATE_FILE}"
