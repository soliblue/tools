#!/usr/bin/env bash
# Claude Code Notification hook: fires when Claude actively needs user input
# mid-flight — most commonly a permission prompt, or an idle timeout. Writes
# an attention entry marked `kind: "notification"` so the extension can use a
# different symbol from regular Stop entries.

set -eu

STATE_DIR="${HOME}/.claude"
STATE_FILE="${STATE_DIR}/attention.json"
mkdir -p "${STATE_DIR}"

payload="$(cat)"

# Debug trace — remove once the hook wiring is stable.
printf '%s notify pid=%s payload=%s\n' "$(date +%s)" "$$" "${payload}" >> "${HOME}/.claude/attention-debug.log"

session_id="$(printf '%s' "${payload}" | jq -r '.session_id // empty')"
cwd="$(printf '%s' "${payload}" | jq -r '.cwd // empty')"
transcript="$(printf '%s' "${payload}" | jq -r '.transcript_path // empty')"
message="$(printf '%s' "${payload}" | jq -r '.message // empty')"

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
last_text="$(printf '%s' "${message}" | tr '\n' ' ' | tr -s ' ' | cut -c1-300)"

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
  '
   # Preserve any running context so clearing the notification can restore it.
   # Prefer an existing running_text (previous running state), then last_text
   # of the current running entry, then empty.
   (.[$sid] // {}) as $prev
   | ($prev.running_text // (if $prev.kind == "running" then $prev.last_text else "" end)) as $rt
   | .[$sid] = {
       session_id: $sid,
       shell_pid:  $pid,
       cwd:        $cwd,
       transcript_path: $tp,
       last_text:  $lt,
       kind:       "notification",
       ts:         $ts,
       running_text: $rt
     }
   ')"

tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
printf '%s\n' "${updated}" > "${tmp}"
mv "${tmp}" "${STATE_FILE}"
